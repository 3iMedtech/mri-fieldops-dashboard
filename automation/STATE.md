# FieldOps3i — Persistent State Snapshot

**Owner:** `fieldops-automation-memory-agent`
**Updated by:** operator-approved commit, with content drafted by `fieldops-automation-memory-agent` at verified gates. The agent does not directly commit state changes.
**Read by:** every agent at session start (especially the Delivery Orchestrator and the three PMs).
**Authority:** advisory snapshot. The repository + Supabase are the truth; this file is the cache.
**Scope:** *current truth* (PRs, branches, environment state, open gates, stale assumptions). For *durable lessons*, see [`memory/MEMORY_PROTOCOL.md`](memory/MEMORY_PROTOCOL.md), [`memory/GLOBAL_LESSONS.md`](memory/GLOBAL_LESSONS.md), and [`memory/tracks/`](memory/tracks).

If this file disagrees with `git log` / `gh pr list` / Supabase, the repo and Supabase win — and the disagreement itself is a finding the memory agent must surface (`STALE` or `INCONSISTENT`).

---

## Last verified

- **Snapshot timestamp:** 2026-05-24 (v1.5.2 deployed to production; v1.5.3 on staging — 74/74 matrix pass)
- **Snapshot author:** Claude (acting as automation-memory-agent)

---

## Branch + commit

- **Canonical branch:** `main`
- **Latest commit on `main`:** `4581fae` — `release: v1.5.2 — Manager XLSX upload, cmc_contracts UNIQUE(sn), test matrix render coverage`
- **Latest commit on `staging`:** `ba2351b` — `fix(ux): PD-003/008/010/011/012 — UX polish bundle (v1.5.3)` — **staging is 1 commit ahead of main**
- **Latest tag:** `v1.5.2` (annotated, pointing to `4581fae`) — `APP_BUILD.tag` and git tag aligned.
- **Previous tag:** `v1.5.1`
- **Working tree:** clean

---

## Open PRs

No open PRs. PRs #25 and #28 closed 2026-05-24 (superseded by direct staging work).

---

## Recently merged / directly shipped to staging→main

All v1.4.2 through v1.5.1 work was shipped directly on the `staging` branch (no separate PRs merged). Summary of significant commits since v1.4.1:

| Commit | Description |
|---|---|
| `905ac6f` | release: v1.4.1 (last tagged release) |
| `9e34331` | release: v1.4.2 — AMC contract type, Renew lifecycle RPC, Contracts UX |
| `079eb83` | feat: v1.4.3 — unified Engineers tab + lifecycle management |
| `9779025` | feat(v1.5.0): Phase 1+nav — WO redesign schema (0012/0013) + tab rename |
| `83efcf2` | chore: bump APP_VERSION to 1.5.0 |
| `3261e54..fb762e2` | feat(v1.5.0): Phases 2–6 — WO form, branding, sub-WOs, email edge fn scaffold, legacy migration |
| `7c771cf..ed71163` | fix(v1.5.0): 7-issue batch, WO polish, asset lock, legacy integration, WO tab rename |
| `34bc689` | chore: align version metadata to v1.5.1 (VERSION file + APP_BUILD were stale) |
| `cf8c6bc` | feat: WO creation email notification via mailto (opt-in) — replaces broken edge-fn auto-fire |
| `7f8ab60` | fix(test): correct XLSX button text filter in test-matrix.js |

---

## Staging Supabase state

- **Project:** `fieldops-staging`
- **URL ref:** `qupkpprptopyejbnslev`
- **Org:** Abhijit Sen (FREE)
- **Last verified:** 2026-05-21
- **Migrations applied:** 0001–0015 (0014/0015 added `'working'` to sys_status constraint for WO closure)
- **Row counts (verified 2026-05-21):**
  - `config_assets`: **27** (25 active + 2 de-installed staging fixtures AN026/AN027)
  - `pm_schedule`: 22
  - `cmc_contracts`: 13
  - `app_tickets` (active): **36** (includes test WOs created during email notification testing)
  - `app_ticket_notifications`: **6** (all `status='failed'`, `error_msg='SMTP credentials not configured'` — edge function deployed but ZOHO_SMTP_* secrets never set)
  - `engineers`: 9
