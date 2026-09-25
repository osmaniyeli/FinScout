-- FinScout: belge kotası iadesi.
-- consume_upload kotayı kayıttan ÖNCE sunucuda düşer. Cihazdaki kayıt (SQLite) bundan sonra hata
-- verirse istemci refund_upload ile o tek tüketimi geri alır.
--
-- Kötüye kullanım sınırları:
--   * Her sayılan tüketim bir satır (upload_consumptions) ve id alır; consume_upload bu id'yi
--     'consumption_id' olarak döndürür (ek alan, geriye uyumlu: eski istemciler yok sayar).
--   * İade yalnız o id ile, yalnız sahibi (auth.uid()) tarafından, tüketimden sonraki 15 dakika içinde
--     ve bir kez yapılabilir.
--   * Kullanıcı başına bir takvim ayında en fazla 3 iade (kayıt hatası nadirdir; istemci iadeyi başarılı
--     kayıttan sonra da çağırabileceği için bu tavan kota kaçırmayı sınırlar).
--   * Tablo istemciye yalnız okunur (kendi satırları); yazma yalnız security definer RPC'lerle.

create table public.upload_consumptions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  period       text not null check (period ~ '^\d{4}-\d{2}$'),
  doc_type     text not null check (doc_type in ('credit_card', 'checking', 'payroll')),
  consumed_at  timestamptz not null default now(),
  refunded_at  timestamptz
);
create index upload_consumptions_user_period_idx on public.upload_consumptions (user_id, period);

alter table public.upload_consumptions enable row level security;
create policy "own consumptions read" on public.upload_consumptions for select to authenticated
  using ((select auth.uid()) = user_id);
revoke all on public.upload_consumptions from anon, authenticated;
grant select on public.upload_consumptions to authenticated;

-- consume_upload: davranış aynı; sayılan tüketim kaydedilir ve id'si döner.
create or replace function public.consume_upload(p_doc_type text, p_is_backfill boolean default false)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_period text := private.current_period();
  v_plan text;
  v_total_limit int;
  v_type_limit int;
  v_total int;
  v_type int;
  v_created timestamptz;
  v_consumption uuid;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  if p_doc_type not in ('credit_card', 'checking', 'payroll') then
    raise exception 'invalid_doc_type' using errcode = '22023';
  end if;

  select plan into v_plan from private.entitlement_for(v_uid);
  select l.total_limit, l.type_limit into v_total_limit, v_type_limit
    from private.plan_limit(v_plan, p_doc_type) l;

  if coalesce(p_is_backfill, false) then
    select created_at into v_created from auth.users where id = v_uid;
    if v_created > now() - interval '30 days' then
      return jsonb_build_object('allowed', true, 'counted', false, 'plan', v_plan, 'period', v_period,
        'usage', private.usage_json(v_uid, v_period), 'total_limit', v_total_limit, 'type_limit', v_type_limit);
    end if;
  end if;

  -- Aynı kullanıcının aynı aydaki eşzamanlı çağrıları sıraya girer (toplam limit türler arası olduğu için)
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':' || v_period, 0));

  select coalesce(sum(count), 0), coalesce(sum(count) filter (where doc_type = p_doc_type), 0)
    into v_total, v_type
    from public.document_uploads where user_id = v_uid and period = v_period;

  if v_total >= v_total_limit or (v_type_limit is not null and v_type >= v_type_limit) then
    return jsonb_build_object('allowed', false, 'counted', false, 'plan', v_plan, 'period', v_period,
      'usage', private.usage_json(v_uid, v_period), 'total_limit', v_total_limit, 'type_limit', v_type_limit);
  end if;

  insert into public.document_uploads as d (user_id, period, doc_type, count)
  values (v_uid, v_period, p_doc_type, 1)
  on conflict (user_id, period, doc_type) do update set count = d.count + 1;

  insert into public.upload_consumptions (user_id, period, doc_type)
  values (v_uid, v_period, p_doc_type)
  returning id into v_consumption;

  return jsonb_build_object('allowed', true, 'counted', true, 'plan', v_plan, 'period', v_period,
    'usage', private.usage_json(v_uid, v_period), 'total_limit', v_total_limit, 'type_limit', v_type_limit,
    'consumption_id', v_consumption);
end;
$$;

-- Tek bir tüketimi geri alır (kayıt hatası sonrası). Hata kodları (P0001):
--   consumption_not_found  : id yok ya da başka kullanıcıya ait (ayrım yapılmaz)
--   already_refunded       : bu tüketim daha önce iade edildi
--   refund_window_expired  : tüketimin üzerinden 15 dakikadan fazla geçti
--   refund_limit_reached   : bu ay 3 iade yapıldı
create function public.refund_upload(p_consumption_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  c record;
  v_refunds int;
  v_now_period text := private.current_period();
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;

  select * into c from public.upload_consumptions
   where id = p_consumption_id and user_id = v_uid
   for update;
  if not found then raise exception 'consumption_not_found' using errcode = 'P0001'; end if;
  if c.refunded_at is not null then raise exception 'already_refunded' using errcode = 'P0001'; end if;
  if c.consumed_at < now() - interval '15 minutes' then
    raise exception 'refund_window_expired' using errcode = 'P0001';
  end if;

  -- consume_upload ile aynı kilit: sayaç değişiklikleri sıraya girer
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':' || c.period, 0));

  select count(*) into v_refunds from public.upload_consumptions
   where user_id = v_uid and period = c.period and refunded_at is not null;
  if v_refunds >= 3 then raise exception 'refund_limit_reached' using errcode = 'P0001'; end if;

  update public.document_uploads
     set count = count - 1
   where user_id = v_uid and period = c.period and doc_type = c.doc_type and count > 0;
  update public.upload_consumptions set refunded_at = now() where id = c.id;

  return jsonb_build_object('refunded', true, 'period', v_now_period,
    'usage', private.usage_json(v_uid, v_now_period));
end;
$$;

revoke all on function public.consume_upload(text, boolean), public.refund_upload(uuid) from public, anon;
grant execute on function public.consume_upload(text, boolean), public.refund_upload(uuid) to authenticated;
