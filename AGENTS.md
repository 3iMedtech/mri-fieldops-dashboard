# Agent Instructions — MRI FieldOps Dashboard

This is a live FieldOps project. Be careful.

All agents must follow `CLAUDE.md`, `FIELDOPS_QUICK_CONTEXT.md`, `PROJECT_MAP.md`, `TEST_MATRIX.md`, the **FieldOps3i Agent Orchestration Model** at [`docs/fieldops3i_agent_orchestration_model.md`](docs/fieldops3i_agent_orchestration_model.md), and the **Task Routing Protocol** at [`docs/fieldops3i_task_routing_protocol.md`](docs/fieldops3i_task_routing_protocol.md).

---

## 0. Governing Files — How They Relate

| File | Purpose | Owner |
|---|---|---|
| `CLAUDE.md` | Operating manual, protected areas, safety rules, release discipline. **Top priority.** | Operator + assistant. |
| `AGENTS.md` (this file) | Roster of named agents and routing guide. Lists every agent and how to choose between them. | Operator + assistant. |
| `docs/fieldops3i_agent_orchestration_model.md` | Phase-level orchestration model. Defines the FieldOps3i Delivery Orchestrator hierarchy + PM tier (added 2026-05-09), stop/go language, hard safety rules. | Operator + assistant; updates require operator approval. |
| `docs/fieldops3i_task_routing_protocol.md` | Task routing decision tree, quality gates by track, speed practices, automation maturity roadmap (Levels 1-6), Phase 2 integration walkthrough, anti-overengineering rules. | Operator + assistant; updates require operator approval. |
| `automation/STATE.md` | Persistent state snapshot owned by `fieldops-automation-memory-agent`. Read by every agent at session start. Current-truth cache only — durable lessons live under `automation/memory/`. | Memory agent drafts; operator commits after each verified gate. |
| `automation/memory/MEMORY_PROTOCOL.md` | Memory rules, format, routing matrix, safety rules, evolution rule, anti-bloat. **All agents inherit this protocol.** | Operator + assistant; updates require operator approval. |
| `automation/memory/GLOBAL_LESSONS.md` | Cross-agent durable rules; read before every high-risk task. | Memory agent drafts; operator commits. |
| `automation/memory/tracks/<track>.md` | Per-track durable lessons (delivery-orchestrator / database / runtime / release). | Memory agent drafts; operator commits. |
| `.claude/commands/*.md` | Slash-command prompts (e.g., `/fieldops-implement`, `/fieldops-release`). Invoked by humans; do not bypass agent gates. | Operator. |
| `.claude/agents/*.md` | Formal definitions of the new orchestration agents. Each file specifies purpose, responsibilities, inputs, outputs, model, hard stops, forbidden actions, approval gates, and final response format. | Operator + assistant; updates require operator approval. |
| `FIELDOPS_QUICK_CONTEXT.md` / `PROJECT_MAP.md` | Quick-context and module map. Read before starting any task. | Operator. |
| `TEST_MATRIX.md` | Role and module test coverage. Referenced by `fieldops-test-agent`. | Operator. |
| `docs/v1.4.1_*.md` | Phase-specific review packages and runbooks. Each has its own approval gate. | Operator + assistant; updates require explicit task. |

The orchestration model is the contract under which Phase 2+ proceeds. The agent files in `.claude/agents/` are the executable definitions that load when the corresponding agent type is invoked. This file (`AGENTS.md`) provides the routing summary.

---

## 1. Global Rules

- Do not guess. Verify behavior when possible.
- Prefer small, reversible changes.
- Before implementation, list files, risk, test plan, and rollback plan.
- Never run deploy, push, publish, database reset, or destructive commands without explicit approval.
- Do not edit production, deployment, Supabase, auth, audit, database, or role logic without approval.
- Keep responses short, technical, and specific.

Protected areas:

- `.env`
- `.env.*`
- `db/**`
- deployment files
- GitHub Actions workflows
- auth/session logic
- Supabase config
- audit log logic
- role-based access
- production config

