-- ═════════════════════════════════════════════════════════════════════
-- 0021_v170_asset_pm_fields_ROLLBACK_REVIEW_ONLY.sql
-- Reverts 0021. Safe to run; drops only the additive columns + FK + index.
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  REVIEW ONLY — operator-applied. Data in these columns is lost.  │
-- ╰─────────────────────────────────────────────────────────────────╯
-- ═════════════════════════════════════════════════════════════════════

ALTER TABLE public.config_assets
  DROP CONSTRAINT IF EXISTS config_assets_primary_engineer_id_fkey;

DROP INDEX IF EXISTS public.config_assets_territory_idx;

ALTER TABLE public.config_assets
  DROP COLUMN IF EXISTS primary_engineer_id,
  DROP COLUMN IF EXISTS territory,
  DROP COLUMN IF EXISTS commission_date;

-- ── End rollback 0021 ────────────────────────────────────────────────
