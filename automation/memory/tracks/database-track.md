# Memory — Database Track

**Read by:** `fieldops-database-pm`, `fieldops-sql-rls-safety-agent`, `fieldops-migration-runbook-verifier`, `fieldops-data-reconciliation-agent`. Also read by `fieldops-release-pm` (release depends on DB track).
**Format:** see [`../MEMORY_PROTOCOL.md`](../MEMORY_PROTOCOL.md) §4.
**Cap:** ~30 entries.

---

## fieldops-database-pm

### L-DBPM-001 — 0004 → 0005 sequencing is non-negotiable

- **Date:** 2026-05-09
- **Commit / PR:** PR #26 (`feat/v1.4.1-phase2-review`)
- **Agent:** Database PM
- **Event:** Phase 2 ships 0004 (additive write policies) and 0005 (V2 backfill). 0005 depends on `app_can_write()` GRANT/RLS state established by 0004.
- **Mistake or discovery:** running 0005 before 0004 PASS verification would write against tables whose RLS doesn't yet permit them.
- **Root cause:** convenience-bias toward "apply both at once".
- **Prevention rule:** Database PM applies 0004, runs §3.3 verification, advances Stop Point #4 → only then begins 0005.
- **Applies to:** Phase 2 staging apply; Phase 2 production apply. Category: SQL/RLS traps; recurring errors.
- **Staleness risk:** archive after Phase 2 ships to production.
- **Action added:** runbook stop points #3, #4 enforce the gap.
- **Linked files:** `db/migrations/0004_v141_phase2_additive_write_policies_REVIEW_ONLY.sql`, `db/migrations/0005_v141_phase2_install_base_master_backfill_REVIEW_ONLY.sql`, `docs/v1.4.1_phase2_staging_apply_runbook.md`.

### L-DBPM-002 — Production approval phrase never inherited from staging

- **Date:** 2026-05-09
- **Commit / PR:** Round-2 review
- **Agent:** Database PM
- **Event:** when staging passes, there's a temptation to advance to production "since the operator already approved Phase 2".
- **Mistake or discovery:** staging approval (`approved, apply phase 2 to staging`) does not authorize production.
- **Root cause:** combined-environment thinking. See [`../GLOBAL_LESSONS.md`](../GLOBAL_LESSONS.md) L-G-003.
- **Prevention rule:** Database PM HOLDs at production gate until operator types `approved, apply phase 2 to production` literally.
- **Applies to:** every cross-environment apply. Category: operator-confusion traps; Supabase environment traps.
- **Staleness risk:** invariant.
- **Action added:** Database PM hard stop verifies phrase target.
- **Linked files:** `.claude/agents/fieldops-database-pm.md`.

### L-DBPM-003 — Re-run specialists when migration content changes

- **Date:** 2026-05-10
- **Commit / PR:** consistency audit at `c3674f2`
- **Agent:** Database PM
- **Event:** if any byte of `db/migrations/000[45]*.sql` or the staging runbook changes between specialist PASS and SQL apply, prior PASS is no longer binding.
- **Mistake or discovery:** PASS is bound to a specific SHA; SHA-drift invalidates it.
- **Root cause:** convenience-bias toward "we already reviewed this".
- **Prevention rule:** Database PM diffs the migration + runbook files between last specialist PASS SHA and current HEAD. Non-empty diff → re-run sql-rls-safety + runbook-verifier on the new SHA before any apply.
- **Applies to:** every SQL apply approval. Category: Git/PR traps; recurring errors.
- **Staleness risk:** invariant.
- **Action added:** Database PM hard stop already lists this; this entry codifies the diff command.
- **Linked files:** `.claude/agents/fieldops-database-pm.md`, `automation/STATE.md`.

### L-DBPM-004 — Supabase SQL Editor suppresses NOTICE / intermediate output for committed transactions

