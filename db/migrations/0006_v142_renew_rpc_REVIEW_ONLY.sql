-- ═════════════════════════════════════════════════════════════════════
-- 0006_v142_renew_rpc_REVIEW_ONLY.sql
--
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  REVIEW ONLY — DO NOT APPLY YET                                 │
-- │  v1.4.2 Track A — Renew Asset RPC                               │
-- │                                                                 │
-- │  Status: drafted 2026-05-13 alongside docs/v1.4.2_technical_    │
-- │  design.md. No staging or production apply is approved yet.     │
-- │  Apply order will be: STAGING → verify → PROD with explicit     │
-- │  human approval at each gate.                                   │
-- ╰─────────────────────────────────────────────────────────────────╯
--
-- Purpose
-- ───────
-- Adds a SECURITY DEFINER RPC `public.app_renew_asset(...)` that lets
-- Admin and Manager renew an asset's contract atomically. The RPC:
--   - Authorizes via `public.app_can_write()` (admin OR manager).
--   - Validates inputs (asset code, contract type, dates).
--   - Locks the target asset row and rejects de_installed assets.
--   - Supersedes the prior `asset_lifecycle` row whose `status='active'`
--     (the 0003 partial unique index `asset_lifecycle_one_active_per_asset`
--     allows at most one active row per asset_code).
--   - Inserts a new `asset_lifecycle` row with `status='active'`.
--   - Inserts an `asset_lifecycle_history` row with `event='renewed'`,
--     full `before_state`/`after_state` JSON snapshots, and actor info.
--   - Returns a JSON success payload.
--
-- Scope of this RPC
-- ─────────────────
-- This RPC writes ONLY to `asset_lifecycle` + `asset_lifecycle_history`.
-- It does NOT write to `cmc_contracts` — that table is being migrated
-- toward read-mostly status, with the XLSX upload path (covered by
-- Track B+C / migration 0007) remaining the canonical write path for
-- legacy contract rows.  The asset_lifecycle table is the canonical
-- forward-looking contract registry; the `source_ref` column may store
-- the corresponding `cmc_contracts.sn` for cross-reference / trace.
--
-- Pre-requisites
-- ──────────────
-- 1. Migration 0003 applied (asset_lifecycle + asset_lifecycle_history
--    tables + helpers + recursion guard).
-- 2. Migration 0004 applied (`v141_*_app_can_write` policies + the
--    `app_can_write()` helper invoked here).
-- 3. Migration 0005 applied (Install Base master backfill — not strictly
--    required by this RPC but recommended for a consistent baseline).
--
-- Idempotency
-- ───────────
-- `create or replace function` makes this migration idempotent.  Re-apply
-- replaces the function body but does not change schema.  Grant statements
-- at the bottom are also idempotent (`grant execute` is a no-op if the
-- role already has execute).
--
-- Pre-flight (read-only)
-- ──────────────────────
-- Operator runs BEFORE apply, on the target environment's SQL Editor:
--
--   -- helpers must exist
--   select p.proname, p.prosecdef, p.proconfig
--     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public'
--      and p.proname in ('app_can_write','app_user_role','app_is_admin')
--    order by p.proname;
--   -- expected: 3 rows; prosecdef=true; proconfig contains search_path=public
--
--   -- lifecycle tables must exist
--   select c.relname
--     from pg_class c join pg_namespace n on n.oid = c.relnamespace
--    where n.nspname = 'public'
--      and c.relname in ('asset_lifecycle','asset_lifecycle_history','config_assets');
--   -- expected: 3 rows
--
--   -- partial unique index must be in place (one active lifecycle per asset)
--   select indexname from pg_indexes
--    where schemaname='public'
--      and tablename='asset_lifecycle'
--      and indexname='asset_lifecycle_one_active_per_asset';
--   -- expected: 1 row
--
--   -- function must NOT yet exist (avoids replace-during-active-use surprise)
--   select count(*) as existing
--     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public' and p.proname = 'app_renew_asset';
--   -- expected: 0
-- ═════════════════════════════════════════════════════════════════════

begin;

