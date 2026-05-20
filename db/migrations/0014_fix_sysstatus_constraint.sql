-- Migration 0014: Allow 'working' sys_status on WO closure
--
-- Problem: app_tickets_calltype_sysstatus_check blocks setting sys_status='working'
-- when closing an Incident/Installation/Other WO via the close-status modal.
-- The constraint was written for creation-time validation only but was not
-- extended to allow the post-resolution state ('working' = machine operational).
-- Result: 0 WOs have ever been successfully closed in production.
--
-- Fix: Add 'working' to the allowed set for all call_types. The creation form
-- already restricts what can be selected at create time (Incident → down/partially_down,
-- Installation/Other → planned_activity) so this constraint only needs to not
-- block the resolution transition.

ALTER TABLE public.app_tickets
  DROP CONSTRAINT IF EXISTS app_tickets_calltype_sysstatus_check;

ALTER TABLE public.app_tickets
  ADD CONSTRAINT app_tickets_calltype_sysstatus_check CHECK (
    call_type IS NULL OR
    sys_status IS NULL OR
    (call_type = 'Incident'     AND sys_status IN ('down', 'partially_down', 'working')) OR
    (call_type = 'Installation' AND sys_status IN ('planned_activity', 'working')) OR
    (call_type = 'Other'        AND sys_status IN ('planned_activity', 'working'))
  );
