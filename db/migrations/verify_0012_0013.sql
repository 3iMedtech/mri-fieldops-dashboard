-- ═════════════════════════════════════════════════════════════════════
-- verify_0012_0013.sql
-- Run after applying 0012 and 0013. All queries must return expected values.
-- ═════════════════════════════════════════════════════════════════════

-- 1. New columns exist on app_tickets
select column_name, data_type, column_default, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'app_tickets'
  and column_name in ('sys_status','parent_id','wo_type','legacy_ref')
order by column_name;
-- expect: 4 rows

-- 2. wo_type default is 'primary' for all existing rows
select count(*) as rows_with_bad_wo_type
from public.app_tickets
where wo_type <> 'primary';
-- expect: 0

-- 3. Constraints exist
select conname, contype
from pg_constraint
where conrelid = 'public.app_tickets'::regclass
  and conname in (
    'app_tickets_wo_type_check',
    'app_tickets_sys_status_check',
    'app_tickets_call_type_check',
    'app_tickets_calltype_sysstatus_check'
  )
order by conname;
-- expect: 4 rows, all contype = 'c' (CHECK)

-- 4. Indexes exist
select indexname from pg_indexes
where schemaname = 'public' and tablename = 'app_tickets'
  and indexname in (
    'app_tickets_parent_id_idx',
    'app_tickets_wo_type_idx',
    'app_tickets_legacy_ref_idx'
  )
order by indexname;
-- expect: 3 rows

-- 5. app_ticket_notifications table exists
select count(*) as notifications_table_exists
from information_schema.tables
where table_schema = 'public' and table_name = 'app_ticket_notifications';
-- expect: 1

-- 6. RLS enabled on notifications table
select tablename, rowsecurity
from pg_tables
where schemaname = 'public' and tablename = 'app_ticket_notifications';
-- expect: rowsecurity = true

-- 7. Sub-WO INSERT policy exists
select policyname from pg_policies
where schemaname = 'public'
  and tablename = 'app_tickets'
  and policyname = 'v150_app_tickets_insert_sub_wo_engineer';
-- expect: 1 row

-- 8. No legacy call_type values remain
select call_type, count(*) from public.app_tickets
where call_type in ('Breakdown','PM','')
group by call_type;
-- expect: 0 rows

-- 9. Smoke: valid insert — Incident + down (must succeed)
insert into public.app_tickets
  (ticket_type, customer, call_type, sys_status, region, call_date)
values
  ('service', 'VERIFY-0012 DELETE ME', 'Incident', 'down', 'test', current_date)
returning id, call_type, sys_status, wo_type, status;
-- expect: row returned, wo_type='primary', status='new'

-- 10. Smoke: invalid — Incident + planned_activity (must raise exception)
do $$
begin
  insert into public.app_tickets
    (ticket_type, customer, call_type, sys_status, region, call_date)
  values
    ('service', 'VERIFY-0012-BAD', 'Incident', 'planned_activity', 'test', current_date);
  raise exception 'FAIL: constraint app_tickets_calltype_sysstatus_check did not fire';
exception
  when check_violation then
    raise notice 'PASS: calltype_sysstatus_check correctly rejected Incident+planned_activity';
end;
$$;

-- 11. Smoke: sub-WO linked to parent (must succeed)
do $$
declare
  _parent_id text;
  _sub_id    text;
begin
  -- create parent
  insert into public.app_tickets
    (ticket_type, customer, call_type, sys_status, region, call_date)
  values ('service','VERIFY-PARENT','Incident','down','test',current_date)
  returning id into _parent_id;

  -- create sub-WO
  insert into public.app_tickets
    (ticket_type, customer, region, call_date, wo_type, parent_id)
  values ('service','VERIFY-PARENT','test',current_date,'sub',_parent_id)
  returning id into _sub_id;

  raise notice 'PASS: sub-WO % created under parent %', _sub_id, _parent_id;
end;
$$;

-- 12. Soft-delete verify rows
update public.app_tickets
set deleted_at = now()
where customer in ('VERIFY-0012 DELETE ME', 'VERIFY-PARENT');
-- expect: UPDATE 2 (parent + sub)

-- 13. Verify deleted rows not visible via RLS select policy
select count(*) as should_be_zero
from public.app_tickets
where customer in ('VERIFY-0012 DELETE ME', 'VERIFY-PARENT');
-- expect: 0