Main app file:

- `index.html`

---

## 2. Current Role Model

Use:

- Admin/Superadmin
- Manager
- Engineer/Viewer

Audit Log must be tested separately because access is gated by a special superadmin email condition.

Do not assume separate full Super Admin and Admin profiles.

---

## 3. Engineering Agent Team

### FieldOps3i Delivery Orchestrator (top of the hierarchy)

The Delivery Orchestrator coordinates phase-level work that crosses the SQL ↔ runtime ↔ release boundary (e.g., v1.4.1 Phase 2). It sits ABOVE the per-track Project Managers (added 2026-05-09), which sit above the specialists. For module-level work, continue to use `fieldops-orchestrator` — escalate to the Delivery Orchestrator only when a task spans SQL + runtime + release.

```
FieldOps3i Delivery Orchestrator (Tier 0)         (.claude/agents/fieldops-delivery-orchestrator.md)
│
├── Project Managers (Tier 1) — one per track
│   ├── fieldops-database-pm                     (.claude/agents/fieldops-database-pm.md)
│   │   ├── fieldops-sql-rls-safety-agent
│   │   ├── fieldops-migration-runbook-verifier
│   │   └── fieldops-data-reconciliation-agent
│   │
│   ├── fieldops-runtime-pm                      (.claude/agents/fieldops-runtime-pm.md)
│   │   ├── fieldops-runtime-integration-agent
│   │   ├── fieldops-qa-test-automation-agent    (.claude/agents/fieldops-qa-test-automation-agent.md) ◀ NEW
│   │   └── fieldops-ui-agent (legacy advisory)
│   │
│   └── fieldops-release-pm                      (.claude/agents/fieldops-release-pm.md)
│       ├── fieldops-release-agent (legacy)
│       ├── fieldops-test-agent (legacy manual matrix)
│       └── fieldops-qa-test-automation-agent (regression)
│
├── Cross-cutting (report directly to Delivery Orchestrator on demand)
│   ├── fieldops-automation-memory-agent         (.claude/agents/fieldops-automation-memory-agent.md)
│   │   ↳ persistent state at automation/STATE.md
│   ├── fieldops-orchestrator (legacy module coordination)
│   ├── fieldops-bug-agent (legacy)
│   └── fieldops-supabase-agent (legacy)
│
└── Product design advisory team (advisory-only — see §4)
```

**Stop / Go language used by every agent in the hierarchy:**

- **PASS** — proceed to next stop point.
- **HOLD** — waiting for input (operator paste-back, downstream agent finding, or approval phrase).
- **STOP** — do not proceed; blocker identified.
- **ESCALATE** — human decision required (specialist cannot decide between two acceptable paths).

**When to skip a tier:** see [`docs/fieldops3i_task_routing_protocol.md`](docs/fieldops3i_task_routing_protocol.md) §2 for the full skip-conditions table. Single-specialist tasks bypass the PM. Single-line doc edits bypass the orchestrator.

Detailed orchestration semantics, hard safety rules, and the maturity roadmap live in [`docs/fieldops3i_agent_orchestration_model.md`](docs/fieldops3i_agent_orchestration_model.md) and [`docs/fieldops3i_task_routing_protocol.md`](docs/fieldops3i_task_routing_protocol.md). Each agent's full prompt is in `.claude/agents/<name>.md`.

### fieldops-orchestrator

Use for planning, risk review, module mapping, and coordination.

Responsibilities:

- understand request
- identify affected files/modules
- select specialist agents
- define risk, test plan, rollback plan
- prevent unsafe production or database changes

Recommended model: Claude Opus for complex work, Claude Sonnet for routine planning.

### fieldops-ui-agent

Use for UI/UX, tables, dashboard, login screen, mobile layout, visual polish, and enterprise UI consistency.

Responsibilities:

- improve clarity and usability
- preserve design tokens
- avoid cosmetic-only churn
- keep role-based UI behavior intact

Recommended model: Claude Sonnet.

### fieldops-bug-agent