- **Edge function `notify-work-order`:** ACTIVE (version 2). Uses Zoho SMTP via nodemailer. **SMTP secrets not configured** — function will always fail until `ZOHO_SMTP_USER`, `ZOHO_SMTP_PASS`, `ALERT_FROM`, `WO_NOTIFY_CC` are set as Supabase secrets. The app now uses mailto: instead; edge function is dormant.
- **Helpers + policies + V2 fingerprint:** see `automation/memory/tracks/database-track.md` for full reconciliation.

---

## Staging Pages state

- **Staging Pages URL:** `https://3imedtech.github.io/mri-fieldops-dashboard/staging/index.html`
- **Currently served commit:** `ba2351b`
- **APP_VERSION:** `1.5.3`
- **Matrix:** 74/74, 0 JS errors (2026-05-24)

---

## Production Supabase state

- **Last verified:** 2026-05-21
- **Migrations applied:** 0001–0015 (same as staging; 0014/0015 applied previously for WO closure sys_status fix)
- **Row counts (verified 2026-05-21):**
  - `config_assets`: **25** (active=25, de_installed=0 — no staging fixtures)
  - `pm_schedule`: 22
  - `cmc_contracts`: 13
  - `app_tickets` (active): **26**
  - `app_ticket_notifications`: **0** (no notification attempts on production)
  - `engineers`: 9
- **Helpers present (5):** `app_user_role` / `app_can_write` / `app_is_admin` / `_other_active_admin_exists` / `_user_roles_block_last_admin_delete` (SECURITY DEFINER + locked search_path).
- **V2 fingerprint:** `965ffcec48aa3ddfbfb7b975bc48dca9` (matches staging — re-verify if V2 baseline changes).

---

## Production Pages state

- **Production Pages URL:** `https://3imedtech.github.io/mri-fieldops-dashboard/`
- **Currently served commit:** `4581fae` — `release: v1.5.2`
- **APP_VERSION:** `1.5.2`
- **Pages workflow run (latest):** `26361036755` — manual dispatch from `4581fae`, completed/success, 2026-05-24
- **Matrix:** 74/74, 0 JS errors, all 3 roles (2026-05-24)

---

## App runtime state

- **APP_VERSION on production:** `1.5.2`
- **APP_VERSION on staging:** `1.5.3`
- **Latest git tag:** `v1.5.2` (annotated, `4581fae`) — aligned with `APP_BUILD.tag`.
- **`index.html` on `main` (v1.5.2):** all four version constants aligned:
  - `window.APP_VERSION = '1.5.2'`
  - `window.APP_BUILD = { version: '1.5.2', released: '2026-05-24', tag: 'v1.5.2' }`
  - `const APP_VERSION = '1.5.2'`
  - `const APP_RELEASE_DATE = '24 May 2026'`
- **`index.html` on `staging` (v1.5.3):** staged, awaiting production approval.

---

## Production runtime smoke (2026-05-24)

Automated test matrix (`scripts/test-matrix.js production 1.5.2`) ran post-deploy on 2026-05-24 against commit `4581fae`. **74/74 checks passed, 0 JS errors across all 3 roles.**

| Role | Result |
|---|---|
| Admin | PASS — 26/26. APP_VERSION=1.5.2, role=admin, body=superadmin-mode, KPIs loaded (16), Contracts/PM/Engineers tabs functional, XLSX button visible, PM stats/timeline rendered, EP cards/tiles rendered. |
| Manager | PASS — 26/26. APP_VERSION=1.5.2, role=manager, body=viewer-mode manager-mode, KPIs loaded (16), all tabs functional, XLSX button visible, PM stats/timeline rendered. |
| Engineer | PASS — 22/22. APP_VERSION=1.5.2, role=viewer, body=viewer-mode, Contracts nav hidden, Renew buttons absent, XLSX hidden, PM read-only, EP cards/tiles rendered. |

