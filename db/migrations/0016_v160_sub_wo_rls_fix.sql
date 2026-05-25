-- 0016_v160_sub_wo_rls_fix.sql
-- Fix sub-WO INSERT policy self-referential bug
-- Before: EXISTS clause used p.id = p.parent_id (always false — no WO is its own parent)
-- After:  EXISTS clause uses p.id = parent_id (parent_id refers to the new row being inserted)

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
      WHERE p.id = parent_id
        AND p.wo_type = 'primary'
        AND p.status <> ALL (ARRAY['closed'::text, 'cancelled'::text])
        AND p.deleted_at IS NULL
    )
  );
