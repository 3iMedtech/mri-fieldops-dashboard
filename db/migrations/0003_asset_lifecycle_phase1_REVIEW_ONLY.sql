-- ═════════════════════════════════════════════════════════════════════
-- 0003_asset_lifecycle_phase1_REVIEW_ONLY.sql
--
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  REVIEW ONLY — DO NOT APPLY TO STAGING OR PRODUCTION YET        │
-- │  No implementation has been approved.                           │
-- │                                                                 │
-- │  ▼ ROLE MAPPING IS UNRESOLVED — see ASSUMPTION A1/A2 below.     │
-- │  ▼ SQL EXECUTION IS BLOCKED until role mapping is confirmed     │
-- │    via the Required Pre-SQL Verification Step (§A0) and the    │
-- │    chosen design option (A/B/C) is documented in this file.    │
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
-- ── ASSUMPTIONS — UNRESOLVED until verified per §A0 ─────────────────
--   A1. Role-mapping design. UNRESOLVED. The RLS draft below is a
--       PLACEHOLDER using the inline JWT-claim form. Three viable
--       designs — pick one before execution and replace the policies
--       accordingly:
--
--         Option A — JWT role claim (drafted as placeholder):
--           Each role policy reads `auth.jwt()->'user_metadata'->>'role'`
--           or whichever claim path §A0 step 1 reveals. Simplest, but
--           depends on the JWT being structured as expected and on
--           client/Supabase Auth dashboard setting `role` correctly
--           at signup.
--
--         Option B — DB user_roles table:
--           A new public.user_roles(user_id uuid pk references
--           auth.users(id), role text check in (...), updated_at).
--           Each policy joins `where exists (select 1 from user_roles
--           where user_id = auth.uid() and role in ('admin','manager'))`.
--           Decouples role from JWT claims; survives JWT
--           restructuring; admin can edit roles via SQL editor without
--           re-issuing tokens. Adds a small management surface.
--
--         Option C — Email allowlist mirrored in DB:
--           Policy uses `(auth.jwt()->>'email')` against a hardcoded
--           or table-driven allowlist. Mirrors the current
--           canManagePM() client-side fallback at the DB layer. Works
--           without JWT user_metadata, but couples DB to email
--           strings.
--
--       Until §A0 results are pasted into A1 and the design option is
--       chosen, this migration MUST NOT be executed.
--
--   A2. JWT claim path. UNRESOLVED. The app reads
--       `_currentUser.user_metadata.role` client-side. That MAY map to
--       `auth.jwt()->'user_metadata'->>'role'` in Postgres, but custom
--       Supabase Auth configurations can place the role in
--       `app_metadata.role` or a custom top-level claim. The placeholder
--       policies use `user_metadata.role` and will silently grant zero
--       admin/manager rights if the actual claim is elsewhere.
--       MUST be verified per §A0 step 1 before execution.
--
--   A3. Manager allowlist (`manager@3imedtech.com`). UNRESOLVED.
--       Today canManagePM() in the app code returns true for the
--       email allowlist regardless of `_userRole`. The DB has no
--       knowledge of this mapping. Three options:
--
--         (i)  Treat the allowlist as a transitional client-only
--              hack; require a real `manager` role be set in JWT
--              metadata before Phase 2 ships Manager write paths.
--              DB stays JWT-claim-driven only.
--         (ii) Mirror the allowlist in DB via Option C of A1.
--         (iii) Encode the allowlist in a DB user_roles table per
--               Option B.
--
--       Until this is resolved, **DB-side Manager INSERT/UPDATE rights
--       MUST NOT be enabled.** The placeholder policies admit
--       'admin','manager' from the JWT, which means the manager
--       allowlist user (without `role: 'manager'` in their JWT) will
--       NOT have DB write access. The current Manager-effective UI
--       experience is therefore client-only and will not survive a
--       direct PostgREST call. This is a deliberate gap and a blocker
--       for Phase 2 Manager-write features.
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

