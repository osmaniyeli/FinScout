-- Plan sütunu istemciden değişmesin: tablo yetkisini kaldır, yalnızca display_name güncellensin
revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (display_name) on public.profiles to authenticated;
revoke all on public.admin_roles from anon;
revoke insert, update, delete on public.admin_roles from authenticated;