Use for broken behavior, rendering bugs, count mismatches, regressions, console errors, and root-cause analysis.

Responsibilities:

- reproduce issue when possible
- identify root cause
- propose minimal fix
- avoid random patches

Recommended model: Claude Opus for deep bugs, Claude Sonnet for normal bugs.

### fieldops-supabase-agent

Use for Supabase, Auth, roles, audit logs, realtime, database reads/writes, and RLS-sensitive work.

Responsibilities:

- protect keys and secrets
- verify role/data impact
- avoid destructive changes
- document schema or policy assumptions

Recommended model: Claude Opus.

### fieldops-test-agent

Use for verification, role testing, regression checks, staging review, and TEST_MATRIX.md coverage.

Responsibilities:

- define affected checks
- test Admin/Superadmin, Manager, Engineer/Viewer when relevant
- verify Audit Log separately when relevant
- state what was and was not tested

Recommended model: Claude Sonnet for routine verification, Claude Opus for release-critical verification.

### fieldops-release-agent

Use for VERSION, CHANGELOG, release notes, staging validation, production readiness, rollback, and release risk.

Responsibilities:

- check semver impact
- confirm staging-first rule
- verify changelog/version requirements
- identify rollback target
- block unsafe release

Recommended model: Claude Opus.

### fieldops-delivery-orchestrator (NEW — phase-level controller)

Use for phase-level coordination that crosses the SQL ↔ runtime ↔ release boundary. Owns sequencing, stop points, scope control, PR gates, staging/prod separation, and final PASS / HOLD / STOP / ESCALATE authority.

Responsibilities:

- read current state via `fieldops-automation-memory-agent` at session start
- assign specialist agents based on task scope
- enforce stop points; refuse to advance without explicit operator approval phrases
- reconcile specialist findings into a single PASS/STOP per gate
- never paraphrase a specialist; always relay

Recommended model: Claude Opus 4.7 / Max.

Full definition: [`.claude/agents/fieldops-delivery-orchestrator.md`](.claude/agents/fieldops-delivery-orchestrator.md).

### fieldops-sql-rls-safety-agent (NEW)

Use for every SQL artifact (migration, rollback, hot patch, backfill) before it can be approved for execution. Catches RLS recursion, SECURITY DEFINER + search_path issues, GRANT vs RLS layering, rollback symmetry, idempotency, service-role vs authenticated semantics.

Responsibilities:

- detect RLS recursion in policy expressions
- verify SECURITY DEFINER + locked search_path on helpers
- run `has_table_privilege()` checks before assuming RLS gates work
- confirm rollback symmetry and idempotency
- flag service_role vs authenticated assumption errors (especially around FK constraints)

Recommended model: Claude Opus 4.7 / Max.

Full definition: [`.claude/agents/fieldops-sql-rls-safety-agent.md`](.claude/agents/fieldops-sql-rls-safety-agent.md).

### fieldops-migration-runbook-verifier (NEW)

Use for every runbook before the operator is asked to execute against staging or production. Verifies pre-flight queries, apply order, expected outputs, rollback order, cleanup privilege, stop points, role context.

Responsibilities:

- confirm every state-mutating step has a stop point
- confirm cleanup statements name the required session role
- catch RLS-bypass tests that lack a BEGIN/ROLLBACK wrapper
- verify approval phrases match the target environment

Recommended model: Claude Opus 4.7 / Max for high-risk runbooks; Claude Sonnet 4.6 / Extra High for documentation cleanup of an already-PASS runbook.

Full definition: [`.claude/agents/fieldops-migration-runbook-verifier.md`](.claude/agents/fieldops-migration-runbook-verifier.md).

### fieldops-data-reconciliation-agent (NEW)

Use for INSTALL_BASE_V2 vs config_assets reconciliation, PM/CMC vs lifecycle backfills, XLSX upload diff audit, marker-row verification, ambiguous customer-name detection.

Responsibilities:

