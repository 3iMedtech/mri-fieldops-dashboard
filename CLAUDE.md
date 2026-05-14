# MRI FieldOps Dashboard — Claude Operating Manual

This file is the governing operating manual for Claude and project agents working on FieldOps3i.

FieldOps3i is a live MRI field service operations dashboard for 3i MEDTECH. Treat it as a production-grade business application. Be careful, verify before changing, and protect working behavior.

---

## 1. Source of Truth Order

Use this order when understanding the project:

1. Current source files in the repo
2. Current documentation files
3. Current release/changelog notes
4. Freshly regenerated Graphify output
5. Archived/old Graphify output as historical reference only

Do not treat generated maps, old summaries, or memory as stronger than current source files.

---

## 2. Default Session Startup

For normal work:

1. Read `FIELDOPS_QUICK_CONTEXT.md`.
2. Read `PROJECT_MAP.md`.
3. Read this file if the task has risk, implementation, release, Graphify, Supabase, auth, role, deployment, automation, or design impact.
4. For phase-level / high-risk work, also read `automation/STATE.md` (current truth) and `automation/memory/GLOBAL_LESSONS.md` (durable rules). PMs and specialists additionally read their own track file under `automation/memory/tracks/`. Full routing in `automation/memory/MEMORY_PROTOCOL.md` §5.
5. Read only the relevant section of `index.html` or other source files.
6. Do not scan large generated folders by default.

For medium or high-risk work, start with `fieldops-orchestrator` (module-level) or `fieldops-delivery-orchestrator` (cross-track / phase-level).

---

## 3. Core Safety Rules

Claude must:

- Analyze first, then suggest.
- Never guess behavior that can be checked.
- Preserve existing working functionality.
- Prefer small, reversible changes.
- Avoid broad rewrites unless explicitly justified.
- Keep role-based behavior safe.
- Keep Supabase, auth, audit, deployment, and database logic protected.
- Clearly state what was reviewed, changed, tested, and what remains unverified.

Claude must not:

- Edit files unless explicitly asked to implement.
- Deploy, push, publish, reset, or run destructive commands without explicit approval.
- Modify `.env`, `.env.*`, secrets, tokens, passwords, or service-role keys.
- Claim testing succeeded unless it was actually performed.
- Use production credentials unless explicitly approved.
- Store credentials in files or responses.

---

## 4. Protected Areas

The following areas require explicit approval before modification:

- Supabase URL/key/environment logic
- Supabase queries that affect role visibility or writes
- Auth/login/logout/recovery/session flow
- Role-based access logic
- Audit log logic
- Production/staging detection
- XLSX upload parser
- Database write/update functions
- Database schema and migrations
- PM schedule calculations
- Engineer performance calculations
- Deployment files
- GitHub Actions workflows
- Production config
- `.env` and `.env.*`

For protected areas, always provide:

1. affected files/modules
2. risk level
3. test plan
4. rollback plan
5. approval checkpoint

---

## 5. Current Role Model

Do not assume separate full profiles for Super Admin and Admin.

Use this role model:

- `Admin/Superadmin`: main privileged profile for normal admin workflows.
- `Manager`: management-level profile if configured through metadata or fallback email logic.
- `Engineer/Viewer`: restricted profile.
- `Audit Log`: separately gated by special superadmin email condition.

Rules:

- Use the label `Admin/Superadmin` for the privileged admin profile.
- Test Audit Log separately because it is email-gated.
- Verify role behavior against actual code before changing access logic.
- Never weaken role gates silently.

---

## 6. Graphify Rules

Graphify exists to support architecture understanding. It is not the source of truth.

Current policy:

- Do not read `graphify-out/` by default.
- Do not read `graphify-out/GRAPH_REPORT.md` for every request.
- Use Graphify only for architecture review, dependency mapping, impact analysis, codebase structure questions, or major refactor planning.
- For normal UI changes, small bug fixes, text changes, styling changes, release notes, or small features, use quick context, project map, and targeted source reads first.
- If Graphify is needed, read the smallest useful summary first:
  1. `graphify-out/wiki/index.md` if it exists
  2. `graphify-out/GRAPH_REPORT.md` only if needed
