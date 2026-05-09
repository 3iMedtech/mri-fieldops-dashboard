-- ═════════════════════════════════════════════════════════════════════
-- 0004_v141_phase2_additive_write_policies_ROLLBACK_REVIEW_ONLY.sql
--
-- ╭─────────────────────────────────────────────────────────────────╮
-- │  REVIEW ONLY — DO NOT APPLY YET                                 │
-- │  Mirror of 0004 — reverses the 6 additive policies              │
-- │  Legacy admin_* policies are NOT touched.                       │
-- ╰─────────────────────────────────────────────────────────────────╯
--
-- Use only if 0004 caused a regression. Manager loses DB-write
-- access immediately on rollback. Admin (JWT path) retains writes
-- via the legacy admin_* policies.
--
-- This rollback drops only the 6 v141_*_app_can_write policies.
-- It does NOT drop the helper functions, the user_roles table, the
-- lifecycle tables, or any 0003 artifact. (For full rollback to
-- pre-Phase-1 state, run 0003 rollback after this one.)
-- ═════════════════════════════════════════════════════════════════════

-- ── Drop additive policies (reverse of 0004 §1, §2, §3) ─────────────
drop policy if exists "v141_config_assets_insert_app_can_write"  on public.config_assets;
drop policy if exists "v141_config_assets_update_app_can_write"  on public.config_assets;
drop policy if exists "v141_pm_schedule_insert_app_can_write"    on public.pm_schedule;
drop policy if exists "v141_pm_schedule_update_app_can_write"    on public.pm_schedule;
drop policy if exists "v141_cmc_contracts_insert_app_can_write"  on public.cmc_contracts;
drop policy if exists "v141_cmc_contracts_update_app_can_write"  on public.cmc_contracts;

-- ── End of rollback ─────────────────────────────────────────────────
