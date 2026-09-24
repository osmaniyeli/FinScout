-- FinScout: sunucu tarafı abonelik doğrulaması, aylık belge kotası ve Aile paketi.
-- Yazma yolları: subscriptions yalnız verify-purchase Edge Function'ı (service_role) ile;
-- kota ve aile tabloları yalnız aşağıdaki security definer RPC'lerle. İstemcinin tablo yazma yetkisi yok.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- 1) Doğrulanmış Google Play abonelikleri
create table public.subscriptions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,
  product_id      text not null check (product_id in (
                    'finscout_individual_monthly', 'finscout_individual_annual', 'finscout_family_annual_4p')),
  purchase_token  text not null unique,            -- aynı makbuz iki hesaba bağlanamaz
  state           text not null,                   -- ACTIVE, IN_GRACE_PERIOD, CANCELED, ON_HOLD, PAUSED, EXPIRED, PENDING, REPLACED ...
  expiry_time     timestamptz,
  auto_renewing   boolean not null default false,
  test_purchase   boolean not null default false,
  verified_at     timestamptz not null default now(),
  created_at      timestamptz not null default now()
);
create index subscriptions_user_id_idx on public.subscriptions (user_id);

-- 2) Aylık belge kullanımı (Europe/Istanbul takvim ayı)
create table public.document_uploads (
  user_id   uuid not null references auth.users (id) on delete cascade,
  period    text not null check (period ~ '^\d{4}-\d{2}$'),
  doc_type  text not null check (doc_type in ('credit_card', 'checking', 'payroll')),
  count     integer not null default 0 check (count >= 0),
  primary key (user_id, period, doc_type)
);

-- 3) Aile
create table public.families (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null unique references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now()
);

create table public.family_members (
  family_id  uuid not null references public.families (id) on delete cascade,
  user_id    uuid not null unique references auth.users (id) on delete cascade,  -- bir kişi tek ailede
  role       text not null default 'member' check (role in ('owner', 'member')),
  joined_at  timestamptz not null default now(),
  primary key (family_id, user_id)
);

create table public.family_invites (
  code        text primary key,
  family_id   uuid not null references public.families (id) on delete cascade,
  created_by  uuid not null references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null,
  used_by     uuid references auth.users (id) on delete set null,
  used_at     timestamptz
);
create index family_invites_family_id_idx on public.family_invites (family_id);
create index family_invites_created_by_idx on public.family_invites (created_by);
create index family_invites_used_by_idx on public.family_invites (used_by);

-- RLS: yalnız kendi satırını okuma; yazma yok
alter table public.subscriptions    enable row level security;
alter table public.document_uploads enable row level security;
alter table public.families         enable row level security;
alter table public.family_members   enable row level security;
alter table public.family_invites   enable row level security;

create policy "own subscriptions read" on public.subscriptions for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "own uploads read" on public.document_uploads for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "own family read" on public.families for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy "own membership read" on public.family_members for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "own invites read" on public.family_invites for select to authenticated
  using ((select auth.uid()) = created_by);

revoke all on public.subscriptions, public.document_uploads, public.families,
              public.family_members, public.family_invites from anon, authenticated;
grant select on public.subscriptions, public.document_uploads, public.families,
                public.family_members, public.family_invites to authenticated;

