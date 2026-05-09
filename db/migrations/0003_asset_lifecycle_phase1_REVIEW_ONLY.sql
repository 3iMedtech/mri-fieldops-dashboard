-- ═════════════════════════════════════════════════════════════════════
-- 0003_asset_lifecycle_phase1_REVIEW_ONLY.sql
--
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  REVIEW ONLY — DO NOT APPLY TO STAGING OR PRODUCTION YET        │
-- │  No implementation has been approved.                           │
-- │                                                                 │
-- │  ROLE MAPPING DESIGN: Option B chosen (DB user_roles table).    │
-- │  See §1a / §1b / §1c below for the table, helpers, and seed.   │
-- │                                                                 │
-- │  Pre-SQL §A0 verification step still required before execution │
-- │  to capture: actual JWT structure (diagnostic), pre-existing   │
-- │  config_assets policies, and config_assets.code constraint.   │
-- │                                                                 │
-- │  Apply order will be: STAGING → verify → PROD, with explicit   │
-- │  human approval at each gate.                                  │
-- ╰─────────────────────────────────────────────────────────────────╯
--
-- Phase 1 of v1.4.1 lifecycle work.
-- Adds the schema foundation needed for Install Base CRUD + contract
-- lifecycle workflows. This migration is data-only safe: it adds new
-- columns and new tables; it does not drop, rename, or rewrite any
-- existing data.
--
-- ── Scope ────────────────────────────────────────────────────────────
--   1. Extend public.config_assets with lifecycle/audit fields.
--   2. Create public.asset_lifecycle    — one active contract row per asset.
--   3. Create public.asset_lifecycle_history — append-only event log.
--   4. Indexes for common access patterns.
--   5. Constraint: at most one active lifecycle per asset_code.
--   6. RLS draft (see ASSUMPTIONS — read carefully before applying).
--
-- ── Out of scope (Phase 2+) ──────────────────────────────────────────
--   - Backfill of existing PM_SCHEDULE / CMC_DATA into asset_lifecycle.
--     A separate review document covers the SQL/Node backfill plan.
--   - UI: Add Asset / Edit / De-install / Renew buttons.
--   - applyInstallBaseOverlay() merge fix (separate review document).
--   - PM scheduling rule changes derived from contract type.
--   - XLSX bulk upload behavior change (separate must-resolve item;
--     see docs/v1.4.1_phase1_review.md §11 — Add Asset UI cannot ship
--     until this is resolved).
--
-- ── Idempotency ──────────────────────────────────────────────────────
--   All DDL uses `if not exists` / guarded `do $$ ... $$` blocks. Safe
--   to re-apply. Re-running will not duplicate columns, indexes, tables,
--   or constraints.
--
-- ── §A0. Required Pre-SQL Verification Step ─────────────────────────
-- Before this migration is approved for staging execution, run the
-- following on the staging Supabase SQL editor while signed in as
-- each role and capture the output (redact secrets):
--
--   -- 1. Inspect the JWT structure for each role.
--   --    Sign in as Admin in the app, then in SQL editor:
--   select auth.jwt();
--   --    Capture: where does the role live? user_metadata.role?
--   --    app_metadata.role? a custom top-level claim?
--   --
--   --    Repeat signed in as Manager, then as Engineer/Viewer.
--   --    Compare the three captures.
--
--   -- 2. List existing policies on config_assets:
--   select policyname, cmd, roles, qual, with_check
--     from pg_policies
--    where schemaname = 'public' and tablename = 'config_assets';
--
--   -- 3. Confirm the unique/PK constraint on config_assets.code:
--   select conname, contype, pg_get_constraintdef(oid)
--     from pg_constraint
--    where conrelid = 'public.config_assets'::regclass;
--
-- DOCUMENT the answers inline in the ASSUMPTIONS A1/A2/A4 below
-- before this file is approved for execution.
--
-- ── ASSUMPTIONS — chosen design + remaining checks ──────────────────
--   A1. Role-mapping design. RESOLVED — Option B (DB user_roles
--       table). New table public.user_roles(user_id pk → auth.users,
--       email, role check in ('admin','manager','viewer'), active,
--       audit fields). All RLS gates use the helpers
--       public.app_user_role(), public.app_can_write(),
--       public.app_is_admin() — see §1a/§1b/§1c. JWT claim path is
--       no longer load-bearing for role decisions.
--
--   A2. JWT claim path. NOT load-bearing under Option B. Still run
--       §A0 step 1 for diagnostic value (capture the JWT structure
--       so future auth changes are documented), but the migration
--       does not depend on `user_metadata.role` being populated.
--       App reads role via `_sb.rpc('app_user_role')` (Phase 2
--       app change, separate review).
--
--   A3. Manager allowlist (`manager@3imedtech.com`). RESOLVED — the
--       allowlist user gets a `user_roles` row with `role='manager'`
--       in the §1c backfill block. The client-side email-allowlist
--       fallback in `canManagePM()` is removed in Phase 2 app code,
--       coordinated with the migration deploy. DB-side Manager
--       writes are now first-class.
--
--   A4. Existing config_assets RLS. UNRESOLVED until §A0 step 2 is
--       run. This migration does not touch config_assets policies and
--       names new policies distinctly. Verify the existing set with
--       step 2 of §A0 and confirm no `v141_*` collisions.
--
--   A5. Foreign key shape. asset_lifecycle.asset_code references
--       config_assets.code. config_assets.code must be UNIQUE. The
--       migration adds a unique index defensively if no PK/UNIQUE
--       exists. Verify with §A0 step 3.
--
--   A6. Asset code immutability (decided product policy #6).
--       asset_code MUST NOT change after creation. Therefore this
--       migration uses `on update restrict` on the FK from
--       asset_lifecycle to config_assets — code rename is forbidden
--       at the DB layer. The companion app patch must also make the
--       Add/Edit Asset form's code field read-only post-creation.
--
-- Apply order (when approved): STAGING first. Verify with the
-- companion .verify.sql draft (to be authored after schema is
-- approved). Then PROD.
-- ═════════════════════════════════════════════════════════════════════

-- ── 0. Pre-flight (NOT NEEDED — staging inspection confirmed) ───────
-- The 2026-05-09 staging inspection (§3.1 in phase1_review.md)
-- confirmed that config_assets.code is already a PRIMARY KEY
-- (constraint `config_assets_pkey`, index `config_assets_pkey`). The
-- existing FK `config_assets_alias_of_fkey` already references
-- config_assets(code), proving the uniqueness is in place.
--
-- Therefore the defensive unique-index block (kept for environments
-- where the constraint might not exist) is REMOVED from this version.
-- The asset_lifecycle FK in §2 below references config_assets(code)
-- and will resolve against the existing PRIMARY KEY.
--
-- (No SQL in this section.)

-- ═════════════════════════════════════════════════════════════════════
-- §1a. user_roles table (structure only — RLS in §1c)
-- ═════════════════════════════════════════════════════════════════════
-- One row per Supabase auth user, mapping to the app's role string.
-- PK = user_id (FK -> auth.users with ON DELETE CASCADE) so the row
-- vanishes if the auth user is deleted. `email` is denormalized for
-- grep-ability and admin UI; not the identity.
create table if not exists public.user_roles (
  user_id     uuid          primary key
                            references auth.users(id)
                            on delete cascade,
  email       text          not null,
  role        text          not null
                            check (role in ('admin','manager','viewer')),
  active      boolean       not null default true,
  created_at  timestamptz   not null default now(),
  created_by  uuid          references auth.users(id),
  updated_at  timestamptz   not null default now(),
  updated_by  uuid          references auth.users(id),
  note        text
);

comment on table public.user_roles is
  'Role mapping for Supabase auth users. PK = user_id. role values: '
  '''admin'' (full write incl. config_assets/asset_lifecycle), '
  '''manager'' (parity with admin for asset/lifecycle writes; cannot '
  'manage user_roles), ''viewer'' (read-only — also covers Engineer). '
  'Audit Log access is gated by a separate email check (unchanged).';

create index if not exists user_roles_email_idx
  on public.user_roles(email);
create index if not exists user_roles_active_role_idx
  on public.user_roles(role)
  where active = true;


-- ═════════════════════════════════════════════════════════════════════
-- §1b. RLS helper functions — security definer, locked search_path
-- ═════════════════════════════════════════════════════════════════════
-- All three are STABLE so the planner can cache results within a
-- statement. SECURITY DEFINER + locked search_path means the helper
-- runs with the function owner's privileges and cannot be hijacked
-- by an attacker injecting a search_path entry. They read
-- public.user_roles directly without re-entering its RLS (the
-- helper executes as owner, bypassing RLS), which breaks the
-- recursion that would otherwise occur.

-- Returns the calling user's role string, or null if no active row.
create or replace function public.app_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.user_roles
   where user_id = auth.uid()
     and active = true
   limit 1;
$$;

-- Boolean: caller is admin or manager (write parity per product
-- decision #8).
create or replace function public.app_can_write()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.user_roles
     where user_id = auth.uid()
       and active  = true
       and role    in ('admin','manager')
  );
$$;

-- Boolean: caller is admin (privileged ops only — user_roles writes,
-- future audit gates if migrated off email check).
create or replace function public.app_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.user_roles
     where user_id = auth.uid()
       and active  = true
       and role    = 'admin'
  );
$$;

-- Grant execute to authenticated so PostgREST can call them as the
-- caller's session.
grant execute on function public.app_user_role() to authenticated;
grant execute on function public.app_can_write() to authenticated;
grant execute on function public.app_is_admin() to authenticated;

-- Lock function ownership / discourage rewrite without review.
comment on function public.app_user_role() is
  'Returns the caller''s app role from public.user_roles. SECURITY '
  'DEFINER + locked search_path; do not modify without security review. '
  'Used by RLS policies and by the app via _sb.rpc(''app_user_role'').';
comment on function public.app_can_write() is
  'Boolean: caller has write parity (admin or manager) on lifecycle / '
  'asset tables. Used by RLS policies on asset_lifecycle and (in '
  'Phase 2) on config_assets.';
comment on function public.app_is_admin() is
  'Boolean: caller is admin. Used by user_roles write policies and '
  'admin-only routes.';


-- ═════════════════════════════════════════════════════════════════════
-- §1c. user_roles RLS + last-admin guard
-- ═════════════════════════════════════════════════════════════════════
-- Now that the helper functions exist (§1b), we can create policies
-- that reference them. PostgreSQL resolves the function reference at
-- create-policy time, so this ordering matters.

alter table public.user_roles enable row level security;

drop policy if exists "v141_user_roles_select_self"  on public.user_roles;
drop policy if exists "v141_user_roles_select_admin" on public.user_roles;
drop policy if exists "v141_user_roles_write_admin"  on public.user_roles;

-- SELECT: every authenticated user can read their own row.
create policy "v141_user_roles_select_self"
  on public.user_roles for select
  to authenticated
  using (user_id = auth.uid());

-- SELECT (broad): admins can read all rows (admin UI in Phase 2+).
-- The helper runs SECURITY DEFINER, bypassing RLS internally, so this
-- does not recurse. The select_self policy covers non-admins; this
-- one extends visibility for admins.
create policy "v141_user_roles_select_admin"
  on public.user_roles for select
  to authenticated
  using ( public.app_is_admin() );

-- INSERT/UPDATE/DELETE: admin only, with the LAST-ADMIN GUARD baked
-- into the WITH CHECK clause. The guard prevents:
--   (a) demoting the last active admin (role <> 'admin' WHERE was admin)
--   (b) deactivating the last active admin (active=false WHERE was admin)
-- It does NOT prevent NEW admin rows from being created (that's net-positive).
-- DELETE is handled by the trigger below because Postgres does not
-- evaluate WITH CHECK on DELETE.
create policy "v141_user_roles_write_admin"
  on public.user_roles
  for all
  to authenticated
  using ( public.app_is_admin() )
  with check (
    public.app_is_admin()
    and (
      -- Allow if the resulting row is still admin+active...
      (role = 'admin' and active = true)
      -- ...OR if at least one OTHER active admin will exist after this op.
      or exists (
        select 1 from public.user_roles ur
         where ur.role = 'admin'
           and ur.active = true
           and ur.user_id <> user_roles.user_id
      )
    )
  );

-- DELETE protection — the policy USING gate alone does not prevent an
-- admin from deleting the last admin row. This trigger raises before
-- the DELETE commits.
create or replace function public._user_roles_block_last_admin_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.role = 'admin' and old.active = true then
    if not exists (
      select 1 from public.user_roles
       where role = 'admin'
         and active = true
         and user_id <> old.user_id
    ) then
      raise exception 'cannot delete the last active admin (user_id=%)',
        old.user_id
        using errcode = 'check_violation';
    end if;
  end if;
  return old;
end $$;

drop trigger if exists trg_user_roles_block_last_admin on public.user_roles;
create trigger trg_user_roles_block_last_admin
  before delete on public.user_roles
  for each row execute function public._user_roles_block_last_admin_delete();

-- updated_at maintenance (the function _touch_updated_at() is created
-- in §4 below; trigger creation only fires at runtime, so the forward
-- reference is fine).
drop trigger if exists trg_user_roles_touch on public.user_roles;
-- Trigger creation deferred to §4 once the function exists.

-- Grants — RLS does the gating; without these grants PostgREST returns
-- 401 before policies fire.
revoke all     on public.user_roles from anon;
grant  select  on public.user_roles to authenticated;
grant  insert, update, delete on public.user_roles to authenticated;


-- ═════════════════════════════════════════════════════════════════════
-- §1d. user_roles backfill (commented — run separately as service_role)
-- ═════════════════════════════════════════════════════════════════════
-- The backfill below MUST be run with the service_role key in the SQL
-- editor (it bypasses RLS). It is intentionally commented out in this
-- migration because the email allowlist must be reviewed against the
-- actual auth.users contents on staging FIRST.
--
-- BEFORE running the backfill, run this audit query to list every
-- existing auth user:
--
--   select id, email, raw_user_meta_data->>'role' as meta_role,
--          last_sign_in_at, created_at
--     from auth.users
--    order by created_at;
--
-- Verify that:
--   • every email expected to be admin is in the admin seed list
--   • every email expected to be manager is in the manager seed list
--   • there are no surprise users (former staff, test accounts) that
--     should be deactivated
--
-- Then update the seed lists below if needed, uncomment the block,
-- and run as service_role.

/*
-- Step 1. Seed known admin + manager rows.
insert into public.user_roles (user_id, email, role, note)
select u.id, u.email,
       case
         when u.email = 'abhijit.s@3imedtech.com' then 'admin'
         when u.email = 'manager@3imedtech.com'  then 'manager'
       end as role,
       'v1.4.1 backfill seed'
from auth.users u
where u.email in (
  'abhijit.s@3imedtech.com',
  'manager@3imedtech.com'
)
on conflict (user_id) do nothing;

-- Step 2. Default everyone else to viewer.
insert into public.user_roles (user_id, email, role, note)
select u.id, u.email, 'viewer', 'v1.4.1 backfill default'
from auth.users u
where not exists (
  select 1 from public.user_roles ur where ur.user_id = u.id
)
on conflict (user_id) do nothing;

-- Sanity: confirm at least one active admin exists. If zero, abort
-- the transaction. This protects against a misconfigured allowlist
-- locking everyone out.
do $$
declare admin_count int;
begin
  select count(*) into admin_count
    from public.user_roles where role='admin' and active=true;
  if admin_count = 0 then
    raise exception 'backfill produced zero active admins; aborting';
  end if;
end $$;
*/


-- ── 1. Extend config_assets ─────────────────────────────────────────
-- Adds lifecycle status + audit fields. All nullable except `status`
-- which defaults to 'active' so existing rows are unaffected.
--
-- 2026-05-09 staging inspection note: config_assets ALREADY has
-- `created_at` and `updated_at` columns from the XLSX-era schema, so
-- the two `add column if not exists` lines for those columns are
-- intentional no-ops on staging/prod. They are kept here for
-- robustness (in case a fresh environment runs this migration without
-- the legacy columns). The new audit fields actually added by 0003
-- are: status, de_installed_at, de_installed_by, created_by,
-- updated_by, note.
alter table public.config_assets
  add column if not exists status            text         not null default 'active'
    check (status in ('active','de_installed')),
  add column if not exists de_installed_at   timestamptz,
  add column if not exists de_installed_by   uuid,
  add column if not exists created_by        uuid,
  add column if not exists created_at        timestamptz  not null default now(),  -- pre-existing on staging
  add column if not exists updated_by        uuid,
  add column if not exists updated_at        timestamptz  not null default now(),  -- pre-existing on staging
  add column if not exists note              text;

comment on column public.config_assets.status is
  'Lifecycle status of the physical asset. ''active'' = in service. '
  '''de_installed'' = retired/removed; row is kept for history. '
  'De-installation is handled here, NOT via asset_lifecycle, so contract '
  'history remains queryable independently of physical asset status.';

-- Helpful filtered indexes
create index if not exists config_assets_status_idx
  on public.config_assets(status);

create index if not exists config_assets_active_idx
  on public.config_assets(status)
  where status = 'active';

-- ── 2. asset_lifecycle ──────────────────────────────────────────────
-- One active contract row per asset_code. Renewals create a NEW row
-- with status='active' and supersede the previous row (status flips
-- to 'superseded'). Cancelled contracts flip to 'cancelled'. Physical
-- de-installation does NOT touch this table — it only flips
-- config_assets.status to 'de_installed'.
create table if not exists public.asset_lifecycle (
  id              uuid          primary key default gen_random_uuid(),
  asset_code      text          not null
                                references public.config_assets(code)
                                on update restrict
                                on delete restrict,
  contract_type   text          not null
                                check (contract_type in (
                                  'warranty',
                                  'extended_warranty',
                                  'cmc',
                                  'labour_contract'
                                )),
  pm_required     boolean       not null
                                default true,
  contract_start  date,
  contract_end    date,
  status          text          not null
                                default 'active'
                                check (status in (
                                  'active',
                                  'superseded',
                                  'cancelled'
                                )),
  source_customer text,        -- raw customer name from PM/CMC source row
  source_ref      text,        -- e.g. PM_SCHEDULE.id or CMC_DATA.sn for trace
  created_by      uuid,
  created_at      timestamptz   not null default now(),
  updated_by      uuid,
  updated_at      timestamptz   not null default now(),
  note            text
);

comment on table public.asset_lifecycle is
  'One row per contract instance for an asset. Multiple historical rows '
  'per asset_code are allowed; at most one with status=''active''.';

comment on column public.asset_lifecycle.pm_required is
  'Set true for warranty / extended_warranty / cmc; false for '
  'labour_contract. Enforced by app + check constraint below.';

-- pm_required must follow contract_type. Labour contracts do not
-- include PM; the others do.
alter table public.asset_lifecycle
  drop constraint if exists asset_lifecycle_pm_required_consistency;
alter table public.asset_lifecycle
  add constraint asset_lifecycle_pm_required_consistency
  check (
    (contract_type = 'labour_contract' and pm_required = false)
    or
    (contract_type in ('warranty','extended_warranty','cmc') and pm_required = true)
  );

-- Date sanity. Optional fields, but if both present, end >= start.
alter table public.asset_lifecycle
  drop constraint if exists asset_lifecycle_dates_sane;
alter table public.asset_lifecycle
  add constraint asset_lifecycle_dates_sane
  check (
    contract_start is null
    or contract_end is null
    or contract_end >= contract_start
  );

-- One ACTIVE lifecycle per asset_code. Implemented as a partial unique
-- index because asset_code is allowed to have many superseded/cancelled
-- rows.
create unique index if not exists asset_lifecycle_one_active_per_asset
  on public.asset_lifecycle(asset_code)
  where status = 'active';

-- Common query patterns: by asset (history), by status (active set),
-- by contract type (urgency reporting).
create index if not exists asset_lifecycle_asset_code_idx
  on public.asset_lifecycle(asset_code);
create index if not exists asset_lifecycle_status_idx
  on public.asset_lifecycle(status);
create index if not exists asset_lifecycle_contract_type_idx
  on public.asset_lifecycle(contract_type);
-- Date range scans for renewal urgency
create index if not exists asset_lifecycle_active_end_idx
  on public.asset_lifecycle(contract_end)
  where status = 'active';

-- ── 3. asset_lifecycle_history ──────────────────────────────────────
-- Append-only event log. One row per state-changing action on an asset
-- or its lifecycle row. Stores `before` / `after` JSONB snapshots so
-- diffs are reconstructible without joining live tables.
create table if not exists public.asset_lifecycle_history (
  id            uuid          primary key default gen_random_uuid(),
  asset_code    text          not null,
  lifecycle_id  uuid,                              -- nullable for asset-only events
  event         text          not null
                              check (event in (
                                'created',
                                'updated',
                                'renewed',
                                'de_installed',
                                'reactivated',
                                'cancelled',
                                'backfill'
                              )),
  before_state  jsonb,
  after_state   jsonb,
  actor         uuid,
  actor_email   text,
  source        text,                              -- e.g. 'app:install_base_form', 'sql:backfill'
  occurred_at   timestamptz   not null default now(),
  note          text
);

comment on table public.asset_lifecycle_history is
  'Append-only event log for Install Base + contract lifecycle. '
  'Never updated or deleted in normal operations. Supersedes ad-hoc '
  'audit_log entries for asset-scoped changes.';

create index if not exists asset_lifecycle_history_asset_idx
  on public.asset_lifecycle_history(asset_code, occurred_at desc);
create index if not exists asset_lifecycle_history_lifecycle_idx
  on public.asset_lifecycle_history(lifecycle_id, occurred_at desc);
create index if not exists asset_lifecycle_history_event_idx
  on public.asset_lifecycle_history(event);

-- ── 4. Updated-at maintenance trigger ───────────────────────────────
-- Keeps updated_at fresh on row UPDATE without app-side discipline.
create or replace function public._touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists trg_config_assets_touch on public.config_assets;
create trigger trg_config_assets_touch
  before update on public.config_assets
  for each row execute function public._touch_updated_at();

drop trigger if exists trg_asset_lifecycle_touch on public.asset_lifecycle;
create trigger trg_asset_lifecycle_touch
  before update on public.asset_lifecycle
  for each row execute function public._touch_updated_at();

-- user_roles touch trigger (forward-referenced in §1c)
drop trigger if exists trg_user_roles_touch on public.user_roles;
create trigger trg_user_roles_touch
  before update on public.user_roles
  for each row execute function public._touch_updated_at();

-- ── 5. RLS — Option B (user_roles) ──────────────────────────────────
-- Policies call public.app_can_write() instead of inspecting the JWT
-- directly. The helper queries public.user_roles under SECURITY
-- DEFINER, so RLS evaluation does not depend on JWT structure.

-- Enable RLS on the new tables.
alter table public.asset_lifecycle         enable row level security;
alter table public.asset_lifecycle_history enable row level security;

-- Drop any pre-existing v1.4.1-prefixed policies so this migration is
-- safely re-runnable.
drop policy if exists "v141_lifecycle_select_authenticated"     on public.asset_lifecycle;
drop policy if exists "v141_lifecycle_insert_admin_manager"     on public.asset_lifecycle;
drop policy if exists "v141_lifecycle_update_admin_manager"     on public.asset_lifecycle;
drop policy if exists "v141_lifecycle_no_delete"                on public.asset_lifecycle;
drop policy if exists "v141_history_select_authenticated"       on public.asset_lifecycle_history;
drop policy if exists "v141_history_insert_authenticated"       on public.asset_lifecycle_history;  -- legacy name from earlier draft
drop policy if exists "v141_history_insert_app_can_write"       on public.asset_lifecycle_history;
drop policy if exists "v141_history_no_update"                  on public.asset_lifecycle_history;
drop policy if exists "v141_history_no_delete"                  on public.asset_lifecycle_history;

-- asset_lifecycle: SELECT — any authenticated user.
create policy "v141_lifecycle_select_authenticated"
  on public.asset_lifecycle for select
  to authenticated
  using (true);

-- asset_lifecycle: INSERT — admin or manager only (via user_roles).
-- Manager parity is established by inserting a row in user_roles with
-- role='manager' (see §1c backfill). The client-side email allowlist
-- in canManagePM() is removed in Phase 2 app code coordinated with
-- this migration.
create policy "v141_lifecycle_insert_admin_manager"
  on public.asset_lifecycle for insert
  to authenticated
  with check ( public.app_can_write() );

create policy "v141_lifecycle_update_admin_manager"
  on public.asset_lifecycle for update
  to authenticated
  using       ( public.app_can_write() )
  with check  ( public.app_can_write() );

-- DELETE is denied for everyone (status='cancelled' is the soft-delete
-- path). Even admin must use UPDATE.
create policy "v141_lifecycle_no_delete"
  on public.asset_lifecycle for delete
  to authenticated
  using (false);

-- asset_lifecycle_history: SELECT — any authenticated user (audit
-- visibility for managers reviewing an asset).
create policy "v141_history_select_authenticated"
  on public.asset_lifecycle_history for select
  to authenticated
  using (true);

-- INSERT — gated by app_can_write(). History rows must accompany real
-- lifecycle/asset mutations; permitting any authenticated user would
-- let Engineer/Viewer pollute the audit trail. service_role bypasses
-- RLS, so backfill scripts and system events still work.
create policy "v141_history_insert_app_can_write"
  on public.asset_lifecycle_history for insert
  to authenticated
  with check ( public.app_can_write() );

-- UPDATE — denied. History is immutable.
create policy "v141_history_no_update"
  on public.asset_lifecycle_history for update
  to authenticated
  using (false)
  with check (false);

-- DELETE — denied. History is immutable.
create policy "v141_history_no_delete"
  on public.asset_lifecycle_history for delete
  to authenticated
  using (false);

-- Revoke broader grants that bypass policies just in case.
revoke update, delete on public.asset_lifecycle_history from authenticated, anon;

-- ── 6. config_assets write policies (deferred to Phase 2) ───────────
-- This migration intentionally does NOT touch existing config_assets
-- policies. Any add/edit/de-install policy work happens in a separate
-- review file once:
--   (a) §A0 step 2 captures the current policy set, AND
--   (b) the XLSX bulk-upload behavior decision (§6 of phase1_review.md)
--       is made — A: upsert, B: preserve app_created, or C: disable
--       bulk replace.
-- When Phase 2 adds config_assets write policies, they will use the
-- same public.app_can_write() helper from §1b for consistency.

-- ── End of 0003 ─────────────────────────────────────────────────────
