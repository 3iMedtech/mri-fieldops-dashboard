-- ═════════════════════════════════════════════════════════════════════
-- 0005_v141_phase2_install_base_master_backfill_REVIEW_ONLY.sql
--
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  REVIEW ONLY — DO NOT APPLY YET                                 │
-- │  Phase 2 — Install Base master-source backfill (one-time)       │
-- │  Apply order will be: STAGING → verify → PROD, with explicit    │
-- │  human approval at each gate.                                   │
-- ╰─────────────────────────────────────────────────────────────────╯
--
-- Phase 2 of v1.4.1 lifecycle work — operationalizes the DB-is-master
-- decision. Inserts any rows from the hardcoded `INSTALL_BASE_V2`
-- array (in index.html lines 1472-1498) that are MISSING from
-- public.config_assets. Codes already present are skipped silently.
--
-- Pre-this-migration baseline (2026-05-09 inspection):
--   * Production config_assets count: 24
--   * Staging config_assets count: 24
--   * INSTALL_BASE_V2 count in source: 25 (codes AN001..AN025)
--
-- Post-this-migration expected:
--   * config_assets count: 25 on both staging and production
--   * 1+ row(s) marked with note='v1.4.1 phase 2 install_base_v2 backfill'
--   * The rollback file deletes ONLY rows with that note marker
--
-- ── Idempotency ─────────────────────────────────────────────────────
-- The INSERT uses `where not exists` per code. Running this migration
-- a second time is a no-op for codes already present, regardless of
-- whether they originated from this backfill or pre-existed.
--
-- ── Pre-requisites ──────────────────────────────────────────────────
-- 1. 0003 migration applied (creates config_assets.status / created_at /
--    updated_at / created_by / updated_by / note / de_installed_at /
--    de_installed_by columns).
-- 2. Operator has run the §3.7 audit query in v1.4.1_phase2_review.md
--    to identify which V2 code(s) are missing from config_assets, and
--    has confirmed exactly 1 row is expected to be inserted (or has
--    investigated if the count differs).
--
-- ── Pre-flight diff query (run BEFORE this migration) ───────────────
-- Operator should run this and confirm the result before running
-- the INSERT block below:
--
--   with v2(code) as (values
--     ('AN001'),('AN002'),('AN003'),('AN004'),('AN005'),
--     ('AN006'),('AN007'),('AN008'),('AN009'),('AN010'),
--     ('AN011'),('AN012'),('AN013'),('AN014'),('AN015'),
--     ('AN016'),('AN017'),('AN018'),('AN019'),('AN020'),
--     ('AN021'),('AN022'),('AN023'),('AN024'),('AN025')
--   )
--   select v2.code as missing_v2_code
--     from v2
--    where not exists (select 1 from public.config_assets c where c.code = v2.code)
--    order by v2.code;
--
-- Expected: exactly 1 row (or whichever number matches your environment's
-- actual divergence). If 0 rows → migration is a no-op. If >1 rows →
-- investigate before proceeding.
-- ═════════════════════════════════════════════════════════════════════

-- ── §1. Backfill missing V2 rows ────────────────────────────────────
-- The CTE `v2` enumerates the canonical V2 row data. Each `where not
-- exists` clause skips codes already present in config_assets.
--
-- Field values mirror the INSTALL_BASE_V2 array in
-- index.html:1472-1498 EXACTLY. If V2 ever changes in source, this
-- block must be regenerated to match — do NOT edit row data here
-- without also editing index.html.

insert into public.config_assets
  (code, ast_id, name, tesla, model, town, state, channel, gradient,
   sw, compressor, coldhead, alias_of, status, created_by,
   created_at, updated_by, updated_at, note)
select v2.code, v2.ast_id, v2.name, v2.tesla, v2.model, v2.town, v2.state,
       v2.channel, v2.gradient, v2.sw, v2.compressor, v2.coldhead, null,
       'active', null,
       now(), null, now(), 'v1.4.1 phase 2 install_base_v2 backfill'
