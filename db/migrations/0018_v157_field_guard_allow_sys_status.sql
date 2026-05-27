-- 0018_v157_field_guard_allow_sys_status.sql
-- Remove sys_status from the engineer field guard.
-- sys_status is an operational outcome field that engineers must set
-- atomically when marking a WO resolved or closed (via the close-status-modal).
-- _atdSaveWork() (regular Save) never touches sys_status, so this only
-- enables the intended resolution/closure flow — not free-form edits.

create or replace function public._app_ticket_engineer_field_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Pass through for admin, manager, and service-role (null role).
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
