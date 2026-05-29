-- 0019_subwo_rls_correlation_fix.sql
-- Fix the sub-WO INSERT policy for the FOURTH time-correctly this round.
--
-- History:
--   v150 policy used `p.id = p.parent_id` (always false).
--   0016 tried to fix it with `p.id = parent_id` — but inside the EXISTS
--   subquery `FROM app_tickets p`, the UNQUALIFIED `parent_id` resolves to the
--   subquery alias `p.parent_id`, NOT the new row. Postgres stored it back as
--   `p.id = p.parent_id` — i.e. 0016 was a no-op. Primaries have parent_id NULL,
--   so EXISTS is always false and engineers (viewer) can never INSERT a sub-WO.
--
-- Fix: qualify the new-row reference as `app_tickets.parent_id`. Because the
-- subquery's own relation is aliased to `p`, the base name `app_tickets` is not
-- shadowed inside the subquery and correlates to the policy's target (new) row.
--
-- Verified on staging 2026-05-29 with the engineer (viewer) auth context:
--   * valid open primary parent  -> INSERT allowed
--   * nonexistent/closed parent  -> INSERT denied (42501)
-- Admin/manager are unaffected (they insert via v150_app_tickets_insert_app_can_write).

DROP POLICY IF EXISTS "v150_app_tickets_insert_sub_wo_engineer" ON public.app_tickets;
DROP POLICY IF EXISTS "v160_app_tickets_insert_sub_wo_engineer" ON public.app_tickets;

CREATE POLICY "v160_app_tickets_insert_sub_wo_engineer" ON public.app_tickets
  FOR INSERT TO authenticated
  WITH CHECK (
    app_user_role() = 'viewer'
    AND wo_type = 'sub'
    AND parent_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM app_tickets p
      WHERE p.id = app_tickets.parent_id
        AND p.wo_type = 'primary'
        AND p.status <> ALL (ARRAY['closed'::text, 'cancelled'::text])
        AND p.deleted_at IS NULL
    )
  );