-- ── 0. Pre-flight: ensure config_assets.code is uniquely indexed ────
-- The lifecycle FK requires a UNIQUE constraint on the parent column.
-- If a PRIMARY KEY or UNIQUE constraint on `code` already exists, this
-- block is a no-op.
do $$
begin
  if not exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    where t.relname = 'config_assets'
      and c.contype in ('p','u')
      and (
        select array_agg(a.attname order by k.ord)
        from unnest(c.conkey) with ordinality k(attnum, ord)
        join pg_attribute a on a.attrelid = c.conrelid and a.attnum = k.attnum
      ) = array['code']::name[]
  ) then
    -- Defensive: only add a unique index, NOT a constraint, so we don't
    -- collide with any future PRIMARY KEY decision.
    if not exists (
      select 1 from pg_indexes
      where schemaname = 'public'
        and tablename  = 'config_assets'
        and indexname  = 'config_assets_code_uidx'
    ) then
      create unique index config_assets_code_uidx
        on public.config_assets(code);
    end if;
  end if;
end $$;

-- ── 1. Extend config_assets ─────────────────────────────────────────
-- Adds lifecycle status + audit fields. All nullable except `status`
-- which defaults to 'active' so existing rows are unaffected.
alter table public.config_assets
  add column if not exists status            text         not null default 'active'
    check (status in ('active','de_installed')),
  add column if not exists de_installed_at   timestamptz,
  add column if not exists de_installed_by   uuid,
  add column if not exists created_by        uuid,
  add column if not exists created_at        timestamptz  not null default now(),
  add column if not exists updated_by        uuid,
  add column if not exists updated_at        timestamptz  not null default now(),
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

-- ── 5. RLS — DRAFT (read ASSUMPTIONS A1–A3 above) ───────────────────
-- These policies use the inline JWT claim form (assumption A1.b).
-- If you choose to create app_user_role(), replace the
-- `auth.jwt()->'user_metadata'->>'role'` expression in each policy
-- accordingly.

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
drop policy if exists "v141_history_insert_authenticated"       on public.asset_lifecycle_history;
drop policy if exists "v141_history_no_update"                  on public.asset_lifecycle_history;
drop policy if exists "v141_history_no_delete"                  on public.asset_lifecycle_history;

-- asset_lifecycle: SELECT — any authenticated user.
create policy "v141_lifecycle_select_authenticated"
  on public.asset_lifecycle for select
  to authenticated
  using (true);

-- asset_lifecycle: INSERT — admin or manager only.
-- Manager email allowlist (assumption A3) is intentionally NOT mirrored
-- in DB; keep the database role check pure metadata-based and rely on
-- the app to grant the manager allowlist user the 'manager' role at
-- signup or via Supabase Auth dashboard.
create policy "v141_lifecycle_insert_admin_manager"
  on public.asset_lifecycle for insert
  to authenticated
  with check (
    (auth.jwt()->'user_metadata'->>'role') in ('admin','manager')
  );

create policy "v141_lifecycle_update_admin_manager"
  on public.asset_lifecycle for update
  to authenticated
  using (
    (auth.jwt()->'user_metadata'->>'role') in ('admin','manager')
  )
  with check (
    (auth.jwt()->'user_metadata'->>'role') in ('admin','manager')
  );

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

-- INSERT — any authenticated user, because history rows are written
-- alongside the parent action (which is itself gated). The parent
-- table policy already restricts who can mutate; history follows.
create policy "v141_history_insert_authenticated"
  on public.asset_lifecycle_history for insert
  to authenticated
  with check (true);

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

-- ── 6. config_assets write policies (additive) ──────────────────────
-- This migration intentionally does NOT touch existing config_assets
-- policies. Any add/edit/de-install policy work happens in a separate
-- review file once we confirm the current policy set on staging via
--   select * from pg_policies where tablename = 'config_assets';
-- The XLSX upload path currently calls .delete() then .insert() — we
-- must not break that bulk path. Phase 2 will introduce a partial
-- write policy or move XLSX upload to service_role only.

-- ── End of 0003 ─────────────────────────────────────────────────────
