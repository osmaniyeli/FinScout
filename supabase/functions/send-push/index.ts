// FinScout: yönetici panelinden push bildirimi (Firebase Cloud Messaging HTTP v1).
// Çağıran JWT ile doğrulanır ve public.admin_roles'ta olmalıdır (service_role ile kontrol).
// Gövde: { title, body, target: 'all' | { email } }
// Geçersiz (UNREGISTERED) token'lar public.devices'tan silinir; her gönderim
// public.admin_notifications'a kaydedilir.
//
// Gerekli secret: FCM_SERVICE_ACCOUNT_JSON (Firebase konsolu > Proje ayarları >
// Hizmet hesapları > "Yeni özel anahtar oluştur" ile inen JSON'un tamamı).
import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-region',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (body: unknown, status = 200) =>
  Response.json(body, { status, headers: cors });

// ---------------------------------------------------------------------------
// Google OAuth: servis hesabı JWT'si (RS256, Web Crypto) -> access token
// ---------------------------------------------------------------------------
type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
};

let cachedToken: { value: string; exp: number } | null = null;

const b64url = (data: Uint8Array | string) => {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : data;
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};

async function googleAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.exp - 60 > now) return cachedToken.value;

  const tokenUri = sa.token_uri ?? 'https://oauth2.googleapis.com/token';
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  );
  const sig = new Uint8Array(await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${header}.${claims}`),
  ));
  const assertion = `${header}.${claims}.${b64url(sig)}`;

  const res = await fetch(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!res.ok) {
    console.error('google token error', res.status, await res.text());
    throw new Error('google_auth_failed');
  }
  const tok = await res.json() as { access_token: string; expires_in: number };
  cachedToken = { value: tok.access_token, exp: now + (tok.expires_in ?? 3600) };
  return tok.access_token;
}

type SendResult = 'ok' | 'invalid_token' | 'failed';

async function sendOne(
  projectId: string, accessToken: string, token: string,
  title: string, body: string, notificationId: string,
): Promise<SendResult> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          // Uygulama içi Bildirimler listesine yazılırken aynı kimlik kullanılır (çift kayıt olmaz)
          data: { kind: 'admin', id: notificationId, title, body },
          android: {
            priority: 'HIGH',
            notification: {
              channel_id: 'announcements',
              icon: 'ic_stat_finscout',
              color: '#10B981',
            },
          },
        },
      }),
    },
  );
  if (res.ok) return 'ok';
  const text = await res.text();
  // UNREGISTERED (404) ya da geçersiz biçimli token (400) → cihaz kaydı silinir
  if (text.includes('UNREGISTERED') ||
      (res.status === 400 && /registration token/i.test(text))) {
    return 'invalid_token';
  }
  console.error('fcm send failed', res.status, text.slice(0, 500));
  return 'failed';
}

// ---------------------------------------------------------------------------

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const url = Deno.env.get('SUPABASE_URL')!;
  const jwt = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!jwt) return json({ error: 'unauthorized' }, 401);

  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: { user }, error: userError } = await admin.auth.getUser(jwt);
  if (userError || !user) return json({ error: 'unauthorized' }, 401);

  const { data: role, error: roleError } = await admin
    .from('admin_roles').select('user_id').eq('user_id', user.id).maybeSingle();
  if (roleError) {
    console.error('admin check failed', roleError.message);
    return json({ error: 'server_error' }, 500);
  }
  if (!role) return json({ error: 'forbidden', message: 'Bu işlem için yönetici yetkisi gerekli.' }, 403);

  // Gövde doğrulama
  let payload: { title?: unknown; body?: unknown; target?: unknown };
  try {
    payload = await req.json();
  } catch {
    return json({ error: 'bad_request', message: 'Geçersiz JSON.' }, 400);
  }
  const title = typeof payload.title === 'string' ? payload.title.trim() : '';
  const body = typeof payload.body === 'string' ? payload.body.trim() : '';
  if (!title || title.length > 100) {
    return json({ error: 'bad_request', message: 'Başlık 1-100 karakter olmalı.' }, 400);
  }
  if (!body || body.length > 1000) {
    return json({ error: 'bad_request', message: 'Mesaj 1-1000 karakter olmalı.' }, 400);
  }
  let targetEmail: string | null = null;
  if (payload.target === 'all') {
    targetEmail = null;
  } else if (
    payload.target && typeof payload.target === 'object' &&
    typeof (payload.target as { email?: unknown }).email === 'string' &&
    (payload.target as { email: string }).email.includes('@')
  ) {
    targetEmail = (payload.target as { email: string }).email.trim().toLowerCase();
  } else {
    return json({ error: 'bad_request', message: "Hedef 'all' ya da { email } olmalı." }, 400);
  }

  // Firebase servis hesabı
  const raw = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');
  if (!raw) {
    return json({
      error: 'push_not_configured',
      message: 'Push bildirimi henüz yapılandırılmadı: FCM_SERVICE_ACCOUNT_JSON secret\'ı eklenmeli (Firebase servis hesabı anahtarı).',
    }, 503);
  }
  let sa: ServiceAccount;
  try {
    sa = JSON.parse(raw) as ServiceAccount;
    if (!sa.project_id || !sa.client_email || !sa.private_key) throw new Error('fields');
  } catch {
    return json({
      error: 'push_not_configured',
      message: 'FCM_SERVICE_ACCOUNT_JSON geçersiz: Firebase servis hesabı JSON dosyasının tamamı olmalı.',
    }, 503);
  }

  // Hedef cihazlar
  let query = admin.from('devices').select('id, fcm_token');
  if (targetEmail) {
    const { data: uid, error } = await admin.rpc('admin_user_id_by_email', { p_email: targetEmail });
    if (error) {
      console.error('email lookup failed', error.message);
      return json({ error: 'server_error' }, 500);
    }
    if (!uid) return json({ error: 'user_not_found', message: 'Bu e-postayla kayıtlı hesap yok.' }, 404);
    query = query.eq('user_id', uid as string);
  }
  const { data: devices, error: devError } = await query.limit(10000);
  if (devError) {
    console.error('devices query failed', devError.message);
    return json({ error: 'server_error' }, 500);
  }

  const notificationId = crypto.randomUUID();
  let sent = 0;
  let failed = 0;
  const invalidIds: string[] = [];

  if (devices && devices.length > 0) {
    let accessToken: string;
    try {
      accessToken = await googleAccessToken(sa);
    } catch {
      return json({
        error: 'fcm_auth_failed',
        message: 'Firebase kimlik doğrulaması başarısız: servis hesabı anahtarını kontrol et.',
      }, 502);
    }
    // 20'şerli paralel gönderim
    for (let i = 0; i < devices.length; i += 20) {
      const chunk = devices.slice(i, i + 20);
      const results = await Promise.all(chunk.map((d) =>
        sendOne(sa.project_id, accessToken, d.fcm_token, title, body, notificationId)
          .catch(() => 'failed' as SendResult)
      ));
      results.forEach((r, j) => {
        if (r === 'ok') sent++;
        else {
          failed++;
          if (r === 'invalid_token') invalidIds.push(chunk[j].id);
        }
      });
    }
    if (invalidIds.length > 0) {
      const { error } = await admin.from('devices').delete().in('id', invalidIds);
      if (error) console.error('invalid token cleanup failed', error.message);
    }
  }

  const { error: logError } = await admin.from('admin_notifications').insert({
    id: notificationId,
    sent_by: user.id,
    title,
    body,
    target: targetEmail ?? 'all',
    sent_count: sent,
    failed_count: failed,
  });
  if (logError) console.error('log insert failed', logError.message);

  console.log('push sent', { by: user.id, target: targetEmail ? 'email' : 'all', sent, failed });
  return json({
    id: notificationId,
    sent,
    failed,
    device_count: devices?.length ?? 0,
    removed_invalid: invalidIds.length,
  });
});
