# FieldOps3i — Agent Orchestration Model

**Status:** Documentation-only. No SQL, no app runtime, no production action implied by this document.
**Authored on branch:** `feat/v1.4.1-phase2-review`
**Audience:** human operator + Claude Code agents working on FieldOps3i.

---

## 1. Executive Summary

FieldOps3i is a live MRI field-service operations dashboard for 3i MEDTECH. It runs against a real Supabase database and is used in production by Admin, Manager, and Engineer/Viewer roles. The codebase is intentionally a single `index.html` with all HTML/CSS/JS inline; the database layer (RLS, helpers, lifecycle tables) is the source of truth for permissions and data shape.

Phase 1 of v1.4.1 (DB schema + helpers + RLS + `user_roles` seed) shipped successfully on staging and production. PR #24 is merged. PR #25 (production runbook) is review-only. PR #26 (Phase 2 review package) is open as DRAFT.

**Phase 2 is materially riskier than Phase 1 because it crosses the SQL/runtime boundary**: it adds DB write policies, rewrites the XLSX upload, integrates `_sb.rpc('app_user_role')` into `index.html`, and ships Add Asset / Edit / De-install / Renew lifecycle UI. A single missed gate would compromise either the audit trail, the last-admin guard, or production data integrity.

This document formalizes the orchestration layer that governs Phase 2 and beyond. The goal is **Tesla-level coding automation discipline**: every action that mutates DB, runtime, or release state passes through a named agent with defined inputs/outputs, an explicit human approval gate, and a hard stop list. No specialist review is ever claimed unless it actually happened.

The model is documentation + agent definition only. It does not change runtime behavior, schema, or release state.

---

## 2. Current Project Stage

