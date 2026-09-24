// FinScout: Google Play abonelik makbuzunu sunucuda doğrular.
// İstemci { productId, purchaseToken } gönderir; Google Play Developer API
// (purchases.subscriptionsv2.get) ile doğrulanır, sonuç public.subscriptions'a yazılır
// ve kullanıcının güncel paketi (entitlement RPC) döner.
//
// Gerekli secret: PLAY_SERVICE_ACCOUNT_JSON (Play Console'da "Finansal verileri görüntüle"
// + "Siparişleri ve abonelikleri yönet" izni verilmiş servis hesabının JSON anahtarı).
import { createClient } from 'npm:@supabase/supabase-js@2';

const PACKAGE_NAME = 'com.moneytrace.app';
const PRODUCTS = new Set([
  'finscout_individual_monthly',
  'finscout_individual_annual',
  'finscout_family_annual_4p',
]);

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const json = (body: unknown, status = 200) =>
  Response.json(body, { status, headers: cors });

// ---------------------------------------------------------------------------
// Google OAuth: servis hesabı JWT'si (RS256, Web Crypto) -> access token
// ---------------------------------------------------------------------------
type ServiceAccount = { client_email: string; private_key: string; token_uri?: string };

let cachedToken: { value: string; exp: number } | null = null;

const b64url = (data: Uint8Array | string) => {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : data;
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};

async function googleAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.exp - 60 > now) return cachedToken.value;

  const raw = Deno.env.get('PLAY_SERVICE_ACCOUNT_JSON');
  if (!raw) throw new Error('missing_service_account');
  const sa = JSON.parse(raw) as ServiceAccount;
  const tokenUri = sa.token_uri ?? 'https://oauth2.googleapis.com/token';

  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
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

// ---------------------------------------------------------------------------

type LineItem = {
  productId: string;
  expiryTime?: string;
  autoRenewingPlan?: { autoRenewEnabled?: boolean };
};
type SubscriptionV2 = {
  subscriptionState?: string;
  lineItems?: LineItem[];
  linkedPurchaseToken?: string;
  testPurchase?: unknown;
  externalAccountIdentifiers?: { obfuscatedExternalAccountId?: string };
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const url = Deno.env.get('SUPABASE_URL')!;
  const authHeader = req.headers.get('Authorization') ?? '';
  const jwt = authHeader.replace(/^Bearer\s+/i, '');
  if (!jwt) return json({ error: 'unauthorized' }, 401);

  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: userError } = await admin.auth.getUser(jwt);
  if (userError || !user) return json({ error: 'unauthorized' }, 401);

  let body: { productId?: unknown; purchaseToken?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'bad_request' }, 400);
  }
  const productId = typeof body.productId === 'string' ? body.productId : '';
  const token = typeof body.purchaseToken === 'string' ? body.purchaseToken : '';
  if (!PRODUCTS.has(productId) || token.length < 10 || token.length > 4096) {
    return json({ error: 'bad_request' }, 400);
  }

  // Makbuz başka bir hesaba bağlıysa reddet (hesap paylaşımı / makbuz yeniden kullanımı)
  const { data: existing } = await admin
    .from('subscriptions').select('user_id').eq('purchase_token', token).maybeSingle();
  if (existing && existing.user_id !== user.id) {
    return json({ error: 'token_in_use' }, 409);
  }

  // Google'a sor
  let accessToken: string;
  try {
    accessToken = await googleAccessToken();
  } catch (e) {
    console.error('google auth', (e as Error).message);
    return json({ error: 'play_auth_failed' }, 502);
  }
  const apiUrl =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE_NAME}` +
    `/purchases/subscriptionsv2/tokens/${encodeURIComponent(token)}`;
  const gRes = await fetch(apiUrl, { headers: { Authorization: `Bearer ${accessToken}` } });
  if (gRes.status === 401 || gRes.status === 403) {
    console.error('play permission denied', gRes.status, await gRes.text());
    return json({ error: 'play_permission_denied' }, 502);
  }
  if (gRes.status === 400 || gRes.status === 404 || gRes.status === 410) {
    await gRes.body?.cancel();
    return json({ error: 'invalid_token' }, 400);
  }
  if (!gRes.ok) {
    console.error('play api error', gRes.status, await gRes.text());
    return json({ error: 'play_unavailable' }, 502);
  }
  const sub = await gRes.json() as SubscriptionV2;

  // Satın alma istemcide Supabase kullanıcı kimliğiyle (obfuscatedAccountId) başlatıldıysa eşleşmeli
  const boundTo = sub.externalAccountIdentifiers?.obfuscatedExternalAccountId;
  if (boundTo && boundTo !== user.id) {
    return json({ error: 'token_in_use' }, 409);
  }

  const item = sub.lineItems?.find((l) => l.productId === productId) ??
    sub.lineItems?.find((l) => PRODUCTS.has(l.productId));
  if (!item) return json({ error: 'product_mismatch' }, 400);

  const state = (sub.subscriptionState ?? 'SUBSCRIPTION_STATE_UNSPECIFIED')
    .replace(/^SUBSCRIPTION_STATE_/, '');
  const expiry = item.expiryTime ?? null;

  const { error: upsertError } = await admin.from('subscriptions').upsert({
    user_id: user.id,
    product_id: item.productId,
    purchase_token: token,
    state,
    expiry_time: expiry,
    auto_renewing: item.autoRenewingPlan?.autoRenewEnabled ?? false,
    test_purchase: sub.testPurchase != null,
    verified_at: new Date().toISOString(),
  }, { onConflict: 'purchase_token' });
  if (upsertError) {
    console.error('upsert failed', upsertError.message);
    return json({ error: 'store_failed' }, 500);
  }

  // Plan değişikliğinde eski makbuz artık hak vermez
  if (sub.linkedPurchaseToken && sub.linkedPurchaseToken !== token) {
    await admin.from('subscriptions').update({ state: 'REPLACED' })
      .eq('purchase_token', sub.linkedPurchaseToken).eq('user_id', user.id);
  }

  // Güncel paketi kullanıcının kendi oturumuyla hesapla
  const userClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: entitlement, error: entError } = await userClient.rpc('entitlement');
  if (entError) console.error('entitlement rpc', entError.message);

  return json({
    verified: true,
    productId: item.productId,
    state,
    expiryTime: expiry,
    entitlement: entitlement ?? null,
  });
});
