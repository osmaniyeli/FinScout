-- FinScout: ücretsiz plan artık TOPLAM 1 belge değil, TÜR BAZLI 1 kredi kartı + 1 hesap ekstresi
-- (bordro ücretsizde hiç desteklenmiyor). Önceki private.plan_limit, 'free' için yalnız
-- total_limit=1 döndürüyordu (type_limit=null) — yani kullanıcı 1 kredi kartı yükledikten sonra
-- farklı türden (hesap ekstresi) bir belge de yükleyemiyordu; bu da istemcideki yeni
-- checkUploadQuota tür bazlı ön kontrolüyle (bkz. user_profile_service.dart) tutarsızdı:
-- istemci "yükleyebilirsin" derken sunucu consume_upload'da reddediyordu.
--
-- Aile paketindeki tür bazlı desenin (5 kart + 5 ekstre + 2 bordro) birebir küçültülmüş hali:
-- ücretsizde tür limiti kredi kartı=1, hesap ekstresi=1, bordro=0 (her zaman reddedilir).
-- total_limit=2 (1+1), aile paketindeki total_limit=12 (5+5+2) ile aynı mantık.
create or replace function private.plan_limit(p_plan text, p_doc_type text, out total_limit int, out type_limit int)
language sql immutable set search_path = '' as $$
  select case p_plan when 'free' then 2 when 'monthly' then 3 when 'annual' then 5 else 12 end,
         case p_plan
           when 'free' then
             case p_doc_type when 'credit_card' then 1 when 'checking' then 1 else 0 end
           when 'family' then
             case p_doc_type when 'credit_card' then 5 when 'checking' then 5 else 2 end
         end;
$$;
