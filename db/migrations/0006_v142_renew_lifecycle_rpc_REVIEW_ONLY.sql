-- ═════════════════════════════════════════════════════════════════════
-- 0006_v142_renew_lifecycle_rpc_REVIEW_ONLY.sql
--
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  REVIEW ONLY — DO NOT APPLY TO STAGING OR PRODUCTION WITHOUT   │
-- │  EXPLICIT OPERATOR APPROVAL.                                    │
-- │                                                                 │
-- │  Apply order: STAGING → verify queries → operator PASS →       │
-- │  PRODUCTION (separate approval phrase required).                │
-- ╰─────────────────────────────────────────────────────────────────╯
--
-- v1.4.2 Phase 1 — Part A: Add 'amc' contract type + Renew RPC.
--
-- ── Scope ────────────────────────────────────────────────────────────
--   A. Fix asset_lifecycle.contract_type CHECK: add 'amc'.
--   B. Fix asset_lifecycle_pm_required_consistency CHECK: add 'amc'
--      to the pm_required=true branch (AMC = labour + PM; parts extra).
--   C. Create renew_asset_lifecycle() RPC:
--      - Authorised via app_can_write() (Admin + Manager).
--      - Supersedes the current active row (status → 'superseded').
--      - Inserts a new active row.
--      - Writes two 'renewed' history events.
--      - SECURITY DEFINER + SET search_path = public.
--      - GRANT EXECUTE TO authenticated.
--
-- ── Idempotency ──────────────────────────────────────────────────────
--   All DDL uses DROP CONSTRAINT IF EXISTS + ADD CONSTRAINT and
--   CREATE OR REPLACE FUNCTION. Safe to re-run.
--
-- ── Pre-apply verification (run on staging FIRST) ───────────────────
--   1. Confirm current contract_type CHECK (should list 4 values):
--      SELECT conname, pg_get_constraintdef(oid)
--        FROM pg_constraint
--       WHERE conrelid = 'public.asset_lifecycle'::regclass
--         AND conname = 'asset_lifecycle_contract_type_check';
--
--   2. Confirm pm_required_consistency CHECK (should list 3 values):
--      SELECT conname, pg_get_constraintdef(oid)
--        FROM pg_constraint
--       WHERE conrelid = 'public.asset_lifecycle'::regclass
--         AND conname = 'asset_lifecycle_pm_required_consistency';
--
--   3. Confirm no live AMC rows (baseline = 0 since type was missing):
--      SELECT COUNT(*) FROM public.asset_lifecycle
--       WHERE contract_type = 'amc';
--
-- ── Post-apply verification (run on staging AFTER) ───────────────────
--   See §V below.
--
-- ── Rollback ─────────────────────────────────────────────────────────
--   Companion: 0006_v142_renew_lifecycle_rpc_ROLLBACK_REVIEW_ONLY.sql
-- ═════════════════════════════════════════════════════════════════════


-- ═════════════════════════════════════════════════════════════════════
-- §A. Fix asset_lifecycle.contract_type CHECK — add 'amc'
-- ═════════════════════════════════════════════════════════════════════
-- PostgreSQL cannot ALTER a CHECK expression in-place. Drop + recreate.
-- The DROP uses IF EXISTS so re-runs are harmless. The current 4-value
-- list ('warranty','extended_warranty','cmc','labour_contract') omits
-- 'amc' (Annual Maintenance Contract: labour + PM visits; parts extra).

ALTER TABLE public.asset_lifecycle
  DROP CONSTRAINT IF EXISTS asset_lifecycle_contract_type_check;

ALTER TABLE public.asset_lifecycle
  ADD CONSTRAINT asset_lifecycle_contract_type_check
  CHECK (contract_type IN (
    'warranty',
    'extended_warranty',
    'cmc',
    'amc',
    'labour_contract'
  ));

COMMENT ON CONSTRAINT asset_lifecycle_contract_type_check
  ON public.asset_lifecycle IS
  'Valid contract types: warranty (manufacturer warranty), '
  'extended_warranty (post-warranty special agreement), '
  'cmc (Comprehensive Maintenance Contract — parts + labour + PM), '
  'amc (Annual Maintenance Contract — labour + PM; parts charged separately), '
  'labour_contract (manpower only; no parts, no PM). '
  'Added amc in v1.4.2 migration 0006.';


