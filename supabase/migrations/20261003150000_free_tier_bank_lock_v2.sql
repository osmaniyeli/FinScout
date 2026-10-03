-- PENDING — HENÜZ CANLIYA UYGULANMADI.
-- Onay: K42 ("Uygula") — Gece Raporu artifact, Kararlar sayfası, 2026-10-03.
-- Bulgu: docs/audit/security-audit.md SEC-04.
-- Bu oturumda apply_migration çağrısı Claude Code auto-mode "Modify Shared Resources"
-- sınıflandırıcısı tarafından engellendi (üretim şemasına otomatik yazma izni yok).
-- Uygulamak için: Supabase Dashboard > SQL Editor'a yapıştır ve çalıştır, VEYA
-- `supabase db push` ile (servis rolü anahtarına erişimi olan bir ortamdan).
--
-- İstemci tarafı (moneytrace/lib/core/services/user_profile_service.dart consumeUpload) bu
-- migrasyonu bekleyecek şekilde ZATEN güncellendi (institution/periodEnd parametreleri eklendi)
-- ama RPC çağrısı hâlâ eski `consume_upload`'ı kullanıyor — bu migrasyon canlıya uygulandıktan
-- SONRA, consumeUpload içindeki `client.rpc('consume_upload', ...)` çağrısı
-- `client.rpc('consume_upload_v2', params: {...,'p_institution': institution,
-- 'p_period_end': periodEnd.toIso8601String().substring(0,10)})` olarak değiştirilip ayrıca
-- `res['reason'] == 'bank_locked'` dalı eklenmeli (bkz. security-audit.md SEC-04 örnek kod,
-- ya da bu konuşmanın önceki bir turunda yazılmış ama üretim fonksiyonu yokken geri alınan hâli).

alter table public.profiles add column if not exists locked_institution text;
-- profiles sütun yetkisi zaten yalnız display_name UPDATE: locked_institution istemciden yazılamaz.

create or replace function public.consume_upload_v2(
  p_doc_type text, p_is_backfill boolean default false,
  p_institution text default null, p_period_end date default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_plan text;
  v_lock text;
  v_month_start date := date_trunc('month', now() at time zone 'Europe/Istanbul')::date;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  select plan into v_plan from private.entitlement_for(v_uid);

  if v_plan = 'free' and p_doc_type in ('credit_card', 'checking') then
    if coalesce(trim(p_institution), '') = '' then
      raise exception 'institution_required' using errcode = '22023';
    end if;
    select locked_institution into v_lock from public.profiles where user_id = v_uid for update;
    if v_lock is null then
      update public.profiles set locked_institution = trim(p_institution) where user_id = v_uid;
    elsif v_lock <> trim(p_institution) then
      return jsonb_build_object('allowed', false, 'counted', false, 'reason', 'bank_locked',
                                'locked_institution', v_lock, 'plan', v_plan);
    end if;
  end if;

  -- Geçmiş dönem muafiyeti yalnız belge dönemi bu aydan önceyse
  if coalesce(p_is_backfill, false) and (p_period_end is null or p_period_end >= v_month_start) then
    p_is_backfill := false;
  end if;

  return public.consume_upload(p_doc_type, p_is_backfill);  -- mevcut sayaç/kilit mantığı
end; $$;
revoke all on function public.consume_upload_v2(text, boolean, text, date) from public, anon;
grant execute on function public.consume_upload_v2(text, boolean, text, date) to authenticated;
-- Banka değiştirme için ayrı, sınırlı RPC (ör. 30 günde bir) — Ayarlar > Banka akışı buna bağlanmalı,
-- bu migrasyonun kapsamı dışında, ayrı bir iş.
-- İstemci consume_upload_v2'ye geçtikten BİR SÜRE SONRA (eski app sürümleri çıkınca):
-- revoke execute on function public.consume_upload(text, boolean) from authenticated;
