# FieldOps3i — Agent Registry

**Last updated:** 2026-06-08 (automation-memory-agent retired → `scripts/update-state.cjs`; 4 active, 20 archived)
**Report:** `node scripts/agent-report.cjs`
**Archived definitions:** `.claude/agents/archived/` — restore any by moving back to `.claude/agents/`

---

## Active agents (4)

| Agent | Tier | Track | Health | Last used | Total uses | Catch rate |
|---|---|---|---|---|---|---|
| `fieldops-code-reviewer` | 2 | Cross | ACTIVE | 2026-05-29 | 1 | — |
| `fieldops-sql-rls-safety-agent` | 2 | DB | HOT | 2026-05-29 | 3 | 33% |
| `fieldops-qa-test-automation-agent` | 2 | Runtime | HOT | 2026-05-29 | 7 | 14% |
| `fieldops-observability-agent` | 3 | Release | HOT | 2026-05-29 | 4 | 25% |

> **STATE.md updates are no longer an agent.** Run `node scripts/update-state.cjs`
> (deterministic git snapshot) after any deploy / branch sync. It rewrites only the
> mechanical sections; narrative edits stay manual.

---

## Archived agents (20)

Moved to `.claude/agents/archived/` — reason: 0 invocations, or superseded by a script.
Restore by moving the `.md` file back to `.claude/agents/` and updating this registry.

| Agent | Tier | Archived reason |
|---|---|---|
| `fieldops-automation-memory-agent` | 2 | Retired 2026-06-08 — STATE.md updates replaced by `scripts/update-state.cjs` (deterministic; no LLM needed). |
| `fieldops-delivery-orchestrator` | 0 | Never used. Phase 2 complexity no longer active. |
| `fieldops-database-pm` | 1 | Never used. PM tier bypassed in practice. |
| `fieldops-runtime-pm` | 1 | Never used. PM tier bypassed in practice. |
| `fieldops-release-pm` | 1 | Never used. PM tier bypassed in practice. |
| `fieldops-migration-runbook-verifier` | 2 | Never used. Phase 2 runbook complexity no longer active. |
| `fieldops-data-reconciliation-agent` | 2 | Never used. Data reconciliation done ad-hoc. |
| `fieldops-runtime-integration-agent` | 2 | Never used. Integration design done inline. |
| `fieldops-orchestrator` | 3 | Never used. Superseded by direct specialist invocation. |
| `fieldops-bug-agent` | 3 | Never used. Bug RCA done inline. |
| `fieldops-ui-agent` | 3 | Never used. UI work done inline. |
| `fieldops-supabase-agent` | 3 | Never used. Supabase work done inline. |
| `fieldops-test-agent` | 3 | Never used. Manual testing replaced by Playwright harness. |
| `fieldops-release-agent` | 3 | Never used. Release work done inline + observability agent. |
| `fieldops-product-design-lead` | 4 | Never used. Advisory only; no active design review cycle. |
| `fieldops-enterprise-ux-researcher` | 4 | Never used. |
| `fieldops-dashboard-usability-auditor` | 4 | Never used. |
| `fieldops-design-system-guardian` | 4 | Never used. |
| `fieldops-accessibility-reviewer` | 4 | Never used. |
| `fieldops-microinteraction-designer` | 4 | Never used. |

---

## Review checkpoints

Tracked decisions so unproven agents don't linger indefinitely.

| Agent | Decision (2026-06-08) | Re-evaluate when | Action if it fails |
|---|---|---|---|
| `fieldops-code-reviewer` | **KEEP + enforce.** Wired into the commit-guard pre-commit hook (`scripts/githooks/pre-commit`) so it fires on every `index.html` / migration commit. Still only 1 lifetime invocation (an `N/A` setup entry — never run on a real diff). | After **5 real-diff reviews** (verdict ≠ `N/A`). `node scripts/agent-report.cjs` auto-flags it (`isReviewer` + ≥5 uses + 0% catch → **EDIT**). | Sharpen its checklist; if still 0% catch after the edit, archive it. |

---

## Restore protocol

To restore an archived agent:
1. Move `archived/<name>.md` → `.claude/agents/<name>.md`
2. Update this file: move the row back to Active, set health/last-used
3. Add it to the `DEFINED_AGENTS` map in `scripts/agent-report.cjs` (move its row from `ARCHIVED_AGENTS`)
4. Update `CLAUDE.md §7` active roster table
