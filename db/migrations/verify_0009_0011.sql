-- ═════════════════════════════════════════════════════════════════════
-- verify_0009_0011.sql
-- Run after applying 0009, 0010, 0011. All queries must return expected values.
-- ═════════════════════════════════════════════════════════════════════

-- 1. app_tickets table exists and has required columns
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'app_tickets'
order by ordinal_position;

-- 2. app_ticket_history table exists
select count(*) as history_table_exists
from information_schema.tables
where table_schema = 'public' and table_name = 'app_ticket_history';
-- expect: 1

-- 3. pm_completions has new columns
select column_name, data_type, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'pm_completions'
  and column_name in ('app_ticket_id', 'source');
-- expect: 2 rows

-- 4. Sequence exists
select sequence_name from information_schema.sequences
where sequence_schema = 'public' and sequence_name = 'app_ticket_seq';
-- expect: 1 row

-- 5. All 7 indexes on app_tickets exist
select indexname from pg_indexes
where schemaname = 'public' and tablename = 'app_tickets'
order by indexname;
-- expect: 7 indexes including app_tickets_pm_cycle_key_unique

-- 6. RLS is enabled on both tables
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in ('app_tickets', 'app_ticket_history');
-- expect: both rows rowsecurity = true

-- 7. Triggers on app_tickets
select trigger_name, event_manipulation, action_timing
from information_schema.triggers
where event_object_schema = 'public'
  and event_object_table = 'app_tickets'
order by trigger_name;
-- expect: 6 triggers (set_id, set_sla, status_guard, engineer_field_guard,
--                      touch_updated_at, history_capture)

-- 8. Smoke: insert a service ticket, verify auto-ID + SLA
insert into public.app_tickets
  (ticket_type, customer, call_date, region)
values
  ('service', 'VERIFY TEST - DELETE ME', current_date, 'test')
returning id, sla_due_at, status, created_at;
-- expect: id like 'SVC-YYYYMM-0001', sla_due_at = call_date + 1 day, status = 'new'

-- 9. Smoke: soft-delete the test row (verify no hard-delete policy blocks UPDATE)
update public.app_tickets
set deleted_at = now()
where customer = 'VERIFY TEST - DELETE ME';
-- expect: UPDATE 1

-- 10. Verify soft-deleted row not visible via SELECT policy
select count(*) as should_be_zero
from public.app_tickets
where customer = 'VERIFY TEST - DELETE ME';
-- expect: 0 (RLS hides deleted_at IS NOT NULL rows)
