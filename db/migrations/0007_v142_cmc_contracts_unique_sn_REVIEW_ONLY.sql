-- ═════════════════════════════════════════════════════════════════════
-- 0007_v142_cmc_contracts_unique_sn_REVIEW_ONLY.sql
--
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  REVIEW ONLY — DO NOT APPLY YET                                 │
-- │  v1.4.2 Track B — UNIQUE(sn) on public.cmc_contracts            │
-- │                                                                 │
-- │  Status: drafted 2026-05-13. No apply approved yet. Pre-flight  │
-- │  duplicate-sn audit is MANDATORY before approval.               │
-- ╰─────────────────────────────────────────────────────────────────╯
--
-- Purpose
-- ───────
-- Adds a UNIQUE constraint on `public.cmc_contracts(sn)` so the runtime
-- XLSX upload path can use a safe `upsert(rows, { onConflict: 'sn' })`
-- pattern instead of the current `delete().neq('sn', -99999) + insert()`
-- pattern (see index.html `applyUploadedData` ~line 2910).  The safe-
-- upsert preserves any non-XLSX-controlled rows in `cmc_contracts` —
-- for example, rows inserted by the v1.4.2 Track A Renew RPC's optional
-- cross-reference write, or rows manually inserted by Admin via SQL
-- Editor for one-off fixes.
--
-- Tracks the recommendation from `L-RTI-008` / `L-DBPM-005` (Manager
-- XLSX gate stays admin-only until this UNIQUE constraint + a safe-
-- upsert runtime change ship together in v1.4.2).
--
-- Pre-flight (MANDATORY before apply; STOP if non-zero rows)
-- ──────────────────────────────────────────────────────────
-- The UNIQUE constraint cannot be added to a table that already
-- contains duplicate values in the keyed column.  Operator must run
-- the following audit on the target environment's SQL Editor and
-- paste back the full result.  Apply only proceeds if the audit
-- returns 0 rows.
--
--   select sn, count(*) as cnt
--     from public.cmc_contracts
--    group by sn
--   having count(*) > 1
--    order by sn;
--   -- expected: 0 rows
--
-- If any rows appear:
--   1. STOP.  Do NOT proceed with this migration.
--   2. Capture the duplicate sn values.
--   3. Manually reconcile.  Possible reasons for duplicates:
--      - Legacy data drift (operator merged two CMC sources before
--        v1.4.0 IB-anchoring shipped).
--      - XLSX re-uploads creating duplicate inserts.
--      - Test fixtures or one-off SQL inserts.
--   4. Decide per row whether to delete (lose history) or rename
--      (assign a synthetic sn-suffix).  Both options are operator-
--      driven; this runbook does not auto-resolve (per `L-REC-002`,
--      ambiguous matches ESCALATE; never auto-resolve).
--   5. Re-run the audit; only proceed when it returns 0 rows.
--
-- Idempotency
-- ───────────
-- The `do $$ … end $$` block checks for the constraint before adding
-- it.  Running this migration twice is a no-op on the second run.
--
-- Pre-requisites
-- ──────────────
-- 1. Migration 0003 + 0004 + 0005 applied (Phase 1 + Phase 2 baseline).
-- 2. Pre-flight duplicate-sn audit returns 0 rows (mandatory).
-- ═════════════════════════════════════════════════════════════════════

begin;

-- ── Add UNIQUE constraint on sn ─────────────────────────────────────
-- Idempotent: checks pg_constraint first.  If the constraint already
-- exists with the canonical name, this is a no-op.
do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conrelid = 'public.cmc_contracts'::regclass
       and conname  = 'cmc_contracts_sn_unique'
  ) then
    alter table public.cmc_contracts
      add constraint cmc_contracts_sn_unique unique (sn);
    raise notice 'cmc_contracts_sn_unique constraint added';
  else
    raise notice 'cmc_contracts_sn_unique already present; no-op';
  end if;
end $$;

-- ── Verify the constraint is in place (raises exception on failure) ─
do $$
declare v_count int;
begin
  select count(*) into v_count
    from pg_constraint
   where conrelid = 'public.cmc_contracts'::regclass
     and conname  = 'cmc_contracts_sn_unique';
  if v_count != 1 then
    raise exception 'cmc_contracts_sn_unique constraint missing after apply (count=%)', v_count;
  end if;
  raise notice 'cmc_contracts_sn_unique constraint present (pg_constraint count=%)', v_count;
end $$;

commit;

-- ── Post-apply verification (read-only; operator pastes back) ───────
-- Run on the same session as the apply (or a fresh service-role session):
--
--   -- constraint exists
--   select c.conname, c.contype, pg_get_constraintdef(c.oid) as def
--     from pg_constraint c
--    where c.conrelid = 'public.cmc_contracts'::regclass
--      and c.conname  = 'cmc_contracts_sn_unique';
--   -- expected: 1 row; contype='u'; def='UNIQUE (sn)'
--
--   -- supporting unique index exists (Postgres auto-creates one)
--   select indexname, indexdef
--     from pg_indexes
--    where schemaname='public'
--      and tablename='cmc_contracts'
--      and indexname like 'cmc_contracts_sn%';
--   -- expected: at least 1 row
--
--   -- row count unchanged (constraint addition does not affect data)
--   select count(*) as row_count from public.cmc_contracts;
--   -- expected: same as pre-apply (13 on production at v1.4.1 baseline)
--
--   -- attempt a duplicate insert (should fail with 23505)
--   --   begin;
--   --     insert into public.cmc_contracts (sn, ...) values ('99999', ...);
--   --     insert into public.cmc_contracts (sn, ...) values ('99999', ...);
--   --     -- second insert errors: duplicate key value violates unique
--   --     -- constraint "cmc_contracts_sn_unique"
--   --   rollback;
--
-- See docs/v1.4.2_staging_apply_runbook.md §10 for the runtime safe-
-- upsert smoke test (TEST-CMC-AAA preservation regression).

-- ── End of 0007 ─────────────────────────────────────────────────────
