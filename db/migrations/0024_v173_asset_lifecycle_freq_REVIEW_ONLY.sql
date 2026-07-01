-- ═════════════════════════════════════════════════════════════════════
-- 0024_v173_asset_lifecycle_freq_REVIEW_ONLY.sql
--
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  REVIEW ONLY — operator-applied (staging → verify → prod).      │
-- ╰─────────────────────────────────────────────────────────────────╯
--
-- R3 (PM auto-generation): the contract must carry the PM frequency so a PM
-- plan can be derived from it. Adds a nullable `freq` (PM visits per year) to
-- asset_lifecycle. Additive, nullable, idempotent → no runtime impact until R3
-- wires the modal + generation.
--
-- Backfill: seed freq from the asset's existing pm_schedule row where present,
-- so already-scheduled machines carry their frequency on the contract too.
--
-- Rollback: ALTER TABLE public.asset_lifecycle DROP COLUMN IF EXISTS freq;
-- ═════════════════════════════════════════════════════════════════════

ALTER TABLE public.asset_lifecycle
  ADD COLUMN IF NOT EXISTS freq integer;

COMMENT ON COLUMN public.asset_lifecycle.freq IS
  'PM visits per year (interval = 12/freq months). Drives PM-plan generation. v1.7.3 / 0024.';

-- Seed freq from the linked pm_schedule row (ID-linked since P1) where the
-- contract does not yet have one.
UPDATE public.asset_lifecycle al
   SET freq = pm.freq, updated_at = now()
  FROM public.pm_schedule pm
 WHERE pm.asset_code = al.asset_code
   AND pm.freq IS NOT NULL AND pm.freq > 0
   AND al.freq IS NULL
   AND al.status IN ('active','cancelled');

-- ── Verify (after) ───────────────────────────────────────────────────
-- SELECT asset_code, contract_type, freq, status FROM public.asset_lifecycle
--   WHERE status='active' ORDER BY asset_code;
-- ── End 0024 ─────────────────────────────────────────────────────────
