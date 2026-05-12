-- ═════════════════════════════════════════════════════════════════════
-- 0004_v141_phase2_additive_write_policies_REVIEW_ONLY.sql
--
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  REVIEW ONLY — DO NOT APPLY YET                                 │
-- │  Phase 2 — additive write policies on legacy tables             │
-- │  Apply order will be: STAGING → verify → PROD, with explicit    │
-- │  human approval at each gate.                                   │
-- ╰─────────────────────────────────────────────────────────────────╯
--
-- Phase 2 of v1.4.1 lifecycle work. Adds 6 new RLS policies (3 tables
-- × 2 commands) on the legacy `config_assets`, `pm_schedule`, and
-- `cmc_contracts` tables. These policies grant INSERT and UPDATE to
-- users matching `public.app_can_write()` (admin or manager via
-- public.user_roles).
--
-- Phase 1 (migration 0003) created the helpers and seeded user_roles
-- but did NOT touch the legacy `admin_*` policies on these tables.
-- Today, only JWT app_metadata.role='admin' users can write — Manager
-- (role in user_roles) cannot. This migration closes that gap by
-- adding ADDITIVE policies that broaden write access to admin OR
-- manager via the security-definer helper.
--
-- ── Strict additive — NOT migrate ───────────────────────────────────
-- This migration does NOT drop, alter, or redefine any existing
-- `admin_*` or `auth_read_*` policies. PostgreSQL OR's permissive
-- policies, so:
--   * Admin (JWT app_metadata.role='admin'): satisfies legacy
--     admin_*_<table> AND new v141_*_<table>_app_can_write. Either
--     gate allows the write. No regression.
--   * Manager (user_roles.role='manager', app_meta_role='viewer'):
--     does NOT satisfy legacy admin_* (JWT path). Satisfies new
--     v141_*_app_can_write (via app_can_write() = true). Manager
--     writes are first-class via the new policy.
--   * Viewer/Engineer (user_roles.role='viewer'): satisfies neither.
--     Cannot write.
--
-- A follow-up migration (0006_* or later) may consolidate by dropping
-- the legacy admin_* write policies once Phase 2 has been stable for
-- 1-2 weeks. That is OUT OF SCOPE for this migration.
--
-- ── Commands covered ────────────────────────────────────────────────
-- For each of public.config_assets, public.pm_schedule, public.cmc_contracts:
--   - INSERT (with check app_can_write())
--   - UPDATE (using + with check app_can_write())
-- DELETE is INTENTIONALLY NOT added. Existing admin_delete_<table>
-- policies retain admin-only DELETE (JWT path). De-installation is
-- via UPDATE of status='de_installed' on config_assets, NOT DELETE.
--
-- ── Idempotency ─────────────────────────────────────────────────────
-- All policies are guarded with `drop policy if exists` + `create
-- policy`. Safe to re-apply.
--
-- ── Pre-requisites ──────────────────────────────────────────────────
-- 1. 0003 migration must already be applied (creates app_can_write()).
-- 2. user_roles must be seeded for the target environment so
--    app_can_write() returns sensible values.
-- ═════════════════════════════════════════════════════════════════════

-- ── §1. config_assets — additive INSERT + UPDATE ────────────────────
drop policy if exists "v141_config_assets_insert_app_can_write" on public.config_assets;
drop policy if exists "v141_config_assets_update_app_can_write" on public.config_assets;

create policy "v141_config_assets_insert_app_can_write"
  on public.config_assets for insert
  to authenticated
  with check ( public.app_can_write() );

create policy "v141_config_assets_update_app_can_write"
  on public.config_assets for update
  to authenticated
  using       ( public.app_can_write() )
  with check  ( public.app_can_write() );

-- DELETE not added. Manager cannot delete config_assets directly.
-- Existing admin_delete_config_assets retains JWT-admin-only DELETE.

-- ── §2. pm_schedule — additive INSERT + UPDATE ──────────────────────
drop policy if exists "v141_pm_schedule_insert_app_can_write" on public.pm_schedule;
drop policy if exists "v141_pm_schedule_update_app_can_write" on public.pm_schedule;

create policy "v141_pm_schedule_insert_app_can_write"
  on public.pm_schedule for insert
  to authenticated
  with check ( public.app_can_write() );

create policy "v141_pm_schedule_update_app_can_write"
  on public.pm_schedule for update
  to authenticated
  using       ( public.app_can_write() )
  with check  ( public.app_can_write() );

-- DELETE not added. PM rows shouldn't be deleted from the app; they
-- can be marked completed/skipped via UPDATE. Bulk delete remains
-- admin-only via the legacy policy.

-- ── §3. cmc_contracts — additive INSERT + UPDATE ────────────────────
drop policy if exists "v141_cmc_contracts_insert_app_can_write" on public.cmc_contracts;
drop policy if exists "v141_cmc_contracts_update_app_can_write" on public.cmc_contracts;

create policy "v141_cmc_contracts_insert_app_can_write"
  on public.cmc_contracts for insert
  to authenticated
  with check ( public.app_can_write() );

create policy "v141_cmc_contracts_update_app_can_write"
  on public.cmc_contracts for update
  to authenticated
  using       ( public.app_can_write() )
  with check  ( public.app_can_write() );

-- DELETE not added. CMC contracts shouldn't be deleted; expired
-- contracts persist as historical record. Admin retains DELETE via
-- legacy policy if a hard-delete is ever required.

-- ── §4. SELECT policies — UNCHANGED ─────────────────────────────────
-- The legacy auth_read_<table> policies on all three tables use
-- `using (true)` and grant SELECT to any authenticated user. That
-- already covers admin, manager, viewer/engineer. NO new SELECT
-- policy is needed.

-- ── End of 0004 ─────────────────────────────────────────────────────
