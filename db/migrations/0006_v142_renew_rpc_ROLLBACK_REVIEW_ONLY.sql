-- ═════════════════════════════════════════════════════════════════════
-- 0006_v142_renew_rpc_ROLLBACK_REVIEW_ONLY.sql
--
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  REVIEW ONLY — DO NOT APPLY YET                                 │
-- │  Mirror rollback for 0006_v142_renew_rpc_REVIEW_ONLY.sql        │
-- │  Drops public.app_renew_asset(...) only.                        │
-- ╰─────────────────────────────────────────────────────────────────╯
--
-- Use only if 0006 caused a regression.  Dropping the RPC removes
-- Renew capability from the app immediately; previously-renewed
-- assets retain their `asset_lifecycle` and `asset_lifecycle_history`
-- rows (this rollback does NOT touch data).
--
-- After rollback, the runtime Renew button should also be reverted
-- (separate `git revert` of the Track A runtime PR), otherwise users
-- will see a UI affordance that errors on click.

begin;

drop function if exists public.app_renew_asset(text,text,date,date,text,text,text);

commit;

-- ── Post-rollback verification ──────────────────────────────────────
--
--   select count(*) as still_present
--     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public' and p.proname = 'app_renew_asset';
--   -- expected: 0
--
-- ── End of 0006 rollback ────────────────────────────────────────────