- **Date:** 2026-05-10
- **Commit / PR:** PR #26 / Phase 2 staging apply (0005)
- **Agent:** Database PM
- **Event:** 0005 apply showed only `Success. No rows returned.` in the SQL Editor Results panel. Runbook §4.2 lists `BEGIN / CREATE TABLE / INSERT / NOTICE / DO / COMMIT` lines that did not appear visibly.
- **Mistake or discovery:** Supabase SQL Editor displays the result of the **last** statement (`COMMIT` → "Success. No rows returned.") and suppresses intermediate `NOTICE` / `CREATE TABLE` / `INSERT` status lines for transactions. They route to Postgres logs, not the Results panel.
- **Root cause:** SQL Editor display behavior; not a migration defect.
- **Prevention rule:** for any transaction-wrapped migration, do not interpret missing intermediate output as failure. The migration's internal invariants raise `ERROR` on failure — absence of `ERROR` plus a successful `COMMIT` headline confirms transaction success. Verify outcome via independent `SELECT`s on the database state.
- **Applies to:** every BEGIN/COMMIT-wrapped migration applied via Supabase SQL Editor. Category: Supabase environment traps; runbook traps.
- **Staleness risk:** until Supabase SQL Editor adds NOTICE display, or until the team uses a CLI-based apply path with verbose logging.
- **Action added:** runbook §4.2 to add a note: "If SQL Editor only shows 'Success. No rows returned.', that is the headline of `COMMIT` — verify via §4.3 SELECTs." Database PM reporting includes the headline-vs-Results-panel disambiguation.
- **Linked files:** `docs/v1.4.1_phase2_staging_apply_runbook.md` §4.2, `db/migrations/0005_v141_phase2_install_base_master_backfill_REVIEW_ONLY.sql`, `automation/memory/tracks/database-track.md`.

---

## fieldops-sql-rls-safety-agent

### L-SQL-001 — RLS recursion via same-table policy reads

- **Date:** Phase 1 ship (production discovery)
- **Commit / PR:** PR #24 (recursion fix `_other_active_admin_exists`)
- **Agent:** SQL/RLS safety
- **Event:** original `user_roles` admin-delete policy queried its own table to check "is there another active admin?" — Postgres flagged "infinite recursion detected in policy for relation user_roles".
- **Mistake or discovery:** any policy expression that reads its own gated table without a SECURITY DEFINER wrapper recurses.
- **Root cause:** intuitive SQL ("count other admins") triggers RLS evaluation on the same table during the policy check.
- **Prevention rule:** every policy expression that needs a same-table read uses a SECURITY DEFINER helper with `SET search_path = public`. The helper bypasses RLS for the lookup.
- **Applies to:** every new RLS policy, especially "last admin" / "single owner" / "active count" guards. Category: SQL/RLS traps; recurring errors.
- **Staleness risk:** invariant — Postgres engine behavior.
- **Action added:** `_other_active_admin_exists(uuid)` helper is the canonical pattern. SQL/RLS agent hard stop scans every new policy for this class.
- **Linked files:** `db/migrations/0003_*.sql`, `.claude/agents/fieldops-sql-rls-safety-agent.md`.

### L-SQL-002 — service_role does not bypass FK constraints

- **Date:** Phase 1 staging runbook draft
- **Commit / PR:** Phase 1 staging runbook revision
- **Agent:** SQL/RLS safety
- **Event:** original Phase 1 runbook used `gen_random_uuid()` for an `auth.uid()` test value; the FK to `auth.users(id)` rejected it.
- **Mistake or discovery:** service_role bypasses RLS but does NOT bypass FK constraints.
- **Root cause:** assumption that service_role bypasses everything.
- **Prevention rule:** test inserts that need a real `auth.uid()` use an existing real user UUID (or seed one in a transaction). Never `gen_random_uuid()` for FK-targeted ID columns.
- **Applies to:** every test step that inserts into a table with `user_id REFERENCES auth.users(id)` or similar. Category: SQL/RLS traps; runbook traps.
- **Staleness risk:** invariant.
- **Action added:** runbook-verifier hard stop scans for `gen_random_uuid()` near FK-bound columns.
- **Linked files:** `.claude/agents/fieldops-sql-rls-safety-agent.md`, `.claude/agents/fieldops-migration-runbook-verifier.md`.

### L-SQL-003 — Idempotency guards are mandatory on all DDL