-- ---------------------------------------------------------------------------
-- Yardımcılar (private şema: PostgREST'ten çağrılamaz)
-- ---------------------------------------------------------------------------

-- Abonelik satırı şu an hak veriyor mu (CANCELED: dönem sonuna kadar geçerli)
create function private.sub_is_active(p_state text, p_expiry timestamptz)
returns boolean language sql stable set search_path = '' as $$
  select p_state in ('ACTIVE', 'IN_GRACE_PERIOD', 'CANCELED')
     and p_expiry is not null and p_expiry > now();
$$;

-- Kullanıcının etkin paketi: kendi aboneliği ya da üyesi olduğu ailenin SAHİBİNİN aile aboneliği.
-- plan: 'free' | 'monthly' | 'annual' | 'family'; source: 'none' | 'own' | 'family'
create function private.entitlement_for(p_uid uuid)
returns table (plan text, product_id text, expiry_time timestamptz, source text, family_owner uuid)
language sql stable security definer set search_path = '' as $$
  select x.plan, x.product_id, x.expiry_time, x.source, x.family_owner
  from (
    select case s.product_id
             when 'finscout_family_annual_4p' then 'family'
             when 'finscout_individual_annual' then 'annual'
             else 'monthly' end as plan,
           s.product_id, s.expiry_time, 'own'::text as source, null::uuid as family_owner
    from public.subscriptions s
    where s.user_id = p_uid and private.sub_is_active(s.state, s.expiry_time)
    union all
    select 'family', s.product_id, s.expiry_time, 'family', f.owner_id
    from public.family_members m
    join public.families f on f.id = m.family_id and f.owner_id <> p_uid
    join public.subscriptions s on s.user_id = f.owner_id
                               and s.product_id = 'finscout_family_annual_4p'
    where m.user_id = p_uid and private.sub_is_active(s.state, s.expiry_time)
    union all
    select 'free', null, null, 'none', null
  ) x
  order by case x.plan when 'family' then 3 when 'annual' then 2 when 'monthly' then 1 else 0 end desc,
           x.expiry_time desc nulls last
  limit 1;
$$;

create function private.owner_has_family_sub(p_owner uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.subscriptions s
    where s.user_id = p_owner and s.product_id = 'finscout_family_annual_4p'
      and private.sub_is_active(s.state, s.expiry_time));
$$;

create function private.current_period()
returns text language sql stable set search_path = '' as $$
  select to_char(now() at time zone 'Europe/Istanbul', 'YYYY-MM');
$$;

-- Plan limitleri: toplam limit ve türe özgü limit (null = sınırsız)
create function private.plan_limit(p_plan text, p_doc_type text, out total_limit int, out type_limit int)
language sql immutable set search_path = '' as $$
  select case p_plan when 'free' then 1 when 'monthly' then 3 when 'annual' then 5 else 12 end,
         case when p_plan = 'family' then
           case p_doc_type when 'credit_card' then 5 when 'checking' then 5 else 2 end
         end;
$$;

create function private.usage_json(p_uid uuid, p_period text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'credit_card', coalesce(max(count) filter (where doc_type = 'credit_card'), 0),
    'checking',    coalesce(max(count) filter (where doc_type = 'checking'), 0),
    'payroll',     coalesce(max(count) filter (where doc_type = 'payroll'), 0))
  from public.document_uploads where user_id = p_uid and period = p_period;
$$;

revoke all on all functions in schema private from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Genel RPC'ler (yalnız authenticated)
-- ---------------------------------------------------------------------------

-- Etkin paket + bu ayın belge kullanımı
create function public.entitlement()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  e record;
  v_period text := private.current_period();
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  select * into e from private.entitlement_for(v_uid);
  return jsonb_build_object(
    'plan', e.plan,
    'product_id', e.product_id,
    'expiry_time', e.expiry_time,
    'source', e.source,
    'period', v_period,
    'usage', private.usage_json(v_uid, v_period),
    'backfill_until', (select u.created_at + interval '30 days' from auth.users u where u.id = v_uid));
end;
$$;

-- Belge kotasını atomik olarak tüketir. Limit doluysa allowed=false döner, sayaç artmaz.
-- p_is_backfill: istemci belgenin içinde bulunulan aydan önceki döneme ait olduğunu bildirir;
-- sunucu yalnızca hesabın ilk 30 gününde bunu kotasız sayar.
create function public.consume_upload(p_doc_type text, p_is_backfill boolean default false)
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

  return jsonb_build_object('allowed', true, 'counted', true, 'plan', v_plan, 'period', v_period,
    'usage', private.usage_json(v_uid, v_period), 'total_limit', v_total_limit, 'type_limit', v_type_limit);
end;
$$;

-- Aile sahibi davet kodu üretir (48 saat, tek kullanımlık; önceki kullanılmamış kodlar geçersiz olur)
create function public.create_family_invite()
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_family uuid;
  v_code text;
  v_bytes bytea;
  v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';  -- 32 karakter, karışabilenler yok
  v_expires timestamptz := now() + interval '48 hours';
  i int;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  if not private.owner_has_family_sub(v_uid) then
    raise exception 'no_family_subscription' using errcode = 'P0001';
  end if;

  select id into v_family from public.families where owner_id = v_uid;
  if v_family is null then
    if exists (select 1 from public.family_members where user_id = v_uid) then
      raise exception 'already_in_family' using errcode = 'P0001';
    end if;
    insert into public.families (owner_id) values (v_uid) returning id into v_family;
    insert into public.family_members (family_id, user_id, role) values (v_family, v_uid, 'owner');
  end if;

  if (select count(*) from public.family_members where family_id = v_family) >= 4 then
    raise exception 'family_full' using errcode = 'P0001';
  end if;

  delete from public.family_invites where family_id = v_family and used_by is null;

  loop
    v_bytes := extensions.gen_random_bytes(8);
    v_code := '';
    for i in 0..7 loop
      v_code := v_code || substr(v_alphabet, (get_byte(v_bytes, i) % 32) + 1, 1);
    end loop;
    exit when not exists (select 1 from public.family_invites where code = v_code);
  end loop;

  insert into public.family_invites (code, family_id, created_by, expires_at)
  values (v_code, v_family, v_uid, v_expires);
  return jsonb_build_object('code', v_code, 'expires_at', v_expires);
end;
$$;

-- Davet koduyla aileye katılma
create function public.join_family(p_code text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_code text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  inv record;
  v_owner uuid;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  if exists (select 1 from public.family_members where user_id = v_uid) then
    raise exception 'already_in_family' using errcode = 'P0001';
  end if;

  select * into inv from public.family_invites where code = v_code for update;
  if not found or inv.used_by is not null or inv.expires_at <= now() then
    raise exception 'invalid_code' using errcode = 'P0001';
  end if;

  -- Üye sınırı için aile satırını kilitle (eşzamanlı katılımlar sıraya girer)
  select owner_id into v_owner from public.families where id = inv.family_id for update;
  if v_owner is null or v_owner = v_uid then
    raise exception 'invalid_code' using errcode = 'P0001';
  end if;
  if not private.owner_has_family_sub(v_owner) then
    raise exception 'owner_subscription_inactive' using errcode = 'P0001';
  end if;
  if (select count(*) from public.family_members where family_id = inv.family_id) >= 4 then
    raise exception 'family_full' using errcode = 'P0001';
  end if;

  insert into public.family_members (family_id, user_id, role) values (inv.family_id, v_uid, 'member');
  update public.family_invites set used_by = v_uid, used_at = now() where code = v_code;
  return jsonb_build_object('joined', true);
end;
$$;

-- Aileden ayrılma. Sahip ayrılırsa aile dağılır (tüm üyelikler ve davetler silinir).
create function public.leave_family()
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  m record;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  select family_id, role into m from public.family_members where user_id = v_uid;
  if not found then return jsonb_build_object('left', false); end if;
  if m.role = 'owner' then
    delete from public.families where id = m.family_id and owner_id = v_uid;
    return jsonb_build_object('left', true, 'dissolved', true);
  end if;
  delete from public.family_members where user_id = v_uid and family_id = m.family_id;
  return jsonb_build_object('left', true, 'dissolved', false);
end;
$$;

-- Sahip bir üyeyi çıkarır
create function public.remove_family_member(p_user_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_family uuid;
  v_n int;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  select id into v_family from public.families where owner_id = v_uid;
  if v_family is null then raise exception 'not_family_owner' using errcode = 'P0001'; end if;
  if p_user_id = v_uid then raise exception 'cannot_remove_owner' using errcode = 'P0001'; end if;
  delete from public.family_members
   where family_id = v_family and user_id = p_user_id and role = 'member';
  get diagnostics v_n = row_count;
  return jsonb_build_object('removed', v_n > 0);
end;
$$;

-- Ailem: rol, üyeler (ad + maskeli e-posta), sahip aboneliği etkin mi, sahip için aktif davet kodu
create function public.my_family()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  m record;
  v_owner uuid;
  v_members jsonb;
  v_invite jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  select family_id, role into m from public.family_members where user_id = v_uid;
  if not found then
    return jsonb_build_object('in_family', false,
      'can_create', private.owner_has_family_sub(v_uid), 'max_members', 4);
  end if;
  select owner_id into v_owner from public.families where id = m.family_id;

  select coalesce(jsonb_agg(jsonb_build_object(
           'user_id', fm.user_id,
           'role', fm.role,
           'is_me', fm.user_id = v_uid,
           'display_name', coalesce(nullif(trim(p.display_name), ''), split_part(u.email, '@', 1)),
           'email_masked', case when u.email is null then null
                                else left(u.email, 1) || '***@' || split_part(u.email, '@', 2) end,
           'joined_at', fm.joined_at)
         order by (fm.role = 'owner') desc, fm.joined_at), '[]'::jsonb)
    into v_members
    from public.family_members fm
    left join public.profiles p on p.user_id = fm.user_id
    left join auth.users u on u.id = fm.user_id
   where fm.family_id = m.family_id;

  if m.role = 'owner' then
    select jsonb_build_object('code', i.code, 'expires_at', i.expires_at) into v_invite
      from public.family_invites i
     where i.family_id = m.family_id and i.used_by is null and i.expires_at > now()
     order by i.created_at desc limit 1;
  end if;

  return jsonb_build_object(
    'in_family', true,
    'role', m.role,
    'max_members', 4,
    'owner_active', private.owner_has_family_sub(v_owner),
    'members', v_members,
    'invite', v_invite);
end;
$$;

revoke all on function public.entitlement(), public.consume_upload(text, boolean),
  public.create_family_invite(), public.join_family(text), public.leave_family(),
  public.remove_family_member(uuid), public.my_family() from public, anon;
grant execute on function public.entitlement(), public.consume_upload(text, boolean),
  public.create_family_invite(), public.join_family(text), public.leave_family(),
  public.remove_family_member(uuid), public.my_family() to authenticated;