from (values
  ('AN001','AST001','BGTH','1.5T','Philips 1.5 T Achieva','Gulbargah','KA','CDAS 8 CH','781','R3.2.3','HC-8E','F2000'),
  ('AN002','AST002','NMR Medical institute','1.5T','Philips 1.5 T Achieva','Hubli','KA','CDAS 16CH','281 Single','R5.3.0','HC-8E','F2000'),
  ('AN003','AST003','Bhavani Diagnostic Centre','3.0T','Philips 3.0 T Achieva','Muzaffarpur','BH','CDAS 16CH','281 Single','R3.2.3','F-50',''),
  ('AN004','AST004','Tiruvarur Medical Centre','1.5T','Philips 1.5 T Achieva','Tiruvarur','TN','CDAS 8CH','271 Single','R.2.6.3.9','HC-8E','F2000/10k'),
  ('AN005','AST005','Anderson (Chennai)','PET CT','GE Discovery VCT64 PET CT','Chennai','TN','','','','',''),
  ('AN006','AST006','Kamakshi Memorial Hospital','DR','Retro Digital Radiography','Chennai','TN','','','','',''),
  ('AN007','AST007','Isha Diagnostics','1.5T','Philips 1.5 T Achieva','Bangalore','KA','CDAS 8CH','281 Single','R.3.2.3','HC-8E','F2000'),
  ('AN008','AST008','Chandru Diagnostics','1.5T','Philips 1.5 T Intera','Ramanagara','KA','BDAS 6CH','274 Single','R11.1.4','HC-8E','F2000'),
  ('AN009','AST009','Ruby Indapur','1.5T','Philips 1.5 T Intera','Indapur','MH','CDAS 8CH','271 Single','R3.2.3','HC-8E','F2000'),
  ('AN010','AST010','Ruby Chiplun','1.5T','Philips 1.5T Achieva','Chiplun','MH','CDAS 8CH','271 Single','R2.6.3','HC-8E','F2000'),
  ('AN011','AST011','OAKTree Diagnostic Centre','1.5T','Philips 1.5 T Achieva','Calicut','KL','CDAS 16CH','781','R3.2.4','HC-8E','F2000/10k'),
  ('AN012','AST012','Anderson diagnostic centre (Trichy)','1.5T','Philips 1.5 T Achieva','Trichy','TN','CDAS 16CH','781','R5.3.1','HC-8E','F2000/10k'),
  ('AN013','AST013','Lifeline Superspeciality','3.0T','Philips Achieva 3.0T REX Magnet','Pandharpur','MH','CDAS 16CH','281','R5.1.0','',''),
  ('AN014','AST014','Nucleus diagnostic','3.0T','Philips Achieva 3.0T REX Magnet','Pune','MH','CDAS 16CH','787','R5.3.1','',''),
  ('AN015','AST015','Dr Prakash Kennedy','3.0T','Philips 3T Achieva TX','Chennai','TN','CDAS 16CH','787 dual','R3.2.3','F50(WC)','4k'),
  ('AN016','AST016','Deepa Fortune','1.5T','1.5T Achieva','Mandya','KA','CDAS 8CH','274','R3.2.3','',''),
  ('AN017','AST017','Kennedy scans Nanganallur','1.5T','GE 1.5T Brivo 355','Chennai','TN','8CH','','23x','csa-71A(air)','4k'),
  ('AN018','AST018','Magnus Diagnostics','3.0T','Philips 3T Achieva','Bangalore','KA','CDAS 16CH','781','R5.7.1','F50(wc)','4k'),
  ('AN019','AST019','JCRL','3T','Philips 3T Achieva','Patna','BH','CDAS 16CH','281','R3.2.3','CSW-71D','4K'),
  ('AN020','AST020','TRR Medical','1.5T','Philips 1.5 T Achieva','Hyderabad','TS','CDAS 16CH','281','R2.6.3','',''),
  ('AN021','AST021','Nivi Scans','1.5T','GE 1.5T HDxT','Namakkal','TN','8CH','','16X','','RDK-408 A2'),
  ('AN022','AST022','Ruby Sangamner','1.5T','Anamaya 1.5T','Sangamner','MH','16CH','','4.2C','','RDK-412'),
  ('AN023','AST023','Ruby Phaltan','1.5T','Philips 1.5 T Intera','Phaltan','MH','CDAS 8CH','271 Single','R3.2.3','HC-8E','F2000'),
  ('AN024','AST024','District Hospital, Champawat','1.5T','Anamaya 1.5T','Champawat','UK','16CH','','4.2C','','RDK-412'),
  ('AN025','AST025','KVC Diagnostics','1.5T','Philips 1.5 T Achieva','Mysore','KA','CDAS 16CH','281','R5.7.1','HC-8E','F2000')
) as v2 (
  code, ast_id, name, tesla, model, town, state, channel, gradient,
  sw, compressor, coldhead
)
where not exists (
  select 1 from public.config_assets c where c.code = v2.code
);

-- ── §2. Post-backfill sanity check ──────────────────────────────────
-- Aborts the transaction if the resulting count is unexpectedly low.
do $$
declare ca_count int;
begin
  select count(*) into ca_count from public.config_assets;
  if ca_count < 25 then
    raise exception 'install_base_v2 backfill produced count=% (<25); aborting', ca_count;
  end if;
  raise notice 'install_base_v2 backfill ok: config_assets count=% (expected >=25)', ca_count;
end $$;

-- ── End of 0005 ─────────────────────────────────────────────────────
