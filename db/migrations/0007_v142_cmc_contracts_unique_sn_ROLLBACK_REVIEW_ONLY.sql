-- ═════════════════════════════════════════════════════════════════════
-- 0007_v142_cmc_contracts_unique_sn_ROLLBACK_REVIEW_ONLY.sql
--
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  REVIEW ONLY — DO NOT APPLY YET                                 │
-- │  Mirror rollback for 0007 — drops UNIQUE(sn) on cmc_contracts.  │
-- ╰─────────────────────────────────────────────────────────────────╯
--
-- Use only if 0007 caused a regression.  Dropping the UNIQUE constraint
-- removes the safety net that the runtime safe-upsert depends on; the
-- runtime XLSX upload would silently revert to allowing duplicate sn
-- values (the legacy `delete + insert` pattern would still work, but
-- the new `upsert(..., { onConflict: 'sn' })` pattern would error
-- because the conflict target no longer exists).
--
-- After rollback, the runtime safe-upsert change must also be reverted
-- (separate `git revert` of the Track B+C runtime PR), and the Manager
-- XLSX gate must revert to admin-only until the constraint is restored.

begin;

alter table public.cmc_contracts
  drop constraint if exists cmc_contracts_sn_unique;

commit;

-- ── Post-rollback verification ──────────────────────────────────────
--
--   select count(*) as still_present
--     from pg_constraint
--    where conrelid = 'public.cmc_contracts'::regclass
--      and conname  = 'cmc_contracts_sn_unique';
--   -- expected: 0
--
--   -- row count unchanged
--   select count(*) as row_count from public.cmc_contracts;
--   -- expected: same as pre-rollback
--
-- ── End of 0007 rollback ────────────────────────────────────────────
