// FinScout: uçtan uca şifreli otomatik yedekleme için, kullanıcının HİÇBİR ŞEY hatırlamasına
// gerek kalmayan, hesaba bağlı bir şifreleme anahtarı üretir.
//
// Anahtar kullanıcı kimliğinden (auth.users.id) HMAC-SHA256 ile DETERMİNİSTİK türetilir:
// aynı kullanıcı için her zaman, her cihazda, her oturumda AYNI 32 baytlık anahtarı verir.
// Sunucuda hiçbir yerde saklanmaz (yalnız sunucu-taraflı bir gizli anahtardan anlık hesaplanır);
// istemci bu anahtarı diske yazmaz, yalnız bellekte (oturum boyunca) tutar.
//
// İstek atan kullanıcı JWT ile doğrulanır; yanıt yalnızca İSTEĞİ ATAN kullanıcının kendi anahtarıdır.
import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') {
    return Response.json({ error: 'method_not_allowed' }, { status: 405, headers: cors });
  }

  const url = Deno.env.get('SUPABASE_URL')!;
  const jwt = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!jwt) return Response.json({ error: 'unauthorized' }, { status: 401, headers: cors });

  const secret = Deno.env.get('BACKUP_KEY_SECRET');
  if (!secret) {
    console.error('backup-key: BACKUP_KEY_SECRET tanımlı değil');
    return Response.json({ error: 'server_misconfigured' }, { status: 503, headers: cors });
  }

  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: { user }, error: userError } = await admin.auth.getUser(jwt);
  if (userError || !user) {
    return Response.json({ error: 'unauthorized' }, { status: 401, headers: cors });
  }

  try {
    // HMAC-SHA256(sunucu gizli anahtarı, kullanıcı id'si) → 32 bayt, tamamen deterministik.
    // Kullanıcının oturumundan veya cihazından bağımsızdır: hangi cihazdan/hangi oturumdan
    // istenirse istensin aynı kullanıcı için hep aynı sonucu verir — bu yüzden başka bir
    // cihazda geri yükleme yapılabilir.
    const hmacKey = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign'],
    );
    const signature = await crypto.subtle.sign('HMAC', hmacKey, new TextEncoder().encode(user.id));
    const keyBase64 = btoa(String.fromCharCode(...new Uint8Array(signature)));

    return Response.json({ keyBase64 }, { headers: cors });
  } catch (e) {
    console.error('backup-key: anahtar türetilemedi', user.id, e);
    return Response.json({ error: 'key_derivation_failed' }, { status: 503, headers: cors });
  }
});
