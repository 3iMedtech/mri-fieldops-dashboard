-- 0017_v157_engineer_email_record.sql
-- Add engineer@3imedtech.com as ENG010 so the test/demo engineer account
-- is matched by _isCurrentEngineerAssigned() (frontend) and the
-- v150_app_tickets_update_write_or_assigned_engineer RLS policy (backend).
-- Without this row both layers return false/NULL and the engineer sees no WOs.

insert into public.engineers (id, name, email, region, status, aliases)
values ('ENG010', 'Demo Engineer', 'engineer@3imedtech.com', 'Bangalore', 'active', '{}')
on conflict (id) do nothing;