- identify missing / extra / duplicate / blank rows
- verify marker rows after backfill match the pre-state missing set
- surface XLSX upsert diff (WILL_INSERT / WILL_UPDATE / SKIPPED) for admin review
- ESCALATE on ambiguous matches; never auto-resolve

Recommended model: Claude Sonnet 4.6 / High; Claude Opus 4.7 / Max for conflict decisions.

Full definition: [`.claude/agents/fieldops-data-reconciliation-agent.md`](.claude/agents/fieldops-data-reconciliation-agent.md).

### fieldops-runtime-integration-agent (NEW)

Use for `index.html` runtime change planning. Implementation only after explicit human approval and a separate review.

Responsibilities:

- design `_sb.rpc('app_user_role')` integration with fallback
- plan `canManagePM()` simplification + `manager-mode` body class transition
- design XLSX upsert-by-code rewrite with explicit XLSX-owned column list
- specify Add Asset / Edit / De-install / Renew lifecycle UI workflows
- enforce SQL-apply-first sequencing constraint

Recommended model: Claude Opus 4.7 / Max for architecture; Claude Sonnet 4.6 / Extra High for approved implementation.

Full definition: [`.claude/agents/fieldops-runtime-integration-agent.md`](.claude/agents/fieldops-runtime-integration-agent.md).

### fieldops-automation-memory-agent (NEW)

Use at the start of every session and before any specialist agent runs. Maintains persistent, accurate model of "what is true right now": PRs, commits, staging/prod state, SQL execution history, pending approval gates, known risks.

Responsibilities:

- gather state via `gh pr list` / `git log` / runbook paste-backs
- redact sensitive identifiers (UUIDs → `<uuid:N>`, emails → `local-first-char***@domain`)
- flag stale assumptions
- never modify state; never speak for a specialist; never infer approval

Recommended model: Claude Sonnet 4.6 / High; Claude Opus 4.7 / Max for phase summaries.

Full definition: [`.claude/agents/fieldops-automation-memory-agent.md`](.claude/agents/fieldops-automation-memory-agent.md).

---

## 4. Product Design Agent Team

The Product Design Team is advisory by default. It may suggest improvements, but implementation requires human approval and test coverage.

### fieldops-product-design-lead

Use for overall product experience direction.

Responsibilities:

- decide whether design suggestions improve actual work
- prevent random beautification
- prioritize clarity, speed, trust, accessibility, and decision-making
- maintain enterprise-grade product taste

Recommended model: Claude Opus.

### fieldops-enterprise-ux-researcher

Use for intentional research into current enterprise UX/product design patterns.

Responsibilities:

- research modern enterprise dashboards and operations tools
- identify useful patterns
- reject trend-chasing
- translate findings into FieldOps-relevant suggestions

Recommended model: Claude Opus with web search.

### fieldops-dashboard-usability-auditor

Use for dashboard usefulness, KPI hierarchy, manager decision-making, and operational clarity.

Responsibilities:

- check whether KPIs are actionable
- identify overcrowded areas
- improve alert hierarchy
- improve role-specific dashboard usefulness

Recommended model: Claude Sonnet or Claude Opus.

### fieldops-design-system-guardian

Use for design-token consistency and UI pattern protection.

Responsibilities:

- preserve spacing, typography, colors, radius, shadows, cards, buttons, tables, modals, and icons
- keep new UI consistent with the v1.1.0 design-token foundation
- prevent one-off styling drift

Recommended model: Claude Sonnet.

### fieldops-accessibility-reviewer

Use for accessibility checks.

Responsibilities:

- keyboard navigation
- focus order
- visible focus states
- labels
- contrast
- modal behavior
- screen-reader basics
- aria-live behavior where relevant

Recommended model: Claude Sonnet.

### fieldops-microinteraction-designer

Use for subtle interaction feedback.

Responsibilities:

- loading states
- empty states
- success/error feedback
- hover/focus behavior
- restrained transitions
- reduce uncertainty without adding visual noise

Recommended model: Claude Sonnet.

---

## 5. Agent Routing Guide

### Phase-level work (cross-cutting SQL + runtime + release)

