-- 0010_v155_sla_trigger_ist.sql
-- Fix SLA trigger: interpret call_date in IST, not UTC
-- Before: call_date::timestamptz + 24h = UTC midnight + 1 day = 05:30 AM IST (wrong)
-- After:  (call_date + 1 day)::timestamp at time zone 'Asia/Kolkata' = IST midnight (correct)

create or replace function public._app_ticket_set_sla()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.ticket_type = 'service' and new.sla_due_at is null and new.call_date is not null then
    new.sla_due_at := (new.call_date + interval '1 day')::timestamp at time zone 'Asia/Kolkata';
  end if;
  return new;
end;
$$;

-- Backfill existing service WOs to corrected IST-midnight timestamps
update app_tickets
set sla_due_at = (call_date + interval '1 day')::timestamp at time zone 'Asia/Kolkata'
where ticket_type = 'service'
  and sla_due_at is not null
  and call_date is not null;