- **Date:** ongoing (Phase 1 + Phase 2)
- **Commit / PR:** all migrations
- **Agent:** SQL/RLS safety
- **Event:** un-guarded DDL fails on second apply, breaking re-runs and recovery.
- **Mistake or discovery:** every DDL must guard with `IF [NOT] EXISTS` or a `DO $$ ... END $$` block.
- **Root cause:** convenience.
- **Prevention rule:** SQL/RLS agent rejects any migration whose DDL lacks idempotency guards. CI Tier 1 (planned) re-applies migration twice and asserts second is no-op.
- **Applies to:** every migration. Category: SQL/RLS traps.
- **Staleness risk:** invariant.
- **Action added:** specialist hard stop.
- **Linked files:** `.claude/agents/fieldops-sql-rls-safety-agent.md`, `docs/fieldops3i_task_routing_protocol.md` §4.1.

### L-SQL-004 — GRANT must align with RLS for `authenticated`

- **Date:** Phase 2 design
- **Commit / PR:** PR #26
- **Agent:** SQL/RLS safety
- **Event:** RLS policies cannot be evaluated if the table-level GRANT denies the operation. Missing GRANT silently rejects with `permission denied` instead of the expected RLS denial.
- **Mistake or discovery:** RLS without GRANT is a no-op; the user sees the wrong error.
- **Root cause:** GRANT and RLS are two separate layers commonly conflated.
- **Prevention rule:** for every new write policy, run `has_table_privilege('authenticated', '<table>', '<cmd>')` and assert true. SQL/RLS hard stop checks this on review.
- **Applies to:** every additive write policy. Category: SQL/RLS traps.
- **Staleness risk:** invariant.
- **Action added:** specialist hard stop.
- **Linked files:** `db/migrations/0004_*.sql`, `.claude/agents/fieldops-sql-rls-safety-agent.md`.

### L-SQL-005 — config_assets has no `modality` column; modality is runtime-derived from `model`

- **Date:** 2026-05-11
- **Commit / PR:** PR #27 / B6 Session X X1 setup at `cb6fa19`
- **Agent:** Data reconciliation + SQL/RLS safety
- **Event:** B6 Session X first attempt to insert `TEST-IB-AAA` into `public.config_assets` included a `modality` column, which failed with a column-does-not-exist error. The retry without the modality column succeeded.
- **Mistake or discovery:** `config_assets` schema does NOT have a `modality` column. Modality is derived at runtime in `index.html` via `getAssetModality(a)` from the asset's `model` field (e.g. `"Discovery VCT"` → `"PET-CT"`, `"Radiography"` → `"DR"`, default → `"MRI"`). This separation is intentional: keeping the DB schema lean and the modality classification logic in JS makes it easy to refine without schema migrations.
- **Root cause:** the impression that "asset has modality" comes from the visual IB table column, not the DB schema. The visual column is computed; the DB column does not exist.
- **Prevention rule:** when inserting into `config_assets` via SQL (test setup, backfill, future migration), use only the actual DB columns: `code, ast_id, name, tesla, model, town, state, channel, gradient, sw, compressor, coldhead, alias_of, status, de_installed_at, de_installed_by, note, created_at, created_by, updated_at, updated_by`. Modality is NEVER a column.
- **Applies to:** every direct SQL on `config_assets`. Category: SQL/RLS traps; recurring errors.
- **Staleness risk:** invariant unless a future migration adds the column (which would be a Phase 3+ design decision contradicting the current architecture).
- **Action added:** new memory entry; data-reconciliation agent should reference this when generating sample data or runbook insert examples.
- **Linked files:** `index.html` (`getAssetModality` definition); `db/migrations/` (no future migration should add this column without explicit design review).

---

## fieldops-migration-runbook-verifier

### L-RB-001 — Runbook code blocks must paste safely as SQL

