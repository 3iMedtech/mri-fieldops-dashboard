-- ═════════════════════════════════════════════════════════════════════
-- 0009_v150_app_tickets_core.sql
--
-- Creates public.app_tickets — the new in-app ticketing table.
-- DOES NOT extend or alter public.tickets (the XLSX-sourced table).
-- XLSX upload at index.html:3200 runs DELETE on tickets; app_tickets
-- is a separate table so XLSX destructive deletes cannot affect it.
--
-- Apply order: STAGING → verify → PROD (explicit approval required).
-- Requires: migrations 0001–0008 applied; uuid_generate_v4() available.
-- ═════════════════════════════════════════════════════════════════════

-- ── §1. Ticket ID sequence ──────────────────────────────────────────
-- Provides the NNNN suffix. Prefix (SVC/PM) + month added in trigger.
create sequence if not exists public.app_ticket_seq
  start with 1
  increment by 1
  no maxvalue
  no cycle;

-- ── §2. Core table ──────────────────────────────────────────────────
create table if not exists public.app_tickets (

  -- identity
  id                          text          primary key,
  ticket_type                 text          not null
    constraint app_tickets_ticket_type_check
      check (ticket_type in ('service', 'pm')),

  -- status (shared values where semantics align; ticket_type determines machine)
  -- Service: new → assigned → in_progress → on_hold / parts_pending → resolved → closed
  -- PM:      upcoming → due → in_progress → completed → closed
  -- Both:    cancelled is reversible (→ new / → upcoming); closed is soft-terminal
  status                      text          not null default 'new'
    constraint app_tickets_status_check
      check (status in (
        'new', 'assigned', 'in_progress', 'on_hold', 'parts_pending',
        'resolved', 'closed', 'cancelled',
        'upcoming', 'due', 'completed', 'missed', 'deferred'
      )),

  -- asset / site
  asset_code                  text,
  customer                    text,
  town                        text,
  state                       text,
  region                      text,
  model                       text,
  contract                    text,

  -- PM link (null for service tickets)
  pm_id                       text,
  -- dedup key: '<pm_id>::<YYYY-MM>' — unique index on non-closed, non-cancelled PM tickets
  pm_cycle_key                text,

  -- call / complaint (service tickets)
  call_date                   date,
  call_type                   text,
  issue_description           text,

  -- parts tracking
  parts                       text,
  parts_req_date              date,
  parts_recv_date             date,
  parts_status                text,

  -- resolution
  resolution                  text,
  sys_up_date                 date,

  -- timestamps stamped by triggers
  resolved_at                 timestamptz,
  closed_at                   timestamptz,

  -- SLA: 24h from call_date for all priorities (Q4:A); stamped by trigger on insert
  priority                    text          not null default 'normal'
    constraint app_tickets_priority_check
      check (priority in ('critical', 'high', 'normal', 'low')),
  sla_due_at                  timestamptz,

  -- assignment: max 2 engineers (Q7:B)
  assigned_engineer_ids       text[]        not null default '{}'
    constraint app_tickets_max_engineers_check
      check (
        assigned_engineer_ids = '{}'
        or array_length(assigned_engineer_ids, 1) <= 2
      ),
  assigned_engineer_names     text[]        not null default '{}',

  -- PM completion attribution: closer gets pm_completions credit (Q1:C)
  -- Both engineers are also recorded in visit_log
  pm_completion_engineer_id   text,
  pm_completion_engineer_name text,

  -- append-only visit timeline; each entry: {engineer_id, engineer_name, action, ts}
  visit_log                   jsonb         not null default '[]'::jsonb,

  -- soft delete only — no hard delete for any role (Q10:A)
  deleted_at                  timestamptz,

  -- audit
  created_by                  uuid          references auth.users(id) on delete set null,
  updated_by                  uuid          references auth.users(id) on delete set null,
  created_at                  timestamptz   not null default now(),
  updated_at                  timestamptz   not null default now()
);

-- ── §3. Indexes ─────────────────────────────────────────────────────
create index if not exists app_tickets_status_idx
  on public.app_tickets (status)
  where deleted_at is null;

create index if not exists app_tickets_asset_code_idx
  on public.app_tickets (asset_code)
  where deleted_at is null;

