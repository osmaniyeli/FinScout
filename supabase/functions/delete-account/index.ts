// FinScout: kullanıcının kendi hesabını kalıcı olarak silmesi (Google Play hesap silme şartı).
// İstek atan kullanıcı JWT ile doğrulanır; yalnızca KENDİ hesabı silinir.
// profiles, key_envelopes, vault_blobs, devices, admin_roles satırları
// auth.users üzerindeki "on delete cascade" ile birlikte silinir.
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

  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: { user }, error: userError } = await admin.auth.getUser(jwt);
  if (userError || !user) {
    return Response.json({ error: 'unauthorized' }, { status: 401, headers: cors });
  }

  const { error } = await admin.auth.admin.deleteUser(user.id);
  if (error) {
    console.error('deleteUser failed', user.id, error.message);
    return Response.json({ error: 'delete_failed' }, { status: 500, headers: cors });
  }
  console.log('account deleted', user.id);
  return Response.json({ deleted: true }, { headers: cors });
});
