-- ═════════════════════════════════════════════════════════════════════
-- 0012_v150_work_order_redesign.sql
--
-- Extends app_tickets for the Work Order redesign:
--   • sys_status replaces priority in the UI (column kept for compat)
--   • wo_type + parent_id enable sub-work-orders
--   • legacy_ref stores the original XLSX ticket ID for migrated rows
--   • call_type gets a CHECK constraint (Incident/Installation/Other)
--   • Cross-column call_type ↔ sys_status dependency enforced in DB
--   • Status guard trigger updated for sub-WO simplified machine
--   • Engineer field guard updated to protect new structural columns
--   • RLS: engineers may INSERT sub-WOs on open primary WOs
--
-- Apply order: STAGING → verify → PROD (explicit approval required).
-- Requires: 0009–0011 applied.
-- ═════════════════════════════════════════════════════════════════════

-- ── §1. Data migration — remap legacy call_type values ───────────────
-- 'Breakdown' → 'Incident' (closest semantic match)
-- 'PM'        → NULL (PM work handled by ticket_type='pm', not call_type)
-- ''          → NULL (empty string normalised to NULL)
update public.app_tickets set call_type = 'Incident'  where call_type = 'Breakdown';
update public.app_tickets set call_type = null         where call_type = 'PM';
update public.app_tickets set call_type = null         where call_type = '';

-- ── §2. New columns ──────────────────────────────────────────────────
alter table public.app_tickets
  add column if not exists sys_status  text,
  add column if not exists parent_id   text
    references public.app_tickets(id) on delete set null,
  add column if not exists wo_type     text not null default 'primary',
  add column if not exists legacy_ref  text;

-- ── §3. Constraints ──────────────────────────────────────────────────
-- wo_type
alter table public.app_tickets
  drop constraint if exists app_tickets_wo_type_check;
alter table public.app_tickets
  add  constraint app_tickets_wo_type_check
    check (wo_type in ('primary', 'sub'));

-- sys_status
alter table public.app_tickets
  drop constraint if exists app_tickets_sys_status_check;
alter table public.app_tickets
  add  constraint app_tickets_sys_status_check
    check (sys_status in ('down', 'partially_down', 'planned_activity'));

-- call_type: allowed values for service tickets; PM tickets exempt
alter table public.app_tickets
  drop constraint if exists app_tickets_call_type_check;
alter table public.app_tickets
  add  constraint app_tickets_call_type_check
    check (
      ticket_type = 'pm'
      or call_type is null
      or call_type in ('Incident', 'Installation', 'Other')
    );

-- call_type ↔ sys_status dependency
alter table public.app_tickets
  drop constraint if exists app_tickets_calltype_sysstatus_check;
alter table public.app_tickets
  add  constraint app_tickets_calltype_sysstatus_check
    check (
      call_type is null or sys_status is null or
      (call_type = 'Incident'     and sys_status in ('down', 'partially_down')) or
      (call_type = 'Installation' and sys_status = 'planned_activity') or
      (call_type = 'Other'        and sys_status = 'planned_activity')
    );

-- ── §4. Indexes ──────────────────────────────────────────────────────
create index if not exists app_tickets_parent_id_idx
  on public.app_tickets (parent_id)
  where parent_id is not null and deleted_at is null;

create index if not exists app_tickets_wo_type_idx
  on public.app_tickets (wo_type)
  where deleted_at is null;

create index if not exists app_tickets_legacy_ref_idx
  on public.app_tickets (legacy_ref)
  where legacy_ref is not null;

-- ── §5. RLS — sub-WO INSERT by engineers ────────────────────────────
-- Engineers (viewer role) may insert a sub-WO when:
--   1. wo_type = 'sub' (must be sub, not primary)
--   2. parent_id references an open primary WO
-- This policy is permissive; the existing app_can_write() policy continues
-- to cover admin/manager inserts.
drop policy if exists "v150_app_tickets_insert_sub_wo_engineer" on public.app_tickets;
create policy "v150_app_tickets_insert_sub_wo_engineer"
  on public.app_tickets for insert
  to authenticated
  with check (
    public.app_user_role() = 'viewer'
    and wo_type = 'sub'
    and parent_id is not null
    and exists (
      select 1 from public.app_tickets p
      where p.id      = parent_id
        and p.wo_type = 'primary'
        and p.status  not in ('closed', 'cancelled')
        and p.deleted_at is null
    )
  );

-- ── §6. Status guard trigger — updated for sub-WO machine ───────────
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

  -- Sub-WO simplified machine (new → in_progress → completed → closed)
  if new.wo_type = 'sub' then
    _allowed := case old.status
      when 'new'         then array['in_progress','cancelled']
      when 'in_progress' then array['completed','cancelled']
      when 'completed'   then array['closed']
      when 'cancelled'   then array['new']
      when 'closed'      then array[]::text[]
      else                    array[]::text[]
    end;

  elsif new.ticket_type = 'service' then
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
    raise exception 'Invalid status transition for ticket % (type=%, wo_type=%): % → %',
      old.id, old.ticket_type, old.wo_type, old.status, new.status;
  end if;

  -- Stamp timestamps on state entry
  if new.status = 'resolved' and old.status <> 'resolved' then
    new.resolved_at := now();
  end if;
  if new.status = 'closed' and old.status <> 'closed' then
    new.closed_at := now();
  end if;
  -- Clear resolved_at when reopened from resolved
  if old.status = 'resolved' and new.status = 'in_progress' then
    new.resolved_at := null;
  end if;

  return new;
end;
$$;

-- ── §7. Engineer field guard — protect new structural columns ────────
create or replace function public._app_ticket_engineer_field_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Pass through for admin, manager, and service-role (null role).
  -- IS DISTINCT FROM treats null as non-viewer (null ≠ 'viewer').
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
    new.sys_status              is distinct from old.sys_status              or
    new.assigned_engineer_ids   is distinct from old.assigned_engineer_ids   or
    new.assigned_engineer_names is distinct from old.assigned_engineer_names or
    new.sla_due_at              is distinct from old.sla_due_at              or
    new.pm_id                   is distinct from old.pm_id                   or
    new.pm_cycle_key            is distinct from old.pm_cycle_key            or
    new.parent_id               is distinct from old.parent_id               or
    new.wo_type                 is distinct from old.wo_type                 or
    new.legacy_ref              is distinct from old.legacy_ref              or
    new.deleted_at              is distinct from old.deleted_at              or
    new.created_by              is distinct from old.created_by
  ) then
    raise exception 'Engineers may not modify protected ticket fields on ticket %', old.id;
  end if;

  return new;
end;
$$;

-- ── End of 0012 ──────────────────────────────────────────────────────