-- ═════════════════════════════════════════════════════════════════════
-- §B. Fix asset_lifecycle_pm_required_consistency CHECK — add 'amc'
-- ═════════════════════════════════════════════════════════════════════
-- The original constraint (0003) only lists 3 types in the pm_required=true
-- branch. Without this fix, any INSERT with contract_type='amc' would fail
-- even after §A adds 'amc' to the type CHECK — both CHECK expressions must
-- agree for an INSERT to succeed. AMC includes PM visits → pm_required=true.

ALTER TABLE public.asset_lifecycle
  DROP CONSTRAINT IF EXISTS asset_lifecycle_pm_required_consistency;

ALTER TABLE public.asset_lifecycle
  ADD CONSTRAINT asset_lifecycle_pm_required_consistency
  CHECK (
    (contract_type = 'labour_contract' AND pm_required = false)
    OR
    (contract_type IN ('warranty','extended_warranty','cmc','amc') AND pm_required = true)
  );

COMMENT ON CONSTRAINT asset_lifecycle_pm_required_consistency
  ON public.asset_lifecycle IS
  'PM visits are required for warranty / extended_warranty / cmc / amc. '
  'Labour contracts (manpower only) must have pm_required=false. '
  'Updated in v1.4.2 migration 0006 to add amc to the pm_required=true branch.';


-- ═════════════════════════════════════════════════════════════════════
-- §C. renew_asset_lifecycle() RPC
-- ═════════════════════════════════════════════════════════════════════
-- Called from the app's Renew modal (Admin / Manager only).
-- Runs as a single atomic transaction:
--   1. Authorise: app_can_write() must return true.
--   2. Validate p_contract_type against all 5 allowed values.
--   3. Capture current active row (if any) as old_row.
--   4. Supersede old_row: status → 'superseded', updated_by + updated_at.
--   5. Insert history event 'renewed' for old_row (before→after snapshot).
--   6. Insert new active asset_lifecycle row.
--   7. Insert history event 'renewed' for new row (before=null, after=new).
--   8. Return JSON: {id: <new_uuid>, asset_code: p_asset_code}.
--
-- SECURITY DEFINER + locked search_path:
--   Function runs with owner privileges, bypassing RLS on the tables it
--   writes. This is intentional — the authorisation check (app_can_write)
--   is explicit inside the function body, mirroring the pattern used by
--   the existing helper functions from 0003.