- Do not read raw Graphify output unless required.
- Do not run `graphify update .`, `graphify analyze .`, or equivalent commands automatically.
- Ask before overwriting or regenerating `graphify-out/`.

Freshness rule:

- If Graphify was generated before recent major project changes, treat it as stale.
- Archive old Graphify before regeneration.
- After regeneration, update `docs/GRAPHIFY_USAGE.md` with date, command, status, and limitations.

---

## 7. Agent Team Rules

Use the FieldOps agent team for structured engineering work. The hierarchy has 4 tiers as of 2026-05-09 — see [`docs/fieldops3i_agent_orchestration_model.md`](docs/fieldops3i_agent_orchestration_model.md) §5 for the full diagram and [`docs/fieldops3i_task_routing_protocol.md`](docs/fieldops3i_task_routing_protocol.md) §2 for the routing decision tree.

### Tier 0 — Delivery Orchestrator
- `fieldops-delivery-orchestrator`: phase-level controller. PASS / HOLD / STOP / ESCALATE authority. Use when a task crosses SQL ↔ runtime ↔ release boundaries.

### Tier 1 — Project Managers (one per track; coordinate specialists; produce ONE attributed verdict per track)
- `fieldops-database-pm`: owns DB track (sql-rls-safety + runbook-verifier + reconciliation).
- `fieldops-runtime-pm`: owns runtime track (runtime-integration + qa-test-automation + ui-agent advisory).
- `fieldops-release-pm`: owns release track (release-agent + qa-test-automation + memory snapshot).

### Tier 2 — Specialists (formal; have hard stops)
- `fieldops-sql-rls-safety-agent`: SQL/RLS migration review.
- `fieldops-migration-runbook-verifier`: runbook correctness vs migration claims.
- `fieldops-data-reconciliation-agent`: V2 / XLSX / PM-CMC drift identification.
- `fieldops-runtime-integration-agent`: app integration design.
- `fieldops-qa-test-automation-agent`: automated test harness (Tier 1-5 of the test pyramid).
- `fieldops-automation-memory-agent`: state persistence (writes `automation/STATE.md`).

### Tier 3 — Legacy / module-level engineering agents
- `fieldops-orchestrator`: planning, scope, risk, module mapping (single-domain).
- `fieldops-ui-agent`: UI/UX polish.
- `fieldops-bug-agent`: root-cause analysis.
- `fieldops-supabase-agent`: Supabase reads/writes within module scope.
- `fieldops-test-agent`: manual `TEST_MATRIX.md` execution.
- `fieldops-release-agent`: release readiness specialist (now reports through release-pm).
- `fieldops-observability-agent`: post-deploy smoke verification (APP_VERSION, Pages headers, console errors, audit_log health). Reports to release-pm.

### Tier 4 — Product design advisory team
- `fieldops-product-design-lead`, `fieldops-enterprise-ux-researcher`, `fieldops-dashboard-usability-auditor`, `fieldops-design-system-guardian`, `fieldops-accessibility-reviewer`, `fieldops-microinteraction-designer`. Advisory-only; no implementation without approval.

Rules:

- Use the Delivery Orchestrator for any phase-level work (multi-track).
- Use a PM when a task needs 2+ specialists in the same track.
- Skip the PM when only one specialist is needed (see routing protocol §2.1).
- Use product design agents for intentional UX/design review, not routine bug fixes.
- Do not claim a specialist review happened unless it was actually performed.
- A PM must NEVER paraphrase a specialist's verdict — relay it attributed.

---

## 8. Product Design Team Rules

The Product Design Team is an advisory and review layer. It may recommend improvements but must not directly implement changes without approval.

Design suggestions must improve at least one of:

- clarity
- speed
- trust
- accessibility
- decision-making
- error prevention
- field-team usability
- management visibility

Avoid:

- cosmetic-only changes with no functional benefit
- trend-chasing
- visual inconsistency
- changing familiar workflows without strong reason
- weakening role-based behavior
- introducing animation or visual noise that reduces usability

Design workflow:

1. Observe
2. Research when needed
3. Suggest
4. Score impact and risk
5. Add to `docs/PRODUCT_DESIGN_BACKLOG.md`
6. Human approval
7. Small implementation
8. Test through `TEST_MATRIX.md`
9. Release through normal process