| Stream | Status |
|---|---|
| Phase 1 schema (`user_roles`, `asset_lifecycle`, `asset_lifecycle_history`, helpers) | ✅ Applied to staging AND production |
| Phase 1 RLS policies (11 `v141_*` on the 3 new tables) | ✅ Applied to both environments |
| Phase 1 `user_roles` seed (admin / manager / viewer) | ✅ Applied to both environments |
| Recursion fix (`_other_active_admin_exists`) | ✅ Baked into 0003 on `main`; applied to both environments |
| PR [#24](https://github.com/3iMedtech/issues) — Phase 1 review package | MERGED to `main` (`8c54334`) |
| PR [#25](https://github.com/3iMedtech/issues) — Phase 1 production runbook | OPEN, **DRAFT** (review-only documentation) |
| PR [#26](https://github.com/3iMedtech/issues) — Phase 2 review package | OPEN, **DRAFT**, latest commit `9f24b70` (review fixes applied) |
| Phase 2 staging SQL apply | NOT STARTED |
| Phase 2 runtime implementation (`index.html` patches) | NOT STARTED |
| Production runtime version | v1.4.0.1 (no Phase 2 deploy) |
| Production Supabase | Phase 1 applied; Phase 2 not touched |

**No further action is approved on Phase 2 SQL, runtime, or production until the orchestration model in this document is accepted and PR #26 has been re-reviewed against the agent-defined gates below.**

---

## 3. Existing Agent / Command Structure

### 3.1 Engineering agents (from `AGENTS.md` §3)

- `fieldops-orchestrator` — planning, scope, risk, module mapping
- `fieldops-ui-agent` — UI/UX, dashboard polish, role-aware visual behavior
- `fieldops-bug-agent` — root-cause analysis, regressions, count mismatches
- `fieldops-supabase-agent` — Supabase reads/writes, RLS-sensitive work, role/data impact
- `fieldops-test-agent` — verification, role testing, regression review, `TEST_MATRIX.md`
- `fieldops-release-agent` — VERSION / CHANGELOG / staging-first / rollback / release risk

### 3.2 Product design advisory agents (from `AGENTS.md` §4)

- `fieldops-product-design-lead`
- `fieldops-enterprise-ux-researcher`
- `fieldops-dashboard-usability-auditor`
- `fieldops-design-system-guardian`
- `fieldops-accessibility-reviewer`
- `fieldops-microinteraction-designer`

These remain unchanged. They are advisory by default and require human approval before any UI implementation.

### 3.3 Slash commands (`.claude/commands/`)

- `fieldops-agent-team.md` — runs orchestrator + test + release agents on a stated task
- `fieldops-design-review.md` — triggers product-design advisory review
- `fieldops-graph-review.md` — Graphify-based codebase architecture review
- `fieldops-implement.md` — gated implementation flow
- `fieldops-release.md` — release readiness check

These remain unchanged. They are invoked by humans; they do not bypass the agent gates.

### 3.4 Governing files

- `CLAUDE.md` — operating manual; protected areas; safety rules; release discipline.
- `AGENTS.md` — agent roster + routing.
- `FIELDOPS_QUICK_CONTEXT.md` / `PROJECT_MAP.md` — quick-context and module map.
- `TEST_MATRIX.md` — role and module test coverage.
- `docs/v1.4.1_phase1_*.md` / `docs/v1.4.1_phase2_*.md` — review packages and runbooks.

This orchestration model adds `.claude/agents/` (formal definitions) and this document; it does not replace any of the above.

---

## 4. Gaps Found for Phase 2

The existing roster covers single-domain work (UI / bug / Supabase / test / release) but did not foresee the cross-cutting coordination Phase 2 demands. Concrete gaps:

| Gap | Why it matters in Phase 2 |
|---|---|
| **No SQL/RLS safety specialist** | Phase 1 §C.1 surfaced an RLS recursion bug in production. The fix landed via PR #24/PR #26 but only after the bug was discovered live. A pre-execution SQL/RLS gate would have caught it before staging. Phase 2 ships 6 new policies + a backfill — a stronger gate is mandatory. |
| **No runbook verifier** | Phase 1 staging runbook had a `gen_random_uuid()` / FK-violation defect that survived initial review and was caught only during execution. Phase 2 has 11 stop points across 2 migrations + app deploy — runbook correctness must be verified before execution starts, not during. |
| **No data-reconciliation specialist** | Phase 2 includes the Install Base master-source backfill (`INSTALL_BASE_V2` vs `config_assets`). Mis-identification of missing rows could silently corrupt the registry. The data-quality auditor agent existed informally in Phase 1 review prose; it needs a formal definition. |
| **No runtime-integration specialist** | The `_sb.rpc('app_user_role')` integration touches the auth lifecycle, body classes, role gating, XLSX flow, and 4+ new lifecycle UI workflows. The existing `fieldops-ui-agent` is focused on visual polish, not auth/RLS-aware integration. |
| **No automation memory** | Across multiple sessions, project state drifts (`config_assets` row count changed; legacy policy expressions weren't captured until late; PR numbers grew). A memory agent that owns "what's true right now" would prevent stale assumptions. |
| **`fieldops-orchestrator` is too generic** | The original orchestrator coordinates module work but doesn't own phase-level gating. Phase 2 spans SQL, runtime, and deploy — that's a phase, not a module. A delivery-level orchestrator is needed above the module orchestrator. |

---

## 5. New Agent Hierarchy (PM-tier extension, 2026-05-09)

```
FieldOps3i Delivery Orchestrator (Tier 0 — Executive)
│
├── Tier 1 — Project Managers (one per track)
│   ├── fieldops-database-pm           (.claude/agents/fieldops-database-pm.md)
│   ├── fieldops-runtime-pm            (.claude/agents/fieldops-runtime-pm.md)
│   └── fieldops-release-pm            (.claude/agents/fieldops-release-pm.md)
│
├── Tier 2 — Specialists (owned by the PM in their track)
│   │
│   ├── DB-track specialists (owned by fieldops-database-pm)
│   │   ├── fieldops-sql-rls-safety-agent
│   │   ├── fieldops-migration-runbook-verifier
│   │   └── fieldops-data-reconciliation-agent
│   │
│   ├── Runtime-track specialists (owned by fieldops-runtime-pm)
│   │   ├── fieldops-runtime-integration-agent
│   │   ├── fieldops-qa-test-automation-agent (NEW — automated test harness)
│   │   └── fieldops-ui-agent (legacy; advisory)
│   │
│   └── Release-track specialists (owned by fieldops-release-pm)
│       ├── fieldops-release-agent (legacy)
│       ├── fieldops-test-agent (legacy; manual TEST_MATRIX)
│       └── fieldops-qa-test-automation-agent (also reports here for regression)
│
├── Tier 3 — Cross-cutting (report directly to Delivery Orchestrator on demand)
│   ├── fieldops-automation-memory-agent (state persistence: automation/STATE.md)
│   ├── fieldops-orchestrator (legacy module coordination)
│   ├── fieldops-bug-agent (legacy)
│   └── fieldops-supabase-agent (legacy)
│
└── Tier 4 — Product design advisory team (advisory-only)
    └── product design lead + 5 specialists (see PRODUCT_DESIGN_TEAM.md)
```

**How the tiers work together:**
- Tier 0 sequences phases, owns the final PASS/HOLD/STOP, never paraphrases anyone below.
- Tier 1 PMs own a track end-to-end — they delegate to Tier 2 specialists, collect findings, produce ONE attributed verdict.
- Tier 2 specialists own narrow, deep checks with hard stops.
- Tier 3 + Tier 4 are invoked by name when needed; they don't automatically gate every task.

**When to skip a tier:**
- Single-specialist task → orchestrator may invoke the specialist directly (skip the PM).
- Single-line doc edit → no orchestrator needed.
- See [`docs/fieldops3i_task_routing_protocol.md`](fieldops3i_task_routing_protocol.md) §2 for the full skip-conditions table.

**Why a PM tier was added (2026-05-09 round-2 audit finding):**
The round-2 audit found that the orchestrator was synthesizing findings from 5+ specialists per multi-track task, creating cognitive overload and making it harder to enforce hard stops. A PM tier per track:
- Reduces orchestrator load on multi-specialist tasks.
- Gives each track ONE attributed verdict the orchestrator can combine cleanly.
- Makes the SQL-apply-first sequencing constraint between DB and Runtime tracks an explicit cross-PM coordination, not an orchestrator-internal step.
- Doesn't add gates — replaces "orchestrator does N specialist calls" with "orchestrator does 3 PM calls, each PM does its specialist calls in parallel".

---

## 6. New Agent Definitions

The full agent prompts live in `.claude/agents/`. The summary below covers purpose, responsibilities, inputs, outputs, model, hard stops, and forbidden actions for each new agent. (UI / bug / Supabase / test / release / product-design agents are unchanged and continue to live in `AGENTS.md`.)

### 6.1 `fieldops-delivery-orchestrator`

- **Purpose:** phase-level controller. Owns sequencing, stop points, scope control, PR gates, staging/prod separation, final PASS / HOLD / STOP / ESCALATE authority.
- **Responsibilities:** sequence apply order across SQL + runtime + deploy; assert that the runbook stop points are honored; refuse to advance without an explicit human approval phrase at every gate; coordinate specialist findings into a single PASS/STOP signal.
- **Inputs:** current PR state; latest commits; staging/prod application history; the runbook for the current phase; any specialist agent findings.
- **Outputs:** PASS/HOLD/STOP/ESCALATE per gate; a written advance plan; explicit list of pending approvals.
- **Model:** Opus 4.7 / Max.
- **Hard stops:** any specialist agent reports STOP; missing approval phrase; staging not at expected baseline; production touched without approval; runbook checksum mismatch.
- **Forbidden actions:** apply SQL; edit `index.html`; merge; tag; deploy; mark PR ready; touch production Supabase. (Orchestrator coordinates; it does not execute the gates it owns.)

### 6.2 `fieldops-sql-rls-safety-agent`

- **Purpose:** specialist review of every SQL migration before it can be approved for execution.
- **Responsibilities:** verify RLS recursion-free policy expressions; confirm SECURITY DEFINER + locked search_path on helpers that read the policy's own table; check `grant` vs RLS layering (`has_table_privilege` agreement); validate rollback symmetry, idempotency (every DDL guarded `if [not] exists`), service-role vs authenticated behavior, FK direction, partial unique indexes, and trigger fire order.
- **Inputs:** the migration SQL file(s); the rollback SQL file(s); the runbook section that applies them; current pg_policies / pg_proc state of the target environment if known.
- **Outputs:** PASS/STOP per migration; line-by-line findings (severity Critical / Medium / Minor); recommended exact patch text for any blocker.
- **Model:** Opus 4.7 / Max.
- **Hard stops:** any RLS recursion detected at runtime; any policy expression that references its own table without a security-definer wrapper; rollback file does not symmetrically reverse the migration; idempotency violation; unguarded DDL.
- **Forbidden actions:** run SQL; edit migration files without explicit human approval and a separate commit; touch Supabase; bypass `fieldops-orchestrator` review.

### 6.3 `fieldops-migration-runbook-verifier`

- **Purpose:** specialist correctness check on every runbook before it can become an executable plan.
- **Responsibilities:** verify pre-flight queries cover the actual environment baseline; apply order matches migration dependencies; expected outputs are stated for every query; rollback order is reverse of apply; cleanup statements name the correct session role (postgres / service-role vs authenticated); stop points are numbered and gated with explicit operator phrases; role context is preserved across multi-role tests; sensitive data is redacted in expected outputs.
- **Inputs:** the runbook file; the migration files it references; the environment baseline (staging or production); the currently-resolved approval phrases.
- **Outputs:** PASS/STOP per runbook; ordered list of defects with exact line numbers; recommended runbook patch text.
- **Model:** Opus 4.7 / Max for high-risk runbooks (production / cross-track); Sonnet 4.6 / Extra High for documentation cleanup of an already-PASS runbook.
- **Hard stops:** any test query that would lock out admin if run as the default `postgres` SQL Editor session without a BEGIN/ROLLBACK wrapper; missing session-context warning on RLS-bypass paths; cleanup that requires a privilege the runbook doesn't document; missing stop point for a step that mutates state; a step whose expected output is defined as "should pass" without a concrete value.
- **Forbidden actions:** run SQL; deploy; merge; mark PR ready.

### 6.4 `fieldops-data-reconciliation-agent`

- **Purpose:** owns identification and reconciliation of data drift between sources (`INSTALL_BASE_V2` vs `config_assets`, PM/CMC vs lifecycle, XLSX vs DB).
- **Responsibilities:** identify missing/extra codes; flag duplicates and blanks; verify marker rows after backfill match the pre-state missing set; audit XLSX upload diff (in-XLSX vs in-DB) before approving an upsert; surface ambiguous customer-name variants; recommend CSV review steps for fuzzy matches.
- **Inputs:** source data (V2 array, XLSX rows, PM/CMC tables); destination state (`config_assets`); existing reconciliation queries from runbooks.
- **Outputs:** PASS/STOP/ESCALATE; concrete diff (with row counts and codes); recommended INSERT / UPDATE / SKIP triage list.
- **Model:** Sonnet 4.6 / High for routine reconciliation; Opus 4.7 / Max for conflict decisions.
- **Hard stops:** non-zero unexplained drift between source and destination; ambiguous match where multiple V2 codes resolve to the same `config_assets.code`; XLSX upload missing a row that DB has app-created status on.
- **Forbidden actions:** run write SQL; modify data without approval; touch production Supabase; merge or deploy.

### 6.5 `fieldops-runtime-integration-agent`

- **Purpose:** owns app implementation planning. Implementation only happens after explicit human approval and a separate review.
- **Responsibilities:** design `_sb.rpc('app_user_role')` integration, including async lifecycle, fallback, caching, and refresh-on-auth-change; redesign `canManagePM()` after email allowlist removal; verify `manager-mode` body class transitions; plan XLSX upsert-by-code with explicit XLSX-owned column list; design Add / Edit / De-install / Renew UI workflows including form schema, payload shape, history insert, and confirmation typing for de-install; validate role-safe UI gating for every button.
- **Inputs:** current `index.html`; relevant Phase 2 review docs; `user_roles` seed expectation; agreed Phase 2 RLS policy set.
- **Outputs:** PASS/STOP for the design doc; exact diff patches for `index.html` (review-only); test plan for each role; risk register.
- **Model:** Opus 4.7 / Max for architecture; Sonnet 4.6 / Extra High for approved implementation.
- **Hard stops:** integration plan would deploy before SQL apply on the same environment; auth fallback path missing; XLSX upsert payload inadvertently overwrites lifecycle fields; any new write button not gated by `canManagePM()`.
- **Forbidden actions:** edit `index.html` until separately approved; deploy; modify `VERSION`/`CHANGELOG.md`/`releases/*`; mark PR ready; merge.

### 6.6 `fieldops-automation-memory-agent`

- **Purpose:** maintain a persistent, accurate model of "what is true right now" across sessions.
- **Responsibilities:** track latest PR numbers + commit SHAs; staging schema/seed state; production schema/seed state; SQL execution history (which migrations applied, when, which environment); pending approval gates; known risks and their owning agent; redact sensitive identifiers when summarizing.
- **Inputs:** PR/commit logs (`gh pr list`, `git log`); runbook stop-point completions; specialist agent outputs; user-confirmed environment state.
- **Outputs:** structured state snapshot suitable for any other agent to consume on session start; flagged stale assumptions (e.g. row counts that may have drifted since last verified).
- **Model:** Sonnet 4.6 / High for routine state tracking; Opus 4.7 / Max for phase-level summaries and end-of-phase reports.
- **Hard stops:** state inconsistency detected (e.g. a runbook claims a migration is applied but the verifier disagrees); production action recorded without an approval phrase trace.
- **Forbidden actions:** modify state by running SQL or making writes; speak on behalf of a specialist (only summarize their findings); claim verification not actually performed.

---

## 7. Model Usage Matrix

| Tier | Model | When to use |
|---|---|---|
| **Tier 1 — high-risk reasoning** | Opus 4.7 / Max | Architecture; SQL/RLS review (`fieldops-sql-rls-safety-agent`); runbook verification for production paths; release-risk review; security-sensitive changes; phase-level orchestration; conflict resolution in data reconciliation. |
| **Tier 2 — approved implementation** | Sonnet 4.6 / Extra High | Approved coding execution following a Tier-1-PASSED design (`fieldops-runtime-integration-agent` post-approval); approved documentation cleanup; staging-only runbook verification of a previously-approved package. |
| **Tier 3 — routine verification + summaries** | Sonnet 4.6 / High | Test verification (`fieldops-test-agent` routine work); PR comments and summaries; routine data reconciliation; automation memory snapshots. |
| **Tier 4 — light text only** | Haiku 4.5 | Grammar / typo fixes; very short summaries; copy edits. **Never** for SQL, RLS, runbooks, or release decisions. |

Default policy: when in doubt, choose the higher tier. Downgrading model selection on a high-risk task is a defect.

---

## 8. Phase 2 Operating Protocol

The exact flow is:

1. **Operator submits a task** (e.g., "apply Phase 2 to staging", "review Phase 2 RPC integration plan", "reconcile V2 vs production").
2. **`fieldops-delivery-orchestrator` receives the task** and reads current state (via `fieldops-automation-memory-agent`): branch, PR state, latest commits, staging/prod baselines, pending gates.
3. **Orchestrator assigns specialist agents** based on task type:
   - SQL changes → `fieldops-sql-rls-safety-agent`
   - Runbook changes → `fieldops-migration-runbook-verifier`
   - Data integrity → `fieldops-data-reconciliation-agent`
   - App code changes → `fieldops-runtime-integration-agent`
   - Verification → `fieldops-test-agent`
   - Release readiness → `fieldops-release-agent`
4. **Specialist agents produce findings** with PASS / HOLD / STOP / ESCALATE plus a concrete recommendation.
5. **Migration / runbook verifier checks gates**: confirms each runbook stop point is honored, queries match expected outputs, role context preserved, rollback path tested.
6. **SQL/RLS agent signs off on DB safety** (or doesn't) before any apply approval is granted.
7. **Release-agent gatekeeper** checks PR state (DRAFT vs ready), file scope (no `index.html`/`VERSION`/`CHANGELOG.md`/`releases/*` change unless explicitly approved), tag/deploy state.
8. **Human approval is required** before any of:
   - SQL apply on any environment
   - Runtime implementation (`index.html` edit)
   - PR mark-ready
   - PR merge
   - Production action of any kind
   - Tag creation
   - Deploy
9. **Approval is recorded** by the automation memory agent. The orchestrator advances to the next gate.
10. **At any point any agent reports STOP**, the orchestrator halts and surfaces the blocker.

The flow is loop-friendly: after each step, state is reread by the memory agent. Stale assumptions trigger an automatic HOLD until reconciled.

---

## 9. Stop / Go Language

| Token | Meaning |
|---|---|
| **PASS** | Specialist confirms the artifact under review meets all required gates; orchestrator may advance to the next stop point provided every other agent has also passed. |
| **HOLD** | Waiting for input — usually a runbook paste-back, an operator approval phrase, a downstream agent's findings, or a missing baseline capture. No advance until released. |
| **STOP** | Do not proceed. A blocker has been identified. Either fix the blocker (separate commit / explicit decision) or abandon the task. |
| **ESCALATE** | Human decision required. The agent cannot decide between two acceptable paths (e.g., "Manager XLSX permission: allow or restrict?"). Orchestrator surfaces options and waits. |

These tokens are explicit in agent output. "Looks good" / "should work" / "probably fine" are not valid outputs.

---

## 10. Hard Safety Rules

These rules apply to every agent, every session, every task. They cannot be relaxed by individual agents.

- **No SQL without explicit approval.** Approval is a literal phrase the operator types in chat (e.g., `approved, apply phase 2 to staging`).
- **No Supabase staging or production touch without approval.** Inspection-only `select` from staging is also gated; the operator runs the queries in their own SQL Editor and pastes results back.
- **No runtime edits in review-only PRs.** Review packages may include diff text, but applying the diff to `index.html` is a separate PR and a separate approval.
- **No edits to `index.html`, `VERSION`, `CHANGELOG.md`, `releases/*`, tags, or deploys** unless explicitly approved by the operator and the release-agent has cleared the change.
- **No production action without the exact approval phrase** for that environment (staging and production phrases differ).
- **No claimed specialist review unless one was actually performed.** The agent that ran the check signs the PASS/STOP. The orchestrator may not paraphrase a specialist; it relays.
- **No agent may downgrade the model selection** for a high-risk task.
- **No agent may bypass `fieldops-delivery-orchestrator`** when phase-level state is in scope.
- **Failed gate reports are append-only.** The audit chain (this document + agent outputs in chat) is the record; do not overwrite past findings.

---

## 11. Automation Maturity Roadmap

This 4-level summary is preserved for backward compatibility. The full 6-level roadmap with target timelines lives in [`docs/fieldops3i_task_routing_protocol.md`](fieldops3i_task_routing_protocol.md) §6.

| Level | Description | FieldOps3i status |
|---|---|---|
| **Level 1 — Human-guided automation** | Each task driven by the human; agents respond to specific prompts; no persistent state across sessions. | Pre-2026-05-09 baseline. |
| **Level 2 — Semi-automated verification** | Specialist agents check artifacts (SQL / runbook) before execution; human still triggers every step; explicit stop points. | **Current state as of `e0da6a2`.** |
| **Level 3 — Scripted verification** | Most pre-flight + post-apply checks are CI-asserted, not paste-backs. Memory persists. Rollback is tag-based. | **Target within 4-8 weeks** (after CI verify-migrations workflow + state persistence + Tier 1-3 tests land). |
| **Level 4 — Automated test harness** | Playwright role-permission tests + RLS assertion suite + post-deploy smoke run on every PR/deploy. | Target within 3 months. |
| **Level 5 — Self-checking release pipeline** | `scripts/release.sh` is authoritative; release flow automated end-to-end with rollback rehearsal. | Target within 6 months. |
| **Level 6 — Near-autonomous delivery** | Human appears only at production apply, security policy change, release tag. | Long-term. |

The 2026-05-09 PM-tier upgrade itself does NOT advance the maturity level — it reduces operator burden on multi-track tasks and makes the existing Level 2 verification chain easier to follow. Maturity advances when CI assertions and the QA test harness actually land in `.github/workflows/` and `tests/`.

---

## 12. Immediate Recommendation

PR #26 should remain DRAFT until:

1. This orchestration model is reviewed and accepted by the operator (or explicitly amended).
2. The Phase 2 staging runbook is verified by `fieldops-migration-runbook-verifier` against the gates in §8.
3. The Phase 2 SQL migrations (0004 + 0005) are signed off by `fieldops-sql-rls-safety-agent`.
4. The Phase 2 runtime integration plan is signed off by `fieldops-runtime-integration-agent` (review-only — no `index.html` edit yet).
5. The data reconciliation plan for the V2 backfill is signed off by `fieldops-data-reconciliation-agent`.
6. The release-agent has confirmed PR #26's scope (no runtime files, no version change, no tag).

After all six PASS, PR #26 may be marked ready for human review. Merge is a separate gate.

This document is the contract under which Phase 2 proceeds.
