-- ═════════════════════════════════════════════════════════════════════
-- 0010_v150_app_ticket_history.sql
--
-- Creates public.app_ticket_history — append-only audit trail.
-- Also installs the history-capture trigger on app_tickets.
-- Requires: 0009 applied first (app_tickets must exist).
-- ═════════════════════════════════════════════════════════════════════

-- ── §1. History table ────────────────────────────────────────────────
create table if not exists public.app_ticket_history (
  id          uuid          primary key default uuid_generate_v4(),
  ticket_id   text          not null
    references public.app_tickets(id) on delete cascade,
  changed_by  uuid          references auth.users(id) on delete set null,
  changed_at  timestamptz   not null default now(),
  -- event_type values: created, status_change, assignment, field_update, visit, comment
  event_type  text          not null,
  old_status  text,
  new_status  text,
  old_values  jsonb,
  new_values  jsonb,
  note        text
);

-- ── §2. RLS ──────────────────────────────────────────────────────────
alter table public.app_ticket_history enable row level security;

-- SELECT: all authenticated
drop policy if exists "v150_app_ticket_history_select" on public.app_ticket_history;
create policy "v150_app_ticket_history_select"
  on public.app_ticket_history for select
  to authenticated
  using ( true );

-- INSERT: admin/manager direct insert; trigger writes via security definer (bypasses RLS)
drop policy if exists "v150_app_ticket_history_insert" on public.app_ticket_history;
create policy "v150_app_ticket_history_insert"
  on public.app_ticket_history for insert
  to authenticated
  with check ( public.app_can_write() );

-- No UPDATE or DELETE policy — history is append-only and immutable.

-- ── §3. Indexes ──────────────────────────────────────────────────────
create index if not exists app_ticket_history_ticket_id_idx
  on public.app_ticket_history (ticket_id, changed_at desc);

create index if not exists app_ticket_history_changed_at_idx
  on public.app_ticket_history (changed_at desc);

-- ── §4. History capture trigger ──────────────────────────────────────
-- Fires AFTER INSERT or UPDATE on app_tickets.
-- Runs as security definer so the insert into app_ticket_history
-- succeeds regardless of the caller's role.
create or replace function public._app_ticket_history_capture()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  _event text;
begin
  if TG_OP = 'INSERT' then
    _event := 'created';
  elsif old.status <> new.status then
    _event := 'status_change';
  elsif old.assigned_engineer_ids is distinct from new.assigned_engineer_ids then
    _event := 'assignment';
  elsif old.visit_log is distinct from new.visit_log then
    _event := 'visit';
  else
    _event := 'field_update';
  end if;

  insert into public.app_ticket_history
    (ticket_id, changed_by, event_type, old_status, new_status, old_values, new_values)
  values (
    new.id,
    auth.uid(),
    _event,
    case when TG_OP = 'UPDATE' then old.status else null end,
    new.status,
    case when TG_OP = 'UPDATE' then to_jsonb(old) else null end,
    to_jsonb(new)
  );

  return new;
end;
$$;

drop trigger if exists app_ticket_history_capture_tg on public.app_tickets;
create trigger app_ticket_history_capture_tg
  after insert or update on public.app_tickets
  for each row execute function public._app_ticket_history_capture();

-- ── End of 0010 ──────────────────────────────────────────────────────