Monthly design reviews should use `.claude/commands/fieldops-design-review.md` and should not edit app code unless separately approved.

---

## 9. Model Usage Guidance

Recommended model usage:

- Claude Opus: architecture, planning, high-risk review, release strategy, Supabase policy/security review, Graphify refresh planning, product design strategy.
- Claude Sonnet: implementation, UI polish, normal debugging, documentation cleanup, test verification.
- Claude Haiku: short summaries, simple copy edits, quick checklist drafting.

Recommended flow:

`Opus plans → Sonnet implements → specialist agents verify → Opus reviews release risk`.

---

## 10. Before Making Changes

Before any implementation, state:

1. Summary of the requested change
2. Files likely touched
3. Affected modules
4. Risk level
5. Test plan
6. Rollback plan
7. Whether approval is required before editing

Wait for approval unless the user clearly asked to implement and the change is low risk.

---

## 11. Testing Expectations

After changes, use the most practical available verification:

- Run available lint/build/test commands if present.
- Open app locally if possible.
- Use staging for role and deployment verification.
- Log in with user-provided staging credentials when required.
- Navigate to affected pages.
- Check browser console if available.
- Review git diff before final response.

Use `TEST_MATRIX.md` for detailed role, page, Supabase, UI, accessibility, and product-design checks.

---

## 12. Release and Deployment Rules

All runtime changes must go through staging before production.

### Development branch rule

All code changes (`index.html`, `scripts/`, `docs/`, `.github/workflows/`) must be committed and pushed to the **`staging` branch** — never directly to `main`. Pushing to `staging` auto-triggers `staging-dispatch.yml`, which updates `https://3imedtech.github.io/mri-fieldops-dashboard/staging/`.

`main` is the production branch. It must never receive a direct push except as part of an approved production deploy.

### Production deploy sequence

Production deploy requires an explicit approval phrase from the user. Accepted phrases:

- "approved for production"
- "deploy to production"
- "push to production"

On receiving one of these phrases, and only then:

1. Confirm staging matrix passed (0 failures): `node /tmp/fieldops_matrix.js staging`
2. Fast-forward main to staging: `git push origin staging:main`
3. Trigger manual deploy: `gh workflow run pages-deploy.yml --ref main`
4. Wait for workflow completion, then run matrix on production: `node /tmp/fieldops_matrix.js production`

### Pre-production checklist

- clean Git status on staging branch
- version bumped if applicable
- staging matrix: 0 failures, 0 JS errors
- role testing complete
- explicit approval phrase received

Do not deploy production from normal implementation prompts. Do not push to `main` without the approval phrase above.

---

## 13. Final Response Format

For implementation work, respond with:

- Summary
- Files reviewed
- Files changed
- Root cause or reason
- Risk
- Test result
- What could not be tested
- Rollback steps
- Next recommended action
- **Memory consulted:** entry IDs cited (e.g., `L-G-003`, `L-SQL-001`)
- **Memory updates proposed:** new lessons in `automation/memory/MEMORY_PROTOCOL.md` §4 format, or "none"

Keep responses short, technical, and specific to FieldOps3i.

---

## 14. Memory System

FieldOps3i uses a structured memory system at [`automation/memory/`](automation/memory/). Read it. Don't bypass it. Don't blindly trust it.

Source-of-truth priority (memory is **last**):

1. Current repository files
2. Current git branch + commit
3. Current PR state
4. Current runbook
5. Current Supabase / environment outputs
6. Current operator approval phrases
7. `automation/STATE.md` (current-truth snapshot)
8. `automation/memory/**` (durable lessons / advisory)

Hard rules (every agent inherits these):

- Memory is advisory. Memory is never source of truth.
- Memory cannot authorize SQL, staging, production, merge, tag, deploy, or mark-ready.
- Memory cannot override an operator approval phrase or its absence.
- Stale memory must be labeled (`STALE — re-verify before relying`).
- Conflicting memory triggers HOLD.
- Cite which entry IDs influenced your decision.
- Agents do not silently change behavior based on memory. Behavior changes only via visible commits to `.claude/agents/<agent>.md` or governance docs.

Full protocol: [`automation/memory/MEMORY_PROTOCOL.md`](automation/memory/MEMORY_PROTOCOL.md).