CREATE OR REPLACE FUNCTION public.renew_asset_lifecycle(
  p_asset_code    text,
  p_contract_type text,
  p_pm_required   boolean,
  p_contract_start date    DEFAULT NULL,
  p_contract_end  date     DEFAULT NULL,
  p_note          text     DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor       uuid;
  v_actor_email text;
  v_old_row     public.asset_lifecycle%ROWTYPE;
  v_new_id      uuid;
  v_old_snap    jsonb;
BEGIN
  -- ── 1. Authorise ────────────────────────────────────────────────────
  IF NOT public.app_can_write() THEN
    RAISE EXCEPTION 'permission denied: admin or manager role required'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- ── 2. Validate contract_type ───────────────────────────────────────
  IF p_contract_type NOT IN (
    'warranty', 'extended_warranty', 'cmc', 'amc', 'labour_contract'
  ) THEN
    RAISE EXCEPTION 'invalid contract_type: %', p_contract_type
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  -- ── 3. Resolve actor ────────────────────────────────────────────────
  v_actor := auth.uid();
  SELECT email INTO v_actor_email
    FROM public.user_roles
   WHERE user_id = v_actor
   LIMIT 1;

  -- ── 4. Capture + supersede the current active row (if any) ─────────
  SELECT * INTO v_old_row
    FROM public.asset_lifecycle
   WHERE asset_code = p_asset_code
     AND status = 'active'
   LIMIT 1;

  IF FOUND THEN
    v_old_snap := to_jsonb(v_old_row);

    UPDATE public.asset_lifecycle
       SET status     = 'superseded',
           updated_at = NOW(),
           updated_by = v_actor
     WHERE id = v_old_row.id;

    -- History: superseded event
    INSERT INTO public.asset_lifecycle_history (
      asset_code, lifecycle_id, event,
      before_state, after_state,
      actor, actor_email, source, note
    ) VALUES (
      p_asset_code, v_old_row.id, 'renewed',
      v_old_snap,
      jsonb_build_object('status', 'superseded', 'superseded_at', NOW()),
      v_actor, v_actor_email,
      'app:renew_asset_lifecycle',
      p_note
    );
  END IF;

  -- ── 5. Insert new active row ────────────────────────────────────────
  INSERT INTO public.asset_lifecycle (
    asset_code, contract_type, pm_required,
    contract_start, contract_end,
    status, created_by, updated_by, note
  ) VALUES (
    p_asset_code, p_contract_type, p_pm_required,
    p_contract_start, p_contract_end,
    'active', v_actor, v_actor, p_note
  )
  RETURNING id INTO v_new_id;

  -- ── 6. History: new active row ──────────────────────────────────────
  INSERT INTO public.asset_lifecycle_history (
    asset_code, lifecycle_id, event,
    before_state, after_state,
    actor, actor_email, source, note
  ) VALUES (
    p_asset_code, v_new_id, 'renewed',
    NULL,
    jsonb_build_object(
      'id',             v_new_id,
      'asset_code',     p_asset_code,
      'contract_type',  p_contract_type,
      'pm_required',    p_pm_required,
      'contract_start', p_contract_start,
      'contract_end',   p_contract_end,
      'status',         'active'
    ),
    v_actor, v_actor_email,
    'app:renew_asset_lifecycle',
    p_note
  );

  RETURN json_build_object('id', v_new_id, 'asset_code', p_asset_code);
END;
$$;

COMMENT ON FUNCTION public.renew_asset_lifecycle(text, text, boolean, date, date, text) IS
  'Renew an asset contract. Supersedes the current active asset_lifecycle '
  'row (status → ''superseded''), inserts a new active row, and writes two '
  '''renewed'' history events. Requires app_can_write() (Admin or Manager). '
  'SECURITY DEFINER + locked search_path. Do not modify without security review. '
  'Added in v1.4.2 migration 0006.';

GRANT EXECUTE
  ON FUNCTION public.renew_asset_lifecycle(text, text, boolean, date, date, text)
  TO authenticated;


-- ═════════════════════════════════════════════════════════════════════
-- §V. Post-apply verification queries (run on staging after apply)
-- ═════════════════════════════════════════════════════════════════════

-- V1. Confirm 'amc' in contract_type CHECK (should list all 5 types):
-- SELECT conname, pg_get_constraintdef(oid)
--   FROM pg_constraint
--  WHERE conrelid = 'public.asset_lifecycle'::regclass
--    AND conname = 'asset_lifecycle_contract_type_check';
-- Expected output: CHECK (contract_type IN ('warranty','extended_warranty','cmc','amc','labour_contract'))

-- V2. Confirm pm_required_consistency includes 'amc' in pm_required=true branch:
-- SELECT conname, pg_get_constraintdef(oid)
--   FROM pg_constraint
--  WHERE conrelid = 'public.asset_lifecycle'::regclass
--    AND conname = 'asset_lifecycle_pm_required_consistency';
-- Expected output: includes 'amc' in the pm_required = true branch

-- V3. Confirm renew_asset_lifecycle exists + is SECURITY DEFINER:
-- SELECT proname, prosecdef, provolatile, pronargs
--   FROM pg_proc
--  WHERE proname = 'renew_asset_lifecycle';
-- Expected: prosecdef = true, pronargs = 6

-- V4. Confirm GRANT to authenticated:
-- SELECT grantee, privilege_type
--   FROM information_schema.role_routine_grants
--  WHERE routine_name = 'renew_asset_lifecycle';
-- Expected: grantee = 'authenticated', privilege_type = 'EXECUTE'

-- ── End of 0006 ──────────────────────────────────────────────────────
