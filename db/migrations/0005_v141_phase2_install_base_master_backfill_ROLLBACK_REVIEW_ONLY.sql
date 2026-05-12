-- ═════════════════════════════════════════════════════════════════════
-- 0005_v141_phase2_install_base_master_backfill_ROLLBACK_REVIEW_ONLY.sql
--
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  REVIEW ONLY — DO NOT APPLY YET                                 │
-- │  Mirror of 0005 — removes only the rows tagged with the         │
-- │  v1.4.1 phase 2 backfill note. Pre-existing rows untouched.     │
-- ╰─────────────────────────────────────────────────────────────────╯
--
-- Use only if 0005 inserted incorrect data and the rows must be
-- removed before re-running with corrected source.
--
-- Safety:
--   * DELETEs only rows where note = 'v1.4.1 phase 2 install_base_v2 backfill'.
--   * If any backfilled row was subsequently edited (the operator
--     changed the `note` field, added lifecycle records, etc.),
--     this rollback will NOT remove that row — by design. The
--     operator chose to keep it.
--   * If asset_lifecycle has rows referencing a backfilled
--     config_assets.code, the FK on delete restrict will block
--     this rollback for that code. In that case the backfill row
--     is operationally "in use" and must not be deleted.
-- ═════════════════════════════════════════════════════════════════════

-- ── §1. Delete only rows tagged by this backfill ────────────────────
delete from public.config_assets
 where note = 'v1.4.1 phase 2 install_base_v2 backfill';

-- ── §2. Verification ────────────────────────────────────────────────
-- Run after the delete:
--   select count(*) from public.config_assets;
-- Expected: count is back to the pre-backfill value (e.g. 24).

-- ── End of rollback ─────────────────────────────────────────────────
