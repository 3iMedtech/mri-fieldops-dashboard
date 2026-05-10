# Memory — Runtime Track

**Read by:** `fieldops-runtime-pm`, `fieldops-runtime-integration-agent`, `fieldops-qa-test-automation-agent`, `fieldops-ui-agent` (legacy advisory).
**Format:** see [`../MEMORY_PROTOCOL.md`](../MEMORY_PROTOCOL.md) §4.
**Cap:** ~30 entries.

---

## fieldops-runtime-pm

### L-RTPM-001 — SQL apply precedes runtime deploy on the same env

- **Date:** Phase 2 design
- **Commit / PR:** PR #26
- **Agent:** Runtime PM
- **Event:** Phase 2 runtime depends on `app_can_write()` policies (0004) and the V2 backfill (0005).
- **Mistake or discovery:** deploying runtime first surfaces RLS rejections in the live app.
- **Root cause:** track-independent thinking.
- **Prevention rule:** Runtime PM HOLDs deploy until Database PM PASS for the same environment is recorded in STATE.md.
- **Applies to:** every Phase 2+ change that depends on new policies/helpers. Category: runtime/UI traps; recurring errors.
- **Staleness risk:** until Phase 2 ships fully to production.
- **Action added:** Runtime PM hard stop checks DB PM verdict on target env.
- **Linked files:** `.claude/agents/fieldops-runtime-pm.md`, `docs/fieldops3i_task_routing_protocol.md` §3.4.

---

## fieldops-runtime-integration-agent

### L-RTI-001 — Manager UX comes from `_userRole`, not email allowlist

- **Date:** Phase 2 design
- **Commit / PR:** PR #26
- **Agent:** Runtime integration
- **Event:** legacy `canManagePM()` had an email allowlist branch. Phase 2 removes it.
- **Mistake or discovery:** client-side role checks must use the DB-resolved `_userRole` (via `_sb.rpc('app_user_role')`), not hardcoded emails.
- **Root cause:** historical bootstrap convenience before `user_roles` existed.
- **Prevention rule:** every `canManagePM()` call site reads `_userRole`. No email comparisons in role checks.
- **Applies to:** `index.html` role gating; new write buttons; `manager-mode` body class. Category: runtime/UI traps.
- **Staleness risk:** until Phase 2 runtime ships.
- **Action added:** runtime-integration design hard stop. QA Tier 4 (planned) tests every role × write-path combination.
- **Linked files:** `index.html` (`canManagePM`, `_userRole` references), `.claude/agents/fieldops-runtime-integration-agent.md`.

### L-RTI-002 — Auth fallback is mandatory; default to viewer, never admin

- **Date:** Phase 2 design
- **Commit / PR:** PR #26
- **Agent:** Runtime integration
- **Event:** `_sb.rpc('app_user_role')` may fail (network, missing seed, RPC error).
- **Mistake or discovery:** without a fallback, the app would either crash or grant admin by accident.
- **Root cause:** RPC integration designs commonly omit failure paths.
- **Prevention rule:** RPC failure → JWT-claim fallback → `'viewer'` default. Never default to `'admin'` or `'manager'`.
- **Applies to:** every RPC-resolved role check. Category: runtime/UI traps; SQL/RLS traps.
- **Staleness risk:** until Phase 2 runtime ships.
- **Action added:** runtime-integration hard stop.
- **Linked files:** `.claude/agents/fieldops-runtime-integration-agent.md`.

### L-RTI-003 — XLSX upsert excludes lifecycle fields

- **Date:** Phase 2 design
- **Commit / PR:** PR #26
- **Agent:** Runtime integration
- **Event:** XLSX upsert-by-code rewrite must NOT overwrite Manager-set `status` / `de_installed_at`.
- **Mistake or discovery:** naive upsert overwrites every column from the XLSX, destroying lifecycle state.
- **Root cause:** PostgREST `upsert(rows)` defaults to writing all columns.
- **Prevention rule:** XLSX-owned column list is explicit. Lifecycle fields (`status`, `de_installed_at`, `lifecycle_event_id`, etc.) are excluded from the payload.
- **Applies to:** every XLSX upload path. Category: runtime/UI traps; Supabase environment traps.
- **Staleness risk:** invariant after Phase 2.
- **Action added:** runtime-integration hard stop. QA Tier 4 (planned) test asserts lifecycle fields unchanged after XLSX re-upload.
- **Linked files:** `index.html` (XLSX upload section), `.claude/agents/fieldops-runtime-integration-agent.md`.

### L-RTI-004 — De-install requires type-asset-code confirmation

- **Date:** Phase 2 design (product decision #7)
- **Commit / PR:** PR #26
- **Agent:** Runtime integration
- **Event:** de-install is destructive UX (asset disappears from active list).
- **Mistake or discovery:** a single click without confirmation risks accidental de-install.
- **Root cause:** original design used a plain confirm() dialog.
- **Prevention rule:** de-install modal requires the operator to type the asset code literally. Submit button is disabled until typed input matches.
- **Applies to:** de-install workflow. Category: runtime/UI traps; operator-confusion traps.
- **Staleness risk:** until de-install workflow ships.
- **Action added:** runtime-integration hard stop.
- **Linked files:** `.claude/agents/fieldops-runtime-integration-agent.md`.

---

## fieldops-qa-test-automation-agent

### L-QA-001 — Coverage gaps must be surfaced before PM PASS

- **Date:** Round-2 audit
- **Commit / PR:** `e0da6a2`
- **Agent:** QA test automation
- **Event:** Tier 1-5 are PLANNED; Tier 6 (manual matrix) is the only operational layer.
- **Mistake or discovery:** without explicit coverage-gap reporting, PMs may PASS while assuming coverage they don't have.
- **Root cause:** absence-of-evidence feels like evidence-of-absence.
- **Prevention rule:** every QA report explicitly lists Tier 1-5 status (COVERED / PLANNED / GAP). Runtime PM and Release PM may not PASS without acknowledging the gaps.
- **Applies to:** every release decision until Tier 1-5 land. Category: recurring errors; release/deploy traps.
- **Staleness risk:** retire each tier as it lands in CI.
- **Action added:** QA reporting format requires the tier matrix.
- **Linked files:** `.claude/agents/fieldops-qa-test-automation-agent.md`, `docs/fieldops3i_task_routing_protocol.md` §4.5.

### L-QA-002 — Regression tests land in the same PR as the fix

- **Date:** memory system landing
- **Commit / PR:** N/A (forward rule)
- **Agent:** QA test automation
- **Event:** test-after-the-fact rarely happens in this project.
- **Mistake or discovery:** without CI enforcement, the bug class can recur.
- **Root cause:** no automated harness yet.
- **Prevention rule:** every fix PR includes the test that would have caught the bug. If test infrastructure for that tier doesn't exist yet, the PR notes the planned test and the tier needed.
- **Applies to:** every bug-fix PR. Category: recurring errors.
- **Staleness risk:** invariant.
- **Action added:** Release PM hard stop checks for matching test (or a planned-test note for non-existent tiers).
- **Linked files:** `.claude/agents/fieldops-qa-test-automation-agent.md`.