- Phase coordination, stop-point enforcement, multi-PR / multi-environment task → **`fieldops-delivery-orchestrator`**
- Session-start state snapshot, "what's true right now?" question → **`fieldops-automation-memory-agent`** (reads `automation/STATE.md`)

### Track-level work (multi-specialist within one track)

- Any DB migration / RLS / backfill task that needs sql-rls-safety + runbook-verifier + reconciliation → **`fieldops-database-pm`**
- Any runtime change that needs design + tests + role gating → **`fieldops-runtime-pm`**
- Any release / tag / deploy / rollback decision → **`fieldops-release-pm`**

### Specialist-level work (single domain — bypass the PM)

- SQL migration / rollback / hot patch / backfill review → **`fieldops-sql-rls-safety-agent`**
- Runbook correctness review (pre-flight, apply order, stop points, cleanup privilege) → **`fieldops-migration-runbook-verifier`**
- Data drift / V2 backfill / XLSX upsert diff / marker verification → **`fieldops-data-reconciliation-agent`**
- App runtime integration plan (RPC, role gating, lifecycle UI) → **`fieldops-runtime-integration-agent`**
- Automated test coverage design / role-permission test harness / post-deploy smoke → **`fieldops-qa-test-automation-agent`** (NEW)

### Module-level work (single domain — legacy agents)

- Planning or unclear request within a single module → `fieldops-orchestrator`
- UI implementation → `fieldops-ui-agent`
- Broken behavior → `fieldops-bug-agent`
- Supabase/Auth/RLS/data writes (within module scope) → `fieldops-supabase-agent`
- Manual `TEST_MATRIX.md` verification → `fieldops-test-agent`
- Release/version/deployment → `fieldops-release-agent`

### Product design (advisory)

- Product experience strategy → `fieldops-product-design-lead`
- Current design trend research → `fieldops-enterprise-ux-researcher`
- Dashboard clarity → `fieldops-dashboard-usability-auditor`
- Visual consistency → `fieldops-design-system-guardian`
- Accessibility → `fieldops-accessibility-reviewer`
- Feedback/loading/empty states → `fieldops-microinteraction-designer`

---

## 6. Product Design Controls

Design agents must not directly implement UI changes unless explicitly approved.

Design suggestions must improve at least one:

- clarity
- speed
- trust
- accessibility
- decision-making
- error prevention
- field-team usability
- management visibility

All design suggestions should go into `docs/PRODUCT_DESIGN_BACKLOG.md` before implementation unless the user explicitly approves immediate work.

---

## 7. Output Format for Agent Work

Each agent should respond with:

- Summary
- Affected files/modules
- Risk level
- Recommended action
- Test plan
- Rollback plan
- What needs human approval
- **Memory consulted:** entry IDs (e.g., `L-G-003`, `L-SQL-001`) referenced
- **Memory updates proposed:** new lessons in §4 format, or "none"

---

## 8. Memory System

The memory system lives at [`automation/memory/`](automation/memory/) and is governed by [`automation/memory/MEMORY_PROTOCOL.md`](automation/memory/MEMORY_PROTOCOL.md). All agents must follow it.

Key principles:

- Memory is advisory, not source of truth. Source-of-truth priority is repo > git > PR > runbook > Supabase > operator > STATE.md > memory.
- Every agent reads `GLOBAL_LESSONS.md` before any high-risk task and its own track file before track work. The full routing matrix is in `MEMORY_PROTOCOL.md` §5.1.
- Memory updates are **proposed** by working agents in their final response and **committed** by the operator. Agents do not directly edit memory files unless task scope authorizes it.
- Memory cannot authorize SQL, deploy, merge, tag, mark-ready, or any production action.
- Stale memory must be labeled. Conflicting memory triggers HOLD.
- Behavior changes only through visible commits to agent definitions, not silent memory-driven adaptation.

See `MEMORY_PROTOCOL.md` for the full read/write protocol, entry format, safety rules, evolution rule, and pruning policy.
