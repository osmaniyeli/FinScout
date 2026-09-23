-- Paraİz hesap + uçtan uca şifreli kasa şeması (GERI_BILDIRIM E1–E5)
-- Sunucu yalnızca şifreli blob görür; veri anahtarı (DK) cihazda üretilir,
-- sunucuya yalnızca kurtarma koduyla (Argon2id) sarılmış hali gelir.

-- 1) Profil: auth.users ile 1-1
create table public.profiles (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  plan         text not null default 'free'
               check (plan in ('free', 'individual', 'family')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- 2) Sarılmış veri anahtarları (kurtarma kodu / ileride passkey)
create table public.key_envelopes (
  user_id     uuid not null references auth.users (id) on delete cascade,
  kind        text not null check (kind in ('recovery')),
  wrapped_dk  text not null,          -- base64(AES-256-GCM(DK))
  nonce       text not null,          -- base64
  kdf         jsonb not null,         -- {"alg":"argon2id","salt":"..","m":..,"t":..,"p":..}
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  primary key (user_id, kind)
);

-- 3) Şifreli kasa: SQLite dökümü / varlık JSON'u parça parça
create table public.vault_blobs (
  user_id     uuid not null references auth.users (id) on delete cascade,
  blob_id     text not null,          -- ör. 'db', 'assets'
  ciphertext  text not null,          -- base64(AES-256-GCM)
  nonce       text not null,
  version     integer not null default 1,
  size_bytes  integer not null default 0,
  updated_at  timestamptz not null default now(),
  primary key (user_id, blob_id)
);

-- 4) Cihazlar (FCM push)
create table public.devices (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  fcm_token    text not null unique,
  platform     text not null default 'android',
  app_version  text,
  last_seen_at timestamptz not null default now()
);
create index devices_user_id_idx on public.devices (user_id);

-- 5) Yönetici rolleri (yalnızca service_role / SQL ile atanır)
create table public.admin_roles (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  role       text not null default 'admin' check (role in ('admin')),
  created_at timestamptz not null default now()
);

-- RLS: herkes yalnızca kendi satırı
alter table public.profiles      enable row level security;
alter table public.key_envelopes enable row level security;
alter table public.vault_blobs   enable row level security;
alter table public.devices       enable row level security;
alter table public.admin_roles   enable row level security;

create policy "own profile read"   on public.profiles for select to authenticated using ((select auth.uid()) = user_id);
create policy "own profile update" on public.profiles for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "own envelopes" on public.key_envelopes for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "own vault" on public.vault_blobs for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "own devices" on public.devices for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "own admin role read" on public.admin_roles for select to authenticated
  using ((select auth.uid()) = user_id);

-- Plan istemciden değiştirilemez (satın alma doğrulaması sunucuda yapılacak);
-- sütun bazlı revoke tablo yetkisi varken işe yaramaz → dar grant
revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (display_name) on public.profiles to authenticated;
revoke insert, update, delete on public.admin_roles from authenticated;
revoke all on public.profiles, public.key_envelopes, public.vault_blobs, public.devices, public.admin_roles from anon;

-- updated_at
create function public.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
create trigger profiles_touch      before update on public.profiles      for each row execute function public.touch_updated_at();
create trigger key_envelopes_touch before update on public.key_envelopes for each row execute function public.touch_updated_at();
create trigger vault_blobs_touch   before update on public.vault_blobs   for each row execute function public.touch_updated_at();

-- Kayıtta profil oluştur
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (user_id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'));
  return new;
end;
$$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Yönetici kontrolü (Edge Function / panel için)
create function public.is_admin() returns boolean
language sql stable security invoker set search_path = '' as $$
  select exists (select 1 from public.admin_roles where user_id = (select auth.uid()));
$$;
revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;
