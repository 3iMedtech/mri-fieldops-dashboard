# FieldOps3i — Agent Registry

**Auto-updated by:** `scripts/agent-report.cjs` (run after every agent invocation log)
**Last regenerated:** 2026-05-29
**Source of truth for:** which agents exist, their tier, their health status.

This file is the canonical roster. If an agent definition exists in `.claude/agents/` but is not listed here, add it. If it is listed here but the `.md` file was deleted, mark it RETIRED.

---

## How to read this table

| Column | Meaning |
|---|---|
| Agent | Slug name matching `.claude/agents/<name>.md` |
| Tier | 0=Orchestrator, 1=PM, 2=Specialist, 3=Legacy/Module, 4=Design-Advisory |
| Track | DB / Runtime / Release / Cross / Design |
| Status | ACTIVE / DORMANT / RETIRED |
| Last used | Date of last recorded invocation (from `invocations.jsonl`) |
| Total uses | Lifetime invocation count |
| Catch rate | STOP+ESCALATE / total invocations (only meaningful for review agents) |
| Health | HOT / ACTIVE / STALE / DEAD — computed by `agent-report.cjs` |

**Health thresholds (computed):**
- `HOT` — used in the last 14 days AND ≥ 3 invocations total
- `ACTIVE` — used in the last 30 days
- `STALE` — defined but last used > 30 days ago, or < 3 lifetime uses
- `DEAD` — never used (0 invocations in the log)

---

## Tier 0 — Delivery Orchestrator

| Agent | Track | Status | Last used | Total uses | Catch rate | Health |
|---|---|---|---|---|---|---|
| fieldops-delivery-orchestrator | Cross | DORMANT | — | 0 | — | DEAD |

## Tier 1 — Project Managers

| Agent | Track | Status | Last used | Total uses | Catch rate | Health |
|---|---|---|---|---|---|---|
| fieldops-database-pm | DB | DORMANT | — | 0 | — | DEAD |
| fieldops-runtime-pm | Runtime | DORMANT | — | 0 | — | DEAD |
| fieldops-release-pm | Release | DORMANT | — | 0 | — | DEAD |

## Tier 2 — Specialists

| Agent | Track | Status | Last used | Total uses | Catch rate | Health |
|---|---|---|---|---|---|---|
| fieldops-code-reviewer | Cross | ACTIVE | 2026-05-29 | 1 | 0% | STALE |
| fieldops-sql-rls-safety-agent | DB | ACTIVE | 2026-05-29 | 3 | 67% | STALE |
| fieldops-migration-runbook-verifier | DB | DORMANT | — | 0 | — | DEAD |
| fieldops-data-reconciliation-agent | DB | DORMANT | — | 0 | — | DEAD |
| fieldops-runtime-integration-agent | Runtime | DORMANT | — | 0 | — | DEAD |
| fieldops-qa-test-automation-agent | Runtime | ACTIVE | 2026-05-29 | 12 | — | HOT |
| fieldops-automation-memory-agent | Cross | ACTIVE | 2026-05-29 | 8 | — | HOT |

## Tier 3 — Legacy / Module-level

| Agent | Track | Status | Last used | Total uses | Catch rate | Health |
|---|---|---|---|---|---|---|
| fieldops-orchestrator | Cross | DORMANT | 2026-05-09 | 2 | — | STALE |
| fieldops-observability-agent | Release | ACTIVE | 2026-05-29 | 6 | — | HOT |
| fieldops-bug-agent | Cross | DORMANT | — | 0 | — | DEAD |
| fieldops-ui-agent | Runtime | DORMANT | — | 0 | — | DEAD |
| fieldops-supabase-agent | DB | DORMANT | — | 0 | — | DEAD |
| fieldops-test-agent | Release | DORMANT | — | 0 | — | DEAD |
| fieldops-release-agent | Release | DORMANT | — | 0 | — | DEAD |

## Tier 4 — Design Advisory (all dormant)

| Agent | Track | Status | Last used | Total uses | Health |
|---|---|---|---|---|---|
| fieldops-product-design-lead | Design | DORMANT | — | 0 | DEAD |
| fieldops-enterprise-ux-researcher | Design | DORMANT | — | 0 | DEAD |
| fieldops-dashboard-usability-auditor | Design | DORMANT | — | 0 | DEAD |
| fieldops-design-system-guardian | Design | DORMANT | — | 0 | DEAD |
| fieldops-accessibility-reviewer | Design | DORMANT | — | 0 | DEAD |
| fieldops-microinteraction-designer | Design | DORMANT | — | 0 | DEAD |

---

## Summary counts

| Status | Count |
|---|---|
| ACTIVE / HOT | 7 |
| STALE (defined, rarely used) | 2 |
| DEAD (defined, never used) | 14 |
| RETIRED | 0 |
| **Total defined** | **23** |

*Run `node scripts/agent-report.cjs` to regenerate this table from live log data.*
