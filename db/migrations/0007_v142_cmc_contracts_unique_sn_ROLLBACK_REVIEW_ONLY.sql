-- ═════════════════════════════════════════════════════════════════════
-- 0007_v142_cmc_contracts_unique_sn_ROLLBACK_REVIEW_ONLY.sql
--
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  ROLLBACK — run ONLY if 0007 must be reverted.                  │
-- │  Requires explicit operator approval before executing.          │
-- ╰─────────────────────────────────────────────────────────────────╯
--
-- NOTE: After dropping this constraint, the Manager XLSX upload will
-- revert to unsafe behaviour (duplicate rows accumulate on re-upload).
-- The app-side XLSX gate should also be re-locked to admin-only
-- (revert index.html changes from 2c) if this rollback is applied.
-- ═════════════════════════════════════════════════════════════════════

ALTER TABLE public.cmc_contracts
  DROP CONSTRAINT IF EXISTS cmc_contracts_sn_key;

-- ── End of 0007 rollback ─────────────────────────────────────────────
