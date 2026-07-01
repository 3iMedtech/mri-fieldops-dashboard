-- ═════════════════════════════════════════════════════════════════════
-- 0023_v172_consolidate_pm_contracts_REVIEW_ONLY.sql
--
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  REVIEW ONLY — operator-applied (staging → verify → prod).      │
-- ╰─────────────────────────────────────────────────────────────────╯
--
-- R2.2b: the BEFORE/AFTER diff for R2.3 revealed a THIRD contract source —
-- warranty (and some other) contracts live only on PM rows
-- (pm_schedule.contract/contract_start/contract_end), not in cmc_contracts.
-- This migrates them into asset_lifecycle so it becomes the true single source,
-- and re-derives status from the asset's status (fixes 0022's hard-coded
-- 'cancelled', which was wrong on envs where the asset is still active).
--
-- Idempotent: NOT EXISTS guard skips assets already carrying a lifecycle row.
-- Rollback: DELETE FROM asset_lifecycle WHERE source_ref LIKE 'pm:%';
--           (status re-derive is harmless to leave.)
-- ═════════════════════════════════════════════════════════════════════

-- 1. Re-derive status of the cmc-migrated rows (0022) from the asset's status.
--    de_installed asset → cancelled; otherwise active. No-op where already correct.
UPDATE public.asset_lifecycle al
   SET status = CASE WHEN coalesce(ca.status,'active') = 'de_installed' THEN 'cancelled' ELSE 'active' END,
       updated_at = now()
  FROM public.config_assets ca
 WHERE ca.code = al.asset_code
   AND al.source_ref LIKE 'cmc:%'
   AND al.status IN ('active','cancelled');

-- 2. Migrate contracts that live only on PM rows (warranty etc.) into
--    asset_lifecycle for assets that don't yet have an active/cancelled row.
INSERT INTO public.asset_lifecycle
  (asset_code, contract_type, pm_required, contract_start, contract_end, status, source_customer, source_ref)
SELECT
  pm.asset_code,
  CASE lower(coalesce(pm.contract,''))
    WHEN 'warranty' THEN 'warranty'
    WHEN 'extended warranty' THEN 'extended_warranty'
    WHEN 'amc' THEN 'amc'
    ELSE 'cmc'
  END,
  true,
  pm.contract_start,
  pm.contract_end,
  CASE WHEN coalesce(ca.status,'active') = 'de_installed' THEN 'cancelled' ELSE 'active' END,
  pm.customer,
  'pm:' || pm.id
FROM public.pm_schedule pm
JOIN public.config_assets ca ON ca.code = pm.asset_code
WHERE pm.asset_code IS NOT NULL
  AND coalesce(pm.contract,'') <> ''
  AND NOT EXISTS (
    SELECT 1 FROM public.asset_lifecycle al
     WHERE al.asset_code = pm.asset_code AND al.status IN ('active','cancelled')
  );

-- ── Verify (after) ───────────────────────────────────────────────────
-- SELECT asset_code, contract_type, status, contract_end, source_ref
--   FROM public.asset_lifecycle WHERE source_ref LIKE 'pm:%' ORDER BY asset_code;
-- Every active install-base asset with a contract should now have exactly one
-- active asset_lifecycle row.
-- ── End 0023 ─────────────────────────────────────────────────────────
