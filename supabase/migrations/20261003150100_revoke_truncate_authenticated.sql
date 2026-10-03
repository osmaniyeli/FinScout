-- PENDING — HENÜZ CANLIYA UYGULANMADI.
-- Onay: K43 ("Uygula") — Gece Raporu artifact, Kararlar sayfası, 2026-10-03.
-- Bulgu: docs/audit/security-audit.md SEC-13.
-- Bu oturumda apply_migration çağrısı Claude Code auto-mode "Modify Shared Resources"
-- sınıflandırıcısı tarafından engellendi. Uygulamak için: Supabase Dashboard > SQL Editor'a
-- yapıştır ve çalıştır, VEYA `supabase db push`.
--
-- Doğrulandı (2026-10-03, execute_sql ile salt-okunur): `authenticated` rolünün bu 4 tabloda
-- TRUNCATE yetkisi var, `anon`'un yok (bu revoke anon için no-op, zararsız). Bu yetkinin RLS'i
-- atlayabilmesi (TRUNCATE RLS politikalarına tabi değildir) gerçek ama şu an sömürülmeyen bir risk.

revoke truncate on public.admin_roles, public.profiles, public.vault_blobs, public.key_envelopes
  from authenticated, anon;
