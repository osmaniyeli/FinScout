-- FinScout: yönetici push bildirimleri (Firebase Cloud Messaging).
-- Cihaz kaydı istemciden yalnız register_device RPC'siyle (token başka hesaptaysa taşınır);
-- gönderim yalnız send-push Edge Function'ı (service_role) ile, çağıranın admin olduğu doğrulanarak.

-- 1) Cihaz kaydı: aynı telefonda hesap değişince token eski hesaptan bu hesaba taşınır.
--    (devices.fcm_token unique; RLS başka hesabın satırını güncellemeye izin vermez → definer RPC)
create function public.register_device(p_token text, p_platform text default 'android', p_app_version text default null)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_token is null or length(p_token) < 20 or length(p_token) > 4096 then
    raise exception 'invalid_token' using errcode = '22023';
  end if;
  insert into public.devices (user_id, fcm_token, platform, app_version, last_seen_at)
  values (v_uid, p_token, coalesce(left(p_platform, 20), 'android'), left(p_app_version, 40), now())
  on conflict (fcm_token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        app_version = excluded.app_version,
        last_seen_at = now();
end;
$$;
revoke execute on function public.register_device(text, text, text) from public, anon;
grant execute on function public.register_device(text, text, text) to authenticated;

-- İstemci tabloya doğrudan yalnız kendi satırını okur/siler (çıkışta); yazma RPC ile.
revoke insert, update, truncate on public.devices from authenticated;

-- 2) E-postadan kullanıcı kimliği: yalnız send-push (service_role) kullanır.
create function public.admin_user_id_by_email(p_email text)
returns uuid language sql stable security definer set search_path = '' as $$
  select id from auth.users where lower(email) = lower(trim(p_email)) limit 1;
$$;
revoke execute on function public.admin_user_id_by_email(text) from public, anon, authenticated;
grant execute on function public.admin_user_id_by_email(text) to service_role;

-- 3) Gönderim geçmişi (yalnız admin okur; yazma yalnız service_role)
create table public.admin_notifications (
  id           uuid primary key default gen_random_uuid(),
  sent_by      uuid references auth.users (id) on delete set null,
  title        text not null check (length(title) between 1 and 100),
  body         text not null check (length(body) between 1 and 1000),
  target       text not null,
  sent_count   int  not null default 0,
  failed_count int  not null default 0,
  created_at   timestamptz not null default now()
);
create index admin_notifications_created_idx on public.admin_notifications (created_at desc);
create index admin_notifications_sent_by_idx on public.admin_notifications (sent_by);
alter table public.admin_notifications enable row level security;
create policy "admin reads notifications" on public.admin_notifications for select to authenticated
  using ((select public.is_admin()));
revoke all on public.admin_notifications from anon;
revoke insert, update, delete, truncate on public.admin_notifications from authenticated;
