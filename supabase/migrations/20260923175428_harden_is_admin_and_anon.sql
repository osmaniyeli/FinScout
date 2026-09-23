-- is_admin RLS ile kendi satırını okuyabildiği için definer gerekmez; anon hiçbir tabloya dokunamaz
alter function public.is_admin() security invoker;
revoke all on public.profiles, public.key_envelopes, public.vault_blobs, public.devices, public.admin_roles from anon;
