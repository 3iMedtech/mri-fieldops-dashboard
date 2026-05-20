-- Migration 0015: Add 'working' to app_tickets_sys_status_check
--
-- 0012 defined sys_status as ('down', 'partially_down', 'planned_activity').
-- Closing a WO sets sys_status = 'working' (machine operational after resolution),
-- which was blocked by this constraint. Staging received this fix ad-hoc;
-- this migration makes it official on both environments.

ALTER TABLE public.app_tickets
  DROP CONSTRAINT IF EXISTS app_tickets_sys_status_check;

ALTER TABLE public.app_tickets
  ADD CONSTRAINT app_tickets_sys_status_check
    CHECK (sys_status IN ('down', 'partially_down', 'planned_activity', 'working'));
