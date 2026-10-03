-- PENDING — HENÜZ CANLIYA UYGULANMADI.
-- Onay: K44 ("Uygula") — Gece Raporu artifact, Kararlar sayfası, 2026-10-03.
-- Not (kullanıcı): "bunu atlarsak canlıya alma aşamasında kullanıcı deneyimi olumsuz etkilenir.
-- bu bizim mustlarımızdan. atlamayalım" — K42/K43'ten yüksek öncelikli kabul edilmeli.
-- Bulgu: docs/audit/security-audit.md SEC-02, SEC-14.
-- Bu oturumda apply_migration çağrısı Claude Code auto-mode "Modify Shared Resources"
-- sınıflandırıcısı tarafından engellendi. Uygulamak için: Supabase Dashboard > SQL Editor'a
-- yapıştır ve çalıştır, VEYA `supabase db push`.
--
-- Doğrulandı (2026-10-03, execute_sql ile salt-okunur): canlıdaki en büyük `ciphertext` 45.084
-- bayt (2 satır, ikisi de blob_id='full_backup') — yeni CHECK kısıtlarının ikisi de mevcut
-- veriyle UYUMLU, migrasyon mevcut satırları bozmaz.

alter table public.vault_blobs
  add constraint vault_blobs_blob_id_check check (blob_id = 'full_backup'),
  add constraint vault_blobs_size_check check (octet_length(ciphertext) <= 20 * 1024 * 1024);

create table if not exists private.vault_blob_history (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  blob_id text not null, ciphertext text not null, size_bytes int,
  replaced_at timestamptz not null default now());

create or replace function private.keep_vault_history() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into private.vault_blob_history (user_id, blob_id, ciphertext, size_bytes)
  values (old.user_id, old.blob_id, old.ciphertext, old.size_bytes);
  delete from private.vault_blob_history h
   where h.user_id = old.user_id and h.id not in (
     select id from private.vault_blob_history where user_id = old.user_id order by id desc limit 5);
  return new;
end; $$;
create trigger vault_blobs_history before update on public.vault_blobs
  for each row when (old.ciphertext is distinct from new.ciphertext)
  execute function private.keep_vault_history();
-- Not: geçmiş tablosu hesap silmede cascade ile silinir; gizlilik metninde "son 5 sürüm" belirtilmeli.
