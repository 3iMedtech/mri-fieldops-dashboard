-- ═════════════════════════════════════════════════════════════════════
-- 0007_v142_cmc_contracts_unique_sn_REVIEW_ONLY.sql
--
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  REVIEW ONLY — DO NOT APPLY TO STAGING OR PRODUCTION WITHOUT   │
-- │  EXPLICIT OPERATOR APPROVAL.                                    │
-- │                                                                 │
-- │  REQUIRED PRE-FLIGHT: Run the two queries in §P below in the   │
-- │  Supabase SQL editor BEFORE applying this migration. If either  │
-- │  returns rows, do NOT apply — a cleanup step is required first. │
-- │                                                                 │
-- │  Apply order: STAGING → verify queries → operator PASS →       │
-- │  PRODUCTION (separate approval phrase required for production). │
-- ╰─────────────────────────────────────────────────────────────────╯
--
-- v1.4.2 Phase 1 — Part B: UNIQUE constraint on cmc_contracts.sn.
--
-- ── Rationale ────────────────────────────────────────────────────────
--   The Manager XLSX upload (cmc_contracts safe-upsert) requires a
--   UNIQUE constraint on cmc_contracts.sn so that ON CONFLICT(sn) DO
--   UPDATE semantics are available. Without this constraint, duplicate
--   sn values accumulate on re-upload, producing ghost rows.
--
-- ── Idempotency ──────────────────────────────────────────────────────
--   Wrapped in DO $$ ... IF NOT EXISTS ... $$. Safe to re-apply.
-- ═════════════════════════════════════════════════════════════════════


-- ═════════════════════════════════════════════════════════════════════
-- §P. Pre-flight queries (run BEFORE applying this migration)
-- ═════════════════════════════════════════════════════════════════════

-- P1. Duplicate sn check (must return zero rows to proceed):
-- SELECT sn, COUNT(*)
--   FROM public.cmc_contracts
--  GROUP BY sn
-- HAVING COUNT(*) > 1;

-- P2. NULL sn check (must return 0 to proceed):
-- SELECT COUNT(*) FROM public.cmc_contracts WHERE sn IS NULL;

-- If P1 or P2 returns rows, STOP. Do not apply this migration until a
-- cleanup step is authored and approved. Cleanup options:
--   a. Deduplicate rows by deleting the older duplicate (keep latest).
--   b. Confirm with operator which row is authoritative.
-- This migration does NOT include a cleanup step because the live data
-- state must be verified before any rows are removed.


-- ═════════════════════════════════════════════════════════════════════
-- §A. Add UNIQUE constraint on cmc_contracts.sn
-- ═════════════════════════════════════════════════════════════════════
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_constraint
     WHERE conrelid = 'public.cmc_contracts'::regclass
       AND conname  = 'cmc_contracts_sn_key'
  ) THEN
    ALTER TABLE public.cmc_contracts
      ADD CONSTRAINT cmc_contracts_sn_key UNIQUE (sn);
  END IF;
END $$;

COMMENT ON CONSTRAINT cmc_contracts_sn_key
  ON public.cmc_contracts IS
  'Unique serial number per CMC contract row. Required for XLSX safe-upsert '
  '(ON CONFLICT(sn) DO UPDATE) from Manager XLSX upload. Added in v1.4.2 migration 0007.';


-- ═════════════════════════════════════════════════════════════════════
-- §V. Post-apply verification queries (run on staging after apply)
-- ═════════════════════════════════════════════════════════════════════

-- V1. Confirm constraint exists:
-- SELECT conname, contype, pg_get_constraintdef(oid)
--   FROM pg_constraint
--  WHERE conrelid = 'public.cmc_contracts'::regclass
--    AND conname = 'cmc_contracts_sn_key';
-- Expected: contype = 'u', constraint definition UNIQUE (sn)

-- V2. Confirm row count unchanged after constraint add:
-- SELECT COUNT(*) FROM public.cmc_contracts;
-- Expected: same as pre-flight count (13 on staging as of 2026-05-11)

-- ── End of 0007 ──────────────────────────────────────────────────────