- **Date:** 2026-05-09
- **Commit / PR:** Round-2 audit
- **Agent:** Runbook verifier
- **Event:** real risk that an operator copies a markdown runbook block into Supabase SQL Editor by accident, including markdown syntax.
- **Mistake or discovery:** runbook code blocks must be valid SQL when extracted, with no markdown leakage.
- **Root cause:** operator copy-paste workflow.
- **Prevention rule:** every apply-section code block uses ` ```sql ` fences. Multi-step blocks wrap in `BEGIN; ... COMMIT;` so partial paste fails fast. Inline narrative SQL (one-line examples) is forbidden in apply sections.
- **Applies to:** every runbook with mutable steps. Category: runbook traps; operator-confusion traps.
- **Staleness risk:** invariant.
- **Action added:** runbook verifier hard stop scans for non-SQL fenced blocks in apply sections.
- **Linked files:** `docs/v1.4.1_phase2_staging_apply_runbook.md`, `.claude/agents/fieldops-migration-runbook-verifier.md`.

### L-RB-002 — Privileged-state tests wrap in BEGIN/ROLLBACK

- **Date:** Phase 1 (caught during runbook review)
- **Commit / PR:** Phase 1 runbook fix
- **Agent:** Runbook verifier
- **Event:** a test query that demoted the last admin would lock out the operator if run as the default `postgres` SQL Editor session without a rollback wrapper.
- **Mistake or discovery:** RLS-bypass paths (run as `postgres`) are dangerous; tests must roll back.
- **Root cause:** test was written as a "see if this fails" probe, not a controlled experiment.
- **Prevention rule:** any test that mutates admin / role / lockout-relevant state is wrapped in `BEGIN; ... ROLLBACK;`. The runbook explicitly states the required session role and the rollback wrapper.
- **Applies to:** every privileged-state test. Category: runbook traps; SQL/RLS traps.
- **Staleness risk:** invariant.
- **Action added:** runbook verifier hard stop.
- **Linked files:** `.claude/agents/fieldops-migration-runbook-verifier.md`.

### L-RB-003 — Cleanup statements declare session role

- **Date:** Phase 1 (post-execution review)
- **Commit / PR:** Phase 1 runbook fix
- **Agent:** Runbook verifier
- **Event:** original cleanup didn't say "run as postgres" — operator could try to run as `authenticated` and fail.
- **Mistake or discovery:** cleanup privilege requirements are non-obvious.
- **Root cause:** runbook author assumed operator would intuit.
- **Prevention rule:** every cleanup statement declares the required session role explicitly.
- **Applies to:** every runbook cleanup section. Category: runbook traps.
- **Staleness risk:** invariant.
- **Action added:** runbook verifier hard stop.
- **Linked files:** `.claude/agents/fieldops-migration-runbook-verifier.md`.

---

## fieldops-data-reconciliation-agent

### L-REC-001 — Marker rows must equal pre-state missing set

- **Date:** Phase 2 design
- **Commit / PR:** PR #26
- **Agent:** Data reconciliation
- **Event:** 0005 backfills missing V2 codes into `config_assets` with a marker note.
- **Mistake or discovery:** if post-apply marker set ⊋ pre-state missing set, silent corruption occurred. If marker set ⊊ pre-state missing set, backfill is incomplete.
- **Root cause:** assumed equality without verification.
- **Prevention rule:** §4.3 verification query asserts `marker_codes == pre_missing_codes` (set equality, not subset).
- **Applies to:** every backfill with marker rows. Category: Supabase environment traps; recurring errors.
- **Staleness risk:** archive after Phase 2 production apply.
- **Action added:** runbook §4.3 query is the canonical check.
- **Linked files:** `db/migrations/0005_*.sql`, `docs/v1.4.1_phase2_staging_apply_runbook.md`.

### L-REC-002 — Ambiguous customer names ESCALATE; never auto-resolve

- **Date:** Phase 2 design
- **Commit / PR:** PR #26
- **Agent:** Data reconciliation
- **Event:** "Isha Diagnostics" vs "Isha Diagnostics Centre" — auto-merging risks corrupting lifecycle history.
- **Mistake or discovery:** fuzzy matching is unsafe for write paths.
- **Root cause:** human-entered free-text customer fields.
- **Prevention rule:** ambiguous matches ESCALATE to operator with a CSV review. Never auto-resolve.
- **Applies to:** every PM/CMC → lifecycle backfill, every fuzzy match. Category: Supabase environment traps.
- **Staleness risk:** until customer master is normalized.
- **Action added:** reconciliation agent hard stop.
- **Linked files:** `.claude/agents/fieldops-data-reconciliation-agent.md`.