create index if not exists app_tickets_region_idx
  on public.app_tickets (region)
  where deleted_at is null;

create index if not exists app_tickets_call_date_idx
  on public.app_tickets (call_date desc)
  where deleted_at is null;

-- PM dedup: one open PM ticket per pm_id × calendar month (Q3:B — auto-create on day 0)
create unique index if not exists app_tickets_pm_cycle_key_unique
  on public.app_tickets (pm_cycle_key)
  where pm_cycle_key is not null
    and deleted_at is null
    and status not in ('closed', 'cancelled');

-- GIN for engineer ID array lookups
create index if not exists app_tickets_engineer_ids_idx
  on public.app_tickets using gin (assigned_engineer_ids)
  where deleted_at is null;

create index if not exists app_tickets_created_at_idx
  on public.app_tickets (created_at desc);

-- ── §4. RLS ─────────────────────────────────────────────────────────
alter table public.app_tickets enable row level security;

-- SELECT: all authenticated users see all non-deleted tickets (Q5:A — UI name filter only)
drop policy if exists "v150_app_tickets_select_authenticated" on public.app_tickets;
create policy "v150_app_tickets_select_authenticated"
  on public.app_tickets for select
  to authenticated
  using ( deleted_at is null );

-- INSERT: admin or manager only
drop policy if exists "v150_app_tickets_insert_app_can_write" on public.app_tickets;
create policy "v150_app_tickets_insert_app_can_write"
  on public.app_tickets for insert
  to authenticated
  with check ( public.app_can_write() );

-- UPDATE: admin/manager full; engineer only if assigned + field guard trigger enforces column scope
drop policy if exists "v150_app_tickets_update_write_or_assigned_engineer" on public.app_tickets;
create policy "v150_app_tickets_update_write_or_assigned_engineer"
  on public.app_tickets for update
  to authenticated
  using ( deleted_at is null )
  with check (
    public.app_can_write()
    or (
      public.app_user_role() = 'viewer'
      and assigned_engineer_ids @> array[
        (select id from public.engineers where email = auth.email() limit 1)
      ]
    )
  );

-- No DELETE policy: soft-delete only via deleted_at column.

-- ── §5. Auto-ID trigger ─────────────────────────────────────────────
create or replace function public._app_ticket_set_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  _prefix text;
  _seq    bigint;
begin
  if new.id is not null and new.id <> '' then
    return new;
  end if;
  _prefix := case new.ticket_type when 'pm' then 'PM' else 'SVC' end;
  _seq    := nextval('public.app_ticket_seq');
  new.id  := _prefix || '-' || to_char(now(), 'YYYYMM') || '-' || lpad(_seq::text, 4, '0');
  return new;
end;
$$;

drop trigger if exists app_ticket_set_id_tg on public.app_tickets;
create trigger app_ticket_set_id_tg
  before insert on public.app_tickets
  for each row execute function public._app_ticket_set_id();

-- ── §6. SLA trigger ─────────────────────────────────────────────────
-- sla_due_at = call_date + 24h for all priorities (Q4:A)
create or replace function public._app_ticket_set_sla()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.ticket_type = 'service'
     and new.sla_due_at is null
     and new.call_date is not null
  then
    new.sla_due_at := new.call_date::timestamptz + interval '24 hours';
  end if;
  return new;
end;
$$;

drop trigger if exists app_ticket_set_sla_tg on public.app_tickets;
create trigger app_ticket_set_sla_tg
  before insert on public.app_tickets
  for each row execute function public._app_ticket_set_sla();

