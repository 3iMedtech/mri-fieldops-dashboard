# mri-fieldops-dashboard

Field Operations Dashboard for 3i MEDTECH MRI service operations.

FieldOps3i is a live service operations dashboard used to track MRI service calls, open tickets, preventive maintenance schedules, install base, field team activity, engineer performance, reports, audit logs, and role-based operational KPIs.

## Project Type

- Single-page HTML/CSS/JavaScript dashboard
- Main runtime file: `index.html`
- Backend: Supabase Auth + Postgres/REST
- Deployment: GitHub Pages

## Current Role Model

- Admin/Superadmin
- Manager
- Engineer/Viewer
- Audit Log is separately email-gated

## Key Documentation

- `CLAUDE.md`: Claude operating manual
- `AGENTS.md`: Engineering and product-design agents
- `FIELDOPS_QUICK_CONTEXT.md`: Quick project context
- `PROJECT_MAP.md`: File/module map
- `TEST_MATRIX.md`: Verification checklist
- `RELEASING.md`: Release process
- `ROLLBACK.md`: Rollback process
- `DEPLOYMENT.md`: Deployment safety guide
- `docs/GRAPHIFY_USAGE.md`: Graphify usage and freshness rules
- `docs/PRODUCT_DESIGN_TEAM.md`: Product design team guidance
- `docs/PRODUCT_DESIGN_BACKLOG.md`: Proposed design improvements

## Safety

Do not modify Supabase, auth, role access, audit log, database writes, deployment, production config, `.env`, or GitHub Actions without explicit approval.