---

## Open approval gates (operator phrase needed)

| Gate | Phrase needed |
|---|---|
| Deploy v1.5.3 to production (staged, 74/74 PASS) | `deploy to production` |
| Configure Zoho SMTP secrets to activate server-side WO email | Operator sets secrets in Supabase dashboard |

---

## Open risks

| Risk | Severity | Owner | Recorded at |
|---|---|---|---|
| `notify-work-order` edge function deployed but SMTP secrets not configured — will always fail if invoked directly | Low | runtime-pm | 2026-05-21 (app uses mailto: now; edge fn dormant) |
| No automated tests in repo (only manual matrix + ad-hoc Playwright) | High | qa-test-automation | ongoing |
| AN026 + AN027 retained as staging de-installed fixtures; production never sees them | Low | runtime-pm | 2026-05-12, unchanged |

**Closed since prior snapshot (2026-05-24):**
- `cmc_contracts` UNIQUE(sn) constraint — applied to both environments; `L-DBPM-005` closed.
- Manager XLSX gate — now uses `canManagePM()`; `L-RTI-008` closed.
- PR #25 and #28 — closed (superseded).
- Test matrix extended to 74 checks per run (PD-006/007 shipped in v1.5.2).

---

## Stale assumptions (re-verify before relying)

| Item | Last verified | When to re-verify |
|---|---|---|
| Staging row counts | 2026-05-21 | After any SQL applied or significant time passes |
| Production row counts | 2026-05-21 | After any SQL applied or significant time passes |
| Production V2 missing code | 2026-05-12 (AN025 backfilled; none missing since) | If V2 baseline changes |
| Production Pages content | 2026-05-24 (commit `4581fae`, APP_VERSION=1.5.2) | After any future deploy |
| GitHub Actions Pages workflow | 2026-05-24 (run `26361036755`, success) | Before next production deploy |

---

## Recent state changes since last snapshot

(This section is overwritten on each snapshot. Older entries archive into a future `automation/STATE_HISTORY.md` if needed.)

- **2026-05-24 (this session):**
  - `4581fae` — `release: v1.5.2` — Manager XLSX gate (`canManagePM()`), `cmc_contracts` UNIQUE(sn) constraint confirmed, test matrix extended to 74 checks (PD-006/PD-007).
  - `ba2351b` — `fix(ux): PD-003/008/010/011/012` — UX polish bundle (v1.5.3): toast warning duration, page-header CSS, AMC filter chips, expired tile CTA, PM empty state. **On staging only — not yet in production.**
  - v1.5.2 deployed to production via `git push origin 4581fae:main` + `gh workflow run pages-deploy.yml --ref main` (run `26361036755`).
  - Production matrix 74/74, 0 JS errors across all 3 roles.
  - Tag `v1.5.2` created on `4581fae`, pushed to origin.
  - PRs #25 and #28 closed.
  - STATE.md refreshed to current truth.

---

## Update protocol

This file is updated by `fieldops-automation-memory-agent` after:
- Any commit on a tracked branch.
- Any PR open / mark-ready / merge.
- Any SQL apply (paste-back captured).
- Any deploy.
- Any specialist agent PASS/STOP for a tracked artifact.
- Any operator approval phrase issued.

Each update overwrites the relevant section. Append-only audit history (full chat transcripts, specialist findings) lives in chat / PR comments / commit messages — NOT in this file. This file is the *current cache*, not the audit chain.

If two agents disagree about state (e.g., orchestrator says "staging at 0004" but runbook-verifier says "0004 not applied yet"), the memory agent flags `INCONSISTENT` and ESCALATEs to the operator before any further action.
