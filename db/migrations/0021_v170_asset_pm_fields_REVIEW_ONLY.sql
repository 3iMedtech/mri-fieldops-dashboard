-- ═════════════════════════════════════════════════════════════════════
-- 0021_v170_asset_pm_fields_REVIEW_ONLY.sql
--
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  REVIEW ONLY — DO NOT APPLY WITHOUT EXPLICIT OPERATOR APPROVAL. │
-- │  Apply order: STAGING → verify → operator PASS → PRODUCTION.    │
-- ╰─────────────────────────────────────────────────────────────────╯
--
-- P2 of the PM-architecture rework (see docs/PM_ARCHITECTURE_DESIGN.md).
-- Additive, nullable columns on the install base so the asset becomes the
-- anchor of the Asset → Contract → PM chain (international-standard model).
--
-- ── Scope ────────────────────────────────────────────────────────────
--   config_assets gains three nullable columns:
--     • commission_date    date  — when the machine went live; the PM plan
--                                   anchor + the gate that flips a PM from
--                                   installation-pending to scheduled.
--     • territory          text  — canonical service territory for dispatch
--                                   (replaces region-string matching).
--     • primary_engineer_id text — owning engineer (FK → engineers.id);
--                                   resolution order: primary → territory.
--
-- ── Safety ───────────────────────────────────────────────────────────
--   • Purely additive + nullable: no existing row or query changes.
--   • Idempotent: ADD COLUMN IF NOT EXISTS.
--   • No RLS change — existing config_assets policies cover new columns.
--   • App code does not read these yet (wired in P3), so apply is a no-op
--     for current runtime behaviour.
--
-- ── Rollback ─────────────────────────────────────────────────────────
--   Companion: 0021_v170_asset_pm_fields_ROLLBACK_REVIEW_ONLY.sql
-- ═════════════════════════════════════════════════════════════════════

ALTER TABLE public.config_assets
  ADD COLUMN IF NOT EXISTS commission_date     date,
  ADD COLUMN IF NOT EXISTS territory           text,
  ADD COLUMN IF NOT EXISTS primary_engineer_id text;

-- FK to engineers(id). Added separately + guarded so re-runs don't error.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'config_assets_primary_engineer_id_fkey'
  ) THEN
    ALTER TABLE public.config_assets
      ADD CONSTRAINT config_assets_primary_engineer_id_fkey
      FOREIGN KEY (primary_engineer_id) REFERENCES public.engineers(id)
      ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS config_assets_territory_idx
  ON public.config_assets (territory);

COMMENT ON COLUMN public.config_assets.commission_date IS
  'Machine go-live date. PM-plan anchor; gates installation-pending → scheduled. v1.7.0 / 0021.';
COMMENT ON COLUMN public.config_assets.territory IS
  'Canonical service territory for dispatch (replaces region-string matching). v1.7.0 / 0021.';
COMMENT ON COLUMN public.config_assets.primary_engineer_id IS
  'Owning engineer (FK engineers.id). Resolution: primary → territory members. v1.7.0 / 0021.';

-- ── Post-apply verification (run on staging after) ───────────────────
-- SELECT column_name, data_type, is_nullable
--   FROM information_schema.columns
--  WHERE table_schema='public' AND table_name='config_assets'
--    AND column_name IN ('commission_date','territory','primary_engineer_id');
-- Expected: 3 rows, all is_nullable = YES.
--
-- SELECT conname FROM pg_constraint
--  WHERE conname = 'config_assets_primary_engineer_id_fkey';
-- Expected: 1 row.
-- ── End 0021 ─────────────────────────────────────────────────────────