-- ── Function definition ─────────────────────────────────────────────
create or replace function public.app_renew_asset(
  p_asset_code      text,
  p_contract_type   text,
  p_contract_start  date,
  p_contract_end    date,
  p_source_ref      text default null,
  p_source_customer text default null,
  p_note            text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_asset            public.config_assets%rowtype;
  v_existing_life    public.asset_lifecycle%rowtype;
  v_new_lifecycle_id uuid;
  v_actor_id         uuid;
  v_actor_email      text;
  v_pm_required      boolean;
  v_before_state     jsonb;
  v_after_state      jsonb;
begin
  -- ── 1. Capture actor identity from JWT ────────────────────────────
  v_actor_id := auth.uid();
  begin
    v_actor_email := (auth.jwt() ->> 'email')::text;
  exception when others then
    v_actor_email := null;
  end;

  -- ── 2. Authorization: admin OR manager only ───────────────────────
  -- `app_can_write()` is the canonical writer-role helper; viewers fall
  -- through to the false branch and the RPC rejects them.  This matches
  -- the same gate enforced by the 0004 RLS policies on config_assets /
  -- pm_schedule / cmc_contracts.  Per L-RTI-002 / L-RTI-007 / L-RTI-010,
  -- there is no path that elevates a viewer to writer.
  if not public.app_can_write() then
    raise exception 'app_renew_asset: forbidden (requires admin or manager role)'
      using errcode = '42501';
  end if;

  -- ── 3. Input validation ───────────────────────────────────────────
  if p_asset_code is null or trim(p_asset_code) = '' then
    raise exception 'app_renew_asset: p_asset_code is required'
      using errcode = '22023';
  end if;
  if p_contract_type is null or p_contract_type not in (
       'warranty','extended_warranty','cmc','labour_contract'
     ) then
    raise exception 'app_renew_asset: p_contract_type must be one of warranty / extended_warranty / cmc / labour_contract; got %', p_contract_type
      using errcode = '22023';
  end if;
  if p_contract_start is null then
    raise exception 'app_renew_asset: p_contract_start is required'
      using errcode = '22023';
  end if;
  if p_contract_end is null then
    raise exception 'app_renew_asset: p_contract_end is required'
      using errcode = '22023';
  end if;
  if p_contract_end < p_contract_start then
    raise exception 'app_renew_asset: p_contract_end (%) must be on or after p_contract_start (%)', p_contract_end, p_contract_start
      using errcode = '22023';
  end if;

  -- pm_required follows contract_type per 0003's
  -- `asset_lifecycle_pm_required_consistency` CHECK constraint:
  -- labour_contract → false; everything else → true.
  v_pm_required := (p_contract_type != 'labour_contract');

  -- ── 4. Asset existence + row-lock + de_installed guard ────────────
  -- Lock the asset row to serialize concurrent Renew attempts on the
  -- same asset.  Without this, two simultaneous Renews could both
  -- attempt to insert an active lifecycle row, and the second one
  -- would fail at the partial unique index instead of presenting a
  -- clean error to the second caller.
  select * into v_asset
    from public.config_assets
   where code = upper(trim(p_asset_code))
   for update;
  if not found then
    raise exception 'app_renew_asset: asset code % not found in config_assets', upper(trim(p_asset_code))
      using errcode = 'P0002';
  end if;
  if v_asset.status = 'de_installed' then
    raise exception 'app_renew_asset: asset % is de_installed; cannot renew. Reactivate the asset before renewing.', v_asset.code
      using errcode = '22023';
  end if;

  -- ── 5. Snapshot prior active lifecycle row (if any) ───────────────
  -- Also lock it so the supersede + new-insert window is serialized.
  select * into v_existing_life
    from public.asset_lifecycle
   where asset_code = v_asset.code and status = 'active'
   for update;

  v_before_state := jsonb_build_object(
    'asset',           to_jsonb(v_asset),
    'prior_lifecycle', case when v_existing_life.id is not null
                          then to_jsonb(v_existing_life)
                          else null end
  );

  -- ── 6. Supersede prior active row ─────────────────────────────────
  -- Must happen BEFORE inserting the new active row to satisfy the
  -- partial unique index `asset_lifecycle_one_active_per_asset`.
  if v_existing_life.id is not null then
    update public.asset_lifecycle
       set status     = 'superseded',
           updated_by = v_actor_id,
           updated_at = now()
     where id = v_existing_life.id;
  end if;

  -- ── 7. Insert new active lifecycle row ────────────────────────────
  insert into public.asset_lifecycle (
    asset_code, contract_type, pm_required,
    contract_start, contract_end, status,
    source_customer, source_ref, note,
    created_by, created_at, updated_by, updated_at
  ) values (
    v_asset.code, p_contract_type, v_pm_required,
    p_contract_start, p_contract_end, 'active',
    p_source_customer, p_source_ref, p_note,
    v_actor_id, now(), v_actor_id, now()
  )
  returning id into v_new_lifecycle_id;

  -- ── 8. Build after-state snapshot for the history row ─────────────
  v_after_state := jsonb_build_object(
    'asset', to_jsonb(v_asset),
    'new_lifecycle', jsonb_build_object(
      'id',              v_new_lifecycle_id,
      'asset_code',      v_asset.code,
      'contract_type',   p_contract_type,
      'pm_required',     v_pm_required,
      'contract_start',  p_contract_start,
      'contract_end',    p_contract_end,
      'status',          'active',
      'source_customer', p_source_customer,
      'source_ref',      p_source_ref,
      'note',            p_note
    )
  );

  -- ── 9. Append asset_lifecycle_history event='renewed' ─────────────
  -- The 0003 INSERT policy `v141_history_insert_app_can_write` permits
  -- this from any authenticated session whose JWT satisfies
  -- app_can_write().  Inside SECURITY DEFINER the inserter is the
  -- function owner, which has direct INSERT privilege; the RLS policy
  -- is bypassed for the function owner.  The user-facing audit trail
  -- preserves the operator identity via actor + actor_email columns.
  insert into public.asset_lifecycle_history (
    asset_code, lifecycle_id, event,
    before_state, after_state,
    actor, actor_email, source, note
  ) values (
    v_asset.code, v_new_lifecycle_id, 'renewed',
    v_before_state, v_after_state,
    v_actor_id, v_actor_email, 'app:renew_asset_rpc', p_note
  );

  -- ── 10. Return success payload ────────────────────────────────────
  return json_build_object(
    'success',                 true,
    'asset_code',              v_asset.code,
    'new_lifecycle_id',        v_new_lifecycle_id,
    'superseded_lifecycle_id', v_existing_life.id,
    'contract_type',           p_contract_type,
    'pm_required',             v_pm_required,
    'contract_start',          p_contract_start,
    'contract_end',            p_contract_end,
    'renewed_at',              now(),
    'actor',                   v_actor_id,
    'actor_email',             v_actor_email
  );
end;
$$;

-- ── Privileges ──────────────────────────────────────────────────────
-- SECURITY DEFINER means the function runs with the OWNER's privileges
-- (typically `postgres` or the migration-runner role on Supabase).  The
-- owner must have INSERT/UPDATE rights on `asset_lifecycle` and INSERT
-- on `asset_lifecycle_history`, plus SELECT on `config_assets` and
-- EXECUTE on `app_can_write()`.  These are all in place from 0003+0004.
--
-- We revoke EXECUTE from PUBLIC and grant only to `authenticated`, so
-- the RPC is reachable by signed-in app users via PostgREST.  The
-- internal `app_can_write()` check rejects viewers; admin and manager
-- pass.  This is the same pattern used by Phase 1 helpers.
revoke all on function public.app_renew_asset(text,text,date,date,text,text,text) from public;
grant execute on function public.app_renew_asset(text,text,date,date,text,text,text) to authenticated;

-- ── Documentation comment ───────────────────────────────────────────
comment on function public.app_renew_asset(text,text,date,date,text,text,text) is
  'v1.4.2 Track A — atomic asset Renew RPC. Supersedes the prior active '
  'asset_lifecycle row and inserts a new active row + asset_lifecycle_history '
  'event=''renewed''. Guarded by app_can_write() (admin or manager). '
  'De_installed assets are rejected. See docs/v1.4.2_technical_design.md.';

commit;

-- ── Post-apply verification (read-only; operator pastes back) ───────
-- Run on the same session as the apply (or a fresh service-role session):
--
--   -- function exists with the right signature + SECURITY DEFINER + locked search_path
--   select p.proname, p.prosecdef, p.proconfig, pg_get_function_arguments(p.oid) as args
--     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public'
--      and p.proname  = 'app_renew_asset';
--   -- expected: 1 row; prosecdef=true; proconfig has search_path=public;
--   --           args = "p_asset_code text, p_contract_type text, p_contract_start date,
--   --                   p_contract_end date, p_source_ref text DEFAULT NULL::text,
--   --                   p_source_customer text DEFAULT NULL::text,
--   --                   p_note text DEFAULT NULL::text"
--
--   -- EXECUTE privilege granted to authenticated
--   select pg_has_role('authenticated', 'public.app_renew_asset(text,text,date,date,text,text,text)'::regprocedure, 'EXECUTE') as can_exec;
--   -- expected: true
--
--   -- function comment present
--   select obj_description('public.app_renew_asset(text,text,date,date,text,text,text)'::regprocedure, 'pg_proc') as fn_comment;
--   -- expected: starts with 'v1.4.2 Track A —'
--
-- See docs/v1.4.2_staging_apply_runbook.md §6 for the live-call smoke tests
-- (admin happy path, manager happy path, viewer rejection, de_installed
-- rejection, invalid date rejection).

-- ── End of 0006 ─────────────────────────────────────────────────────