-- ── §7. Status guard trigger ─────────────────────────────────────────
-- Enforces state machine on UPDATE. Also stamps resolved_at / closed_at.
-- Auto-close after 2 days (Q2:B) is enforced in the app layer on load
-- (app checks resolved_at + 2 days < now() and calls this transition).
-- Cancelled is reversible for both service and PM tickets (Q8:A).
create or replace function public._app_ticket_status_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  _allowed text[];
begin
  if old.status = new.status then return new; end if;

  if new.ticket_type = 'service' then
    _allowed := case old.status
      when 'new'           then array['assigned','cancelled']
      when 'assigned'      then array['in_progress','cancelled','new']
      when 'in_progress'   then array['on_hold','parts_pending','resolved','cancelled']
      when 'on_hold'       then array['in_progress','cancelled']
      when 'parts_pending' then array['in_progress','cancelled']
      when 'resolved'      then array['closed','in_progress']
      when 'cancelled'     then array['new']
      when 'closed'        then array['in_progress']
      else                      array[]::text[]
    end;
  else
    -- PM ticket state machine
    _allowed := case old.status
      when 'upcoming'    then array['due','deferred','cancelled']
      when 'due'         then array['in_progress','missed','deferred','cancelled']
      when 'in_progress' then array['completed','deferred','cancelled']
      when 'completed'   then array['closed']
      when 'missed'      then array['in_progress','deferred']
      when 'deferred'    then array['due','cancelled']
      when 'cancelled'   then array['upcoming']
      when 'closed'      then array[]::text[]
      else                    array[]::text[]
    end;
  end if;

  if not (new.status = any(_allowed)) then
    raise exception 'Invalid status transition for ticket % (type=%): % → %',
      old.id, old.ticket_type, old.status, new.status;
  end if;

  -- Stamp timestamps on state entry
  if new.status = 'resolved' and old.status <> 'resolved' then
    new.resolved_at := now();
  end if;
  if new.status in ('closed') and old.status not in ('closed') then
    new.closed_at := now();
  end if;
  -- Clear resolved_at when reopened from resolved
  if old.status = 'resolved' and new.status = 'in_progress' then
    new.resolved_at := null;
  end if;

  return new;
end;
$$;

drop trigger if exists app_ticket_status_guard_tg on public.app_tickets;
create trigger app_ticket_status_guard_tg
  before update on public.app_tickets
  for each row execute function public._app_ticket_status_guard();

-- ── §8. Engineer field guard trigger ────────────────────────────────
-- Engineers (viewer role) may only write: status, resolution, sys_up_date,
-- parts, parts_req_date, parts_recv_date, parts_status, visit_log,
-- pm_completion_engineer_id, pm_completion_engineer_name, updated_by.
-- All identity, assignment, SLA, and PM link columns are protected.
create or replace function public._app_ticket_engineer_field_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Pass through for admin, manager, and service-role (null role).
  -- app_user_role() returns null when auth.uid() is null (service key).
  -- Use IS DISTINCT FROM to treat null as non-viewer.
  if public.app_user_role() is distinct from 'viewer' then return new; end if;

  if (
    new.id                      is distinct from old.id                      or
    new.ticket_type             is distinct from old.ticket_type             or
    new.asset_code              is distinct from old.asset_code              or
    new.customer                is distinct from old.customer                or
    new.town                    is distinct from old.town                    or
    new.state                   is distinct from old.state                   or
    new.region                  is distinct from old.region                  or
    new.model                   is distinct from old.model                   or
    new.contract                is distinct from old.contract                or
    new.call_date               is distinct from old.call_date               or
    new.call_type               is distinct from old.call_type               or
    new.issue_description       is distinct from old.issue_description       or
    new.priority                is distinct from old.priority                or
    new.assigned_engineer_ids   is distinct from old.assigned_engineer_ids   or
    new.assigned_engineer_names is distinct from old.assigned_engineer_names or
    new.sla_due_at              is distinct from old.sla_due_at              or
    new.pm_id                   is distinct from old.pm_id                   or
    new.pm_cycle_key            is distinct from old.pm_cycle_key            or
    new.deleted_at              is distinct from old.deleted_at              or
    new.created_by              is distinct from old.created_by
  ) then
    raise exception 'Engineers may not modify protected ticket fields on ticket %', old.id;
  end if;

  return new;
end;
$$;

drop trigger if exists app_ticket_engineer_field_guard_tg on public.app_tickets;
create trigger app_ticket_engineer_field_guard_tg
  before update on public.app_tickets
  for each row execute function public._app_ticket_engineer_field_guard();

-- ── §9. updated_at trigger ───────────────────────────────────────────
create or replace function public._app_ticket_touch_updated_at()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists app_ticket_touch_updated_at_tg on public.app_tickets;
create trigger app_ticket_touch_updated_at_tg
  before update on public.app_tickets
  for each row execute function public._app_ticket_touch_updated_at();

-- ── End of 0009 ──────────────────────────────────────────────────────
