-- ═════════════════════════════════════════════════════════════════════
-- 0003_asset_lifecycle_phase1_ROLLBACK_REVIEW_ONLY.sql
--
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  REVIEW ONLY — DO NOT APPLY TO STAGING OR PRODUCTION YET        │
-- │  Mirror of 0003_asset_lifecycle_phase1. Reverses the schema     │
-- │  additions in reverse order. Does NOT preserve any data written │
-- │  to asset_lifecycle / asset_lifecycle_history — running this    │
-- │  rollback will DROP those tables and all rows in them.          │
-- ╰─────────────────────────────────────────────────────────────────╯
--
-- Use only if 0003 caused a regression that cannot be forward-fixed.
-- The expected execution sequence for rollback is:
--   1. Stop all writers (app deploy on hold).
--   2. Snapshot db (Supabase backup or pg_dump of public.*).
--   3. Run this rollback in STAGING and verify.
--   4. Run this rollback in PROD with explicit human approval.
--
-- The rollback does NOT remove the new config_assets columns by
-- default, because those columns are nullable/defaulted and pose no
-- runtime risk if left in place. Removing them is gated behind the
-- final block — uncomment only if you are sure no other code reads
-- them.
-- ═════════════════════════════════════════════════════════════════════

-- ── 1. Drop policies (reverse of 0003 §5) ───────────────────────────
drop policy if exists "v141_lifecycle_select_authenticated" on public.asset_lifecycle;
drop policy if exists "v141_lifecycle_insert_admin_manager" on public.asset_lifecycle;
drop policy if exists "v141_lifecycle_update_admin_manager" on public.asset_lifecycle;
drop policy if exists "v141_lifecycle_no_delete"            on public.asset_lifecycle;
drop policy if exists "v141_history_select_authenticated"   on public.asset_lifecycle_history;
drop policy if exists "v141_history_insert_authenticated"   on public.asset_lifecycle_history;
drop policy if exists "v141_history_no_update"              on public.asset_lifecycle_history;
drop policy if exists "v141_history_no_delete"              on public.asset_lifecycle_history;

-- ── 2. Drop triggers + helper function (reverse of 0003 §4) ─────────
drop trigger  if exists trg_asset_lifecycle_touch on public.asset_lifecycle;
drop trigger  if exists trg_config_assets_touch   on public.config_assets;
-- Drop the function only if no other table has a trigger on it.
do $$
begin
  if not exists (
    select 1 from pg_trigger t
    join pg_proc p on p.oid = t.tgfoid
    where p.proname = '_touch_updated_at'
      and not t.tgisinternal
  ) then
    drop function if exists public._touch_updated_at();
  end if;
end $$;

-- ── 3. Drop history table (reverse of 0003 §3) ──────────────────────
-- All rows in asset_lifecycle_history are dropped.
drop table if exists public.asset_lifecycle_history cascade;

-- ── 4. Drop lifecycle table (reverse of 0003 §2) ────────────────────
-- All rows in asset_lifecycle are dropped.
drop table if exists public.asset_lifecycle cascade;

-- ── 5. config_assets columns (reverse of 0003 §1) ───────────────────
-- LEFT IN PLACE BY DEFAULT. These columns are nullable / defaulted and
-- cause no harm. To fully remove them, uncomment the block below.
-- BEFORE UNCOMMENTING: confirm that no app code, no view, and no other
-- migration references status / de_installed_at / created_by / etc.

-- alter table public.config_assets
--   drop column if exists note,
--   drop column if exists updated_by,
--   drop column if exists updated_at,
--   drop column if exists created_by,
--   drop column if exists created_at,
--   drop column if exists de_installed_by,
--   drop column if exists de_installed_at,
--   drop column if exists status;
-- drop index if exists public.config_assets_status_idx;
-- drop index if exists public.config_assets_active_idx;

-- ── 6. Defensive unique index on config_assets.code ─────────────────
-- 0003 §0 only created this index if no PK/UNIQUE existed on `code`.
-- Drop only if it was created by 0003 (recognizable by the
-- 'config_assets_code_uidx' name).
drop index if exists public.config_assets_code_uidx;

-- ── End of rollback ─────────────────────────────────────────────────
