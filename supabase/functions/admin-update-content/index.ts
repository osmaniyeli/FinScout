// supabase/functions/admin-update-content/index.ts
//
// Yönetim paneli "İçerik / Metinler" sekmesinin YAZMA ucu (bkz. Web_Yonetici_Paneli/index.html
// tab-content, saveContentRow()). Panel public.app_content tablosuna DOĞRUDAN yazmaz — o tablonun
// RLS'i anon/authenticated için yalnız SELECT'e izin verir (bkz. supabase/migrations/
// 20260929120000_app_content_cms.sql). Bu fonksiyon paylaşılan bir sırla (ADMIN_PANEL_SECRET,
// Supabase secret olarak ayarlanır — asla koda veya panele gömülmez) doğrulama yapar ve yalnız
// doğrulanırsa service-role anahtarıyla (RLS'i bypass eder) satırı upsert eder.
//
// !!! DEPLOY EDİLMEDİ !!! — kod burada yalnız yazıldı. Devreye almak için (repo sahibi tarafından):
//   supabase functions deploy admin-update-content --project-ref oudxswtadqurmlnvcjyc
//   supabase secrets set ADMIN_PANEL_SECRET=<güçlü-bir-parola> --project-ref oudxswtadqurmlnvcjyc
// SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY, Supabase Edge Functions'ta proje bazında otomatik
// sağlanan ortam değişkenleridir; ayrıca ayarlanmaları gerekmez.
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

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'invalid_json' }, { status: 400, headers: cors });
  }

  const adminSecret = Deno.env.get('ADMIN_PANEL_SECRET');
  if (!adminSecret) {
    // Secret ayarlanmadan bu fonksiyon KİMSEYİ doğrulayamaz; açıkça 500 döner (sessizce
    // "her zaman izinli" olmaz — bu ciddi bir güvenlik hatası olurdu).
    console.error('ADMIN_PANEL_SECRET tanımlı değil (Supabase secret olarak ayarlanmalı)');
    return Response.json({ error: 'server_not_configured' }, { status: 500, headers: cors });
  }
  if (typeof body.admin_secret !== 'string' || body.admin_secret !== adminSecret) {
    return Response.json({ error: 'unauthorized' }, { status: 401, headers: cors });
  }

  const key = typeof body.key === 'string' ? body.key.trim() : '';
  const tr = typeof body.tr === 'string' ? body.tr : '';
  const en = typeof body.en === 'string' ? body.en : '';
  const category =
    typeof body.category === 'string' && body.category.trim() ? body.category.trim() : 'general';

  // tr/en boş bırakılabilir mi? Hayır: AppStrings.applyOverrides boş alanı yok sayıp sabit koda
  // düşer, yani panelden "boşalt" demek pratikte "değiştirme" anlamına gelir — kullanıcıyı
  // yanıltmamak için burada reddediyoruz; içerik gerçekten kaldırılacaksa satır silinmeli.
  if (!key || !tr || !en) {
    return Response.json(
      { error: 'missing_fields', detail: 'key, tr ve en alanlarının hepsi zorunlu (boş olamaz)' },
      { status: 400, headers: cors },
    );
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  const { data, error } = await admin
    .from('app_content')
    .upsert({ key, tr, en, category, updated_at: new Date().toISOString() }, { onConflict: 'key' })
    .select()
    .single();

  if (error) {
    console.error('app_content upsert failed', key, error.message);
    return Response.json({ error: 'write_failed', detail: error.message }, { status: 500, headers: cors });
  }

  console.log('app_content updated', key);
  return Response.json({ success: true, row: data }, { headers: cors });
});
