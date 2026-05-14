-- ═════════════════════════════════════════════════════════════════════
-- 0006_v142_renew_lifecycle_rpc_ROLLBACK_REVIEW_ONLY.sql
--
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  ROLLBACK — run ONLY if 0006 must be reverted.                  │
-- │  Requires explicit operator approval phrase before executing.   │
-- ╰─────────────────────────────────────────────────────────────────╯
--
-- Reverses 0006 changes:
--   A. Restore contract_type CHECK to 4 values (remove 'amc').
--   B. Restore pm_required_consistency to 3-value pm_required=true branch.
--   C. Drop renew_asset_lifecycle() RPC.
--
-- DANGER: If any asset_lifecycle rows have contract_type='amc', step A
-- will fail (CHECK constraint cannot be added while violating rows exist).
-- Run this pre-flight query first:
--   SELECT COUNT(*) FROM public.asset_lifecycle WHERE contract_type = 'amc';
-- If non-zero, those rows must be migrated to another type or deleted
-- (with operator approval) before this rollback can proceed.
-- ═════════════════════════════════════════════════════════════════════

-- §C rollback: drop RPC
DROP FUNCTION IF EXISTS public.renew_asset_lifecycle(text, text, boolean, date, date, text);

-- §B rollback: restore pm_required_consistency to 3-value branch
ALTER TABLE public.asset_lifecycle
  DROP CONSTRAINT IF EXISTS asset_lifecycle_pm_required_consistency;

ALTER TABLE public.asset_lifecycle
  ADD CONSTRAINT asset_lifecycle_pm_required_consistency
  CHECK (
    (contract_type = 'labour_contract' AND pm_required = false)
    OR
    (contract_type IN ('warranty','extended_warranty','cmc') AND pm_required = true)
  );

-- §A rollback: restore contract_type CHECK to 4 values
ALTER TABLE public.asset_lifecycle
  DROP CONSTRAINT IF EXISTS asset_lifecycle_contract_type_check;

ALTER TABLE public.asset_lifecycle
  ADD CONSTRAINT asset_lifecycle_contract_type_check
  CHECK (contract_type IN (
    'warranty',
    'extended_warranty',
    'cmc',
    'labour_contract'
  ));

-- ── End of 0006 rollback ─────────────────────────────────────────────
