# MRI FieldOps Dashboard — Project Map

Use this file to locate the right area before editing. Do not rewrite broad sections unless necessary.

## Main Runtime File

- `index.html`: single-page FieldOps dashboard containing HTML, CSS, and JavaScript.

## Foundation and Documentation Files

- `CLAUDE.md`: governing Claude operating manual.
- `AGENTS.md`: engineering and product-design agent definitions; routing tree.
- `FIELDOPS_QUICK_CONTEXT.md`: short startup context.
- `PROJECT_MAP.md`: file/module map.
- `TEST_MATRIX.md`: verification checklist (manual layer).
- `CHANGELOG.md`: release history.
- `VERSION`: current version.
- `RELEASING.md`: release process.
- `ROLLBACK.md`: rollback process (tag-based default; force-push only with operator phrase).
- `DEPLOYMENT.md`: deployment guide.
- `automation/FIELDOPS_AUTOMATION_ROADMAP.md`: automation roadmap and boundaries (legacy 4-phase document).
- `automation/STATE.md`: persistent state snapshot (current truth) — read by every agent at session start (added 2026-05-09).
- `automation/memory/MEMORY_PROTOCOL.md`: rules, format, routing matrix, safety, evolution, anti-bloat for the memory layer (added 2026-05-10).
- `automation/memory/GLOBAL_LESSONS.md`: cross-agent durable rules; read before every high-risk task.
- `automation/memory/tracks/<track>.md`: per-track durable lessons (delivery-orchestrator / database / runtime / release).
- `docs/fieldops3i_agent_orchestration_model.md`: Tier 0–4 agent hierarchy + safety rules.
- `docs/fieldops3i_task_routing_protocol.md`: task routing tree, quality gates, automation maturity (Levels 1-6), Phase 2 walkthrough, anti-overengineering rules.
- `docs/GRAPHIFY_USAGE.md`: Graphify status and usage rules.
- `docs/PRODUCT_DESIGN_TEAM.md`: product design team operating manual.
- `docs/PRODUCT_DESIGN_BACKLOG.md`: design suggestions before approval/implementation.
- `.claude/agents/`: formal agent definitions (Tier 0 + Tier 1 PMs + Tier 2 specialists).
- `.claude/commands/`: repeatable Claude command workflows.

## Project Directories

- `db/`: database schema, seed data, migrations. Protected.
- `scripts/`: helper/release scripts.
- `graphify-out/`: generated architecture map. Use only when needed and freshness is confirmed.
- `releases/`: release snapshots.
- `.github/workflows/`: deployment automation. Protected.

## Main App Modules

- Login overlay
- Supabase Auth
- Dashboard KPIs
- Service History
- Open Tickets
- PM Schedules
- Install Base
- Field Team
- Flags & Ambiguities
- Engineer Performance
- Reports
- Audit Log
- XLSX upload
- CSV/PDF export
- Realtime/live indicator
- Staging/production mode handling
- Role-based UI access

## High-Risk Areas

Approval required before changes:

- Supabase initialization
- Auth/session logic
- Role-based visibility
- Audit logging
- XLSX parsing/import
- Database writes
- PM calculations
- Engineer performance calculations
- Deployment/version files
- GitHub Actions workflows
- Production config
- `.env` and `.env.*`

## Safer First Improvements

Usually low-risk if scoped carefully:

- documentation updates
- UI spacing and consistency
- empty states
- loading states
- error message clarity
- table readability
- mobile layout refinements
- design backlog updates

## Agent Team

The hierarchy has 4 tiers as of 2026-05-09. Full diagram in `AGENTS.md` §3 and `docs/fieldops3i_agent_orchestration_model.md` §5.

Tier 0 — Delivery Orchestrator:

- `fieldops-delivery-orchestrator`

Tier 1 — Project Managers (one per track):

- `fieldops-database-pm`
- `fieldops-runtime-pm`
- `fieldops-release-pm`

Tier 2 — Specialists (formal):

- `fieldops-sql-rls-safety-agent`
- `fieldops-migration-runbook-verifier`
- `fieldops-data-reconciliation-agent`
- `fieldops-runtime-integration-agent`
- `fieldops-qa-test-automation-agent` (NEW 2026-05-09)
- `fieldops-automation-memory-agent`

Tier 3 — Legacy / module-level engineering agents:

- `fieldops-orchestrator`
- `fieldops-ui-agent`
- `fieldops-bug-agent`
- `fieldops-supabase-agent`
- `fieldops-test-agent`
- `fieldops-release-agent`

Tier 4 — Product design advisory:

- `fieldops-product-design-lead`
- `fieldops-enterprise-ux-researcher`
- `fieldops-dashboard-usability-auditor`
- `fieldops-design-system-guardian`
- `fieldops-accessibility-reviewer`
- `fieldops-microinteraction-designer`

Use `/fieldops-agent-team` for coordinated planning.
Use `/fieldops-graph-review` for Graphify-assisted architecture/impact review.
Use `/fieldops-design-review` for monthly or intentional product design review.
Use `/fieldops-implement` only after plan approval.
Use `/fieldops-release` before versioning or deployment.

For task routing decisions (which tier to enter), see `docs/fieldops3i_task_routing_protocol.md` §2.

## Role Model

- Admin/Superadmin: main privileged profile.
- Manager: management-level profile if configured.
- Engineer/Viewer: restricted profile.
- Audit Log: special email-gated superadmin condition.

Do not treat Super Admin and Admin as separate full profiles unless the app is intentionally redesigned.
