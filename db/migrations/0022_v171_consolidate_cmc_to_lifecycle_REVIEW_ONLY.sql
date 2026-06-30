-- ═════════════════════════════════════════════════════════════════════
-- 0022_v171_consolidate_cmc_to_lifecycle_REVIEW_ONLY.sql
--
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  REVIEW ONLY — operator-applied (staging → verify → prod).      │
-- ╰─────────────────────────────────────────────────────────────────╯
--
-- R2 of the enterprise rebuild (docs/ENTERPRISE_ARCHITECTURE_AND_ROADMAP.md):
-- make asset_lifecycle the single contract source of truth by migrating the
-- legacy cmc_contracts rows into it, ID-linked by asset_code.
--
-- Mapping is by normalized town (the 13 cmc rows have unique towns, so this is
-- portable across environments and stable regardless of `sn`). De-installed
-- machines' contracts are recorded as status='cancelled'. Rows whose asset
-- already has an active/cancelled lifecycle row (AN001 BGTH, AN007 Isha) are
-- skipped by the NOT EXISTS guard → safe + idempotent (re-runnable).
--
-- Display-neutral: dates/type carried verbatim from cmc_contracts, so the
-- Contracts page shows the same values via the existing asset_lifecycle
-- override. The page is switched to read asset_lifecycle as PRIMARY in R2.3
-- (separate code change).
--
-- ── Rollback ─────────────────────────────────────────────────────────
--   DELETE FROM public.asset_lifecycle WHERE source_ref LIKE 'cmc:%';
-- ═════════════════════════════════════════════════════════════════════

WITH tmap(town_norm, asset_code, status) AS (VALUES
  ('hubli','AN002','active'), ('muzaffarpur','AN003','active'),
  ('tiruvarur','AN004','active'), ('calicut','AN011','active'),
  ('trichy','AN012','active'), ('pune','AN014','active'),
  ('chiplun','AN010','active'), ('mysore','AN025','active'),
  ('phalton','AN023','active'),
  ('ramanagara','AN008','cancelled'), ('pandharpur','AN013','cancelled')
)
INSERT INTO public.asset_lifecycle
  (asset_code, contract_type, pm_required, contract_start, contract_end, status, source_customer, source_ref)
SELECT
  t.asset_code,
  CASE
    WHEN lower(coalesce(c.contract,'')) = 'amc' THEN 'amc'
    WHEN lower(coalesce(c.contract,'')) = 'warranty' THEN 'warranty'
    WHEN lower(coalesce(c.contract,'')) = 'extended warranty' THEN 'extended_warranty'
    ELSE 'cmc'
  END,
  true,
  c.start_date,
  c.end_date,
  t.status,
  c.customer,
  'cmc:' || coalesce(c.sn::text, c.customer)
FROM public.cmc_contracts c
JOIN tmap t ON t.town_norm = regexp_replace(lower(coalesce(c.town,'')), '[^a-z0-9]', '', 'g')
WHERE NOT EXISTS (
  SELECT 1 FROM public.asset_lifecycle al
   WHERE al.asset_code = t.asset_code AND al.status IN ('active','cancelled')
);

-- ── Verify (after) ───────────────────────────────────────────────────
-- SELECT asset_code, contract_type, status, contract_end, source_ref
--   FROM public.asset_lifecycle WHERE source_ref LIKE 'cmc:%' ORDER BY asset_code;
-- Expected: 11 rows (9 active + 2 cancelled: AN008, AN013).
-- ── End 0022 ─────────────────────────────────────────────────────────
