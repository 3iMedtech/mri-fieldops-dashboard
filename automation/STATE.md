# FieldOps3i — Persistent State Snapshot

**Owner:** `fieldops-automation-memory-agent`
**Updated by:** operator-approved commit, with content drafted by `fieldops-automation-memory-agent` at verified gates. The agent does not directly commit state changes.
**Read by:** every agent at session start (especially the Delivery Orchestrator and the three PMs).
**Authority:** advisory snapshot. The repository + Supabase are the truth; this file is the cache.
**Scope:** *current truth* (PRs, branches, environment state, open gates, stale assumptions). For *durable lessons*, see [`memory/MEMORY_PROTOCOL.md`](memory/MEMORY_PROTOCOL.md), [`memory/GLOBAL_LESSONS.md`](memory/GLOBAL_LESSONS.md), and [`memory/tracks/`](memory/tracks).

If this file disagrees with `git log` / `gh pr list` / Supabase, the repo and Supabase win — and the disagreement itself is a finding the memory agent must surface (`STALE` or `INCONSISTENT`).

---

## Last verified

- **Snapshot timestamp:** 2026-05-21 (WO email notification shipped to production; test-matrix XLSX fix deployed; staging and main fully in sync)
- **Snapshot author:** Claude (acting as automation-memory-agent)

---

## Branch + commit

- **Canonical branch:** `main`
- **Latest commit on `main`:** `7f8ab60` — `fix(test): correct XLSX button text filter in test-matrix.js`
- **Latest commit on `staging`:** `7f8ab60` — same; **staging and main are fully in sync**
- **Latest tag:** `v1.4.1` (annotated, tag object `59a5da6`) — ⚠️ NO v1.5.x tag created yet. `APP_BUILD.tag` references `'v1.5.1'` in index.html but that git tag does not exist. Tag should be created before the next release cycle.
- **Previous tag:** `v1.4.0.1`
- **Working tree:** clean

---

## Open PRs

| # | Title | State | Draft | Head branch | Owner verdict |
|---|---|---|---|---|---|
| 25 | Draft: v1.4.1 Phase 1 production-apply runbook (review-only) | OPEN | YES | `docs/v1.4.1-phase1-production-runbook` | **Stale** — superseded by Phase 2 ship (2026-05-13). Operator decision pending: close or leave for archival. Not blocking any work. |
| 28 | Draft: v1.4.2 technical design | OPEN | YES | `feat/v1.4.2-technical-design` | **Stale** — opened 2026-05-13; v1.4.2 through v1.5.1 have since shipped on `staging`/`main` without this branch. Likely superseded. Operator decision pending: close or archive. |

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
- **Currently served commit:** `7f8ab60`
- **APP_VERSION:** `1.5.1`

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
- **Currently served commit:** `7f8ab60` — `fix(test): correct XLSX button text filter in test-matrix.js`
- **APP_VERSION:** `1.5.1`
- **Pages workflow run (latest):** `26230984781` — manual dispatch from `7f8ab60`, completed/success, 2026-05-21
- **Previous deploy:** `26229727431` — WO email notification + version metadata (cf8c6bc), 2026-05-21

---

## App runtime state

- **APP_VERSION on production:** `1.5.1`
- **APP_VERSION on staging:** `1.5.1`
- **Latest git tag:** `v1.4.1` — ⚠️ no v1.5.x tag created. `APP_BUILD.tag = 'v1.5.1'` in index.html is forward-declared; the actual git tag must still be created.
- **`index.html` on `main`:** all four version constants aligned:
  - `window.APP_VERSION = '1.5.1'`
  - `window.APP_BUILD = { version: '1.5.1', released: '2026-05-20', tag: 'v1.5.1' }`
  - `const APP_VERSION = '1.5.1'`
  - `const APP_RELEASE_DATE = '20 May 2026'`

---

## Production runtime smoke (2026-05-21)

Automated test matrix (`scripts/test-matrix.js production`) ran post-deploy on 2026-05-21 against commit `7f8ab60`. **59/59 checks passed, 0 JS errors across all 3 roles.**

| Role | Result |
|---|---|
| Admin | PASS — 21/21. APP_VERSION=1.5.1, role=admin, body=superadmin-mode, KPIs loaded, Contracts/PM/Engineers tabs functional, XLSX button visible, 0 JS errors. |
| Manager | PASS — 21/21. APP_VERSION=1.5.1, role=manager, body=viewer-mode manager-mode, KPIs loaded, Contracts/PM/Engineers tabs functional, XLSX button visible, 0 JS errors. |
| Engineer | PASS — 17/17. APP_VERSION=1.5.1, role=viewer, body=viewer-mode, Contracts nav hidden, Renew buttons absent, XLSX hidden, PM read-only, Engineers tab visible (read-only), 0 JS errors. |

WO email notification feature additionally verified via Playwright (all 3 roles, 25 checks, 0 failures) — see 2026-05-21 session for full detail.

---

## Open approval gates (operator phrase needed)

**No open forward gates.** v1.5.1 is fully shipped and in sync on staging + production.

### Optional follow-up actions (operator-discretion)

| Suggestion | Phrase needed |
|---|---|
| Create missing `v1.5.1` git tag | `approved, tag v1.5.1` |
| Close stale PR #25 (v1.4.1 Phase 1 runbook) | `approved, close PR #25` |
| Close stale PR #28 (v1.4.2 technical design) | `approved, close PR #28` |
| Configure Zoho SMTP secrets in Supabase to activate server-side WO email | Operator sets `ZOHO_SMTP_USER`, `ZOHO_SMTP_PASS`, `ALERT_FROM`, `WO_NOTIFY_CC` in Supabase dashboard |

---

## Open risks

| Risk | Severity | Owner | Recorded at |
|---|---|---|---|
| No `v1.5.1` git tag — `APP_BUILD.tag` references it but tag doesn't exist | Medium | release-pm | 2026-05-21 |
| PR #25 stale (v1.4.1 Phase 1 runbook — superseded) | Low | release-pm | 2026-05-13, unchanged |
| PR #28 stale (v1.4.2 technical design — superseded by direct staging work) | Low | release-pm | 2026-05-21 |
| `cmc_contracts` UNIQUE constraint on `sn` not yet applied — safe-upsert deferred | Medium | database-pm | `L-DBPM-005` |
| Manager XLSX gate remains admin-only until `cmc_contracts` UNIQUE constraint ships | Medium | runtime-pm | `L-RTI-008` |
| `notify-work-order` edge function deployed but SMTP secrets not configured — will always fail if invoked directly | Low | runtime-pm | 2026-05-21 (app uses mailto: now; edge fn dormant) |
| No automated tests in repo (only manual matrix + ad-hoc Playwright) | High | qa-test-automation | ongoing |
| AN026 + AN027 retained as staging de-installed fixtures; production never sees them | Low | runtime-pm | 2026-05-12, unchanged |

**Closed since prior snapshot:**
- `APP_VERSION` / `APP_BUILD` / `VERSION` file misalignment — all four constants now aligned at `1.5.1` (`34bc689`).
- WO email notification silently auto-firing and failing — replaced with opt-in mailto: flow (`cf8c6bc`).
- Test matrix XLSX button false failure — test text filter fixed (`7f8ab60`).

---

## Stale assumptions (re-verify before relying)

| Item | Last verified | When to re-verify |
|---|---|---|
| Staging row counts | 2026-05-21 | After any SQL applied or significant time passes |
| Production row counts | 2026-05-21 | After any SQL applied or significant time passes |
| Production V2 missing code | 2026-05-12 (AN025 backfilled; none missing since) | If V2 baseline changes |
| Production Pages content | 2026-05-21 (commit `7f8ab60`, APP_VERSION=1.5.1) | After any future deploy |
| GitHub Actions Pages workflow | 2026-05-21 (2 successful runs today: staging + production) | Before next production deploy |

---

## Recent state changes since last snapshot

(This section is overwritten on each snapshot. Older entries archive into a future `automation/STATE_HISTORY.md` if needed.)

- **2026-05-21 (this session):**
  - `34bc689` — `chore: align version metadata to v1.5.1`. VERSION file was stale (1.4.1); APP_BUILD still referenced v1.5.0. All four version constants now aligned.
  - `cf8c6bc` — `feat: WO creation email notification via mailto (opt-in)`. Replaced broken edge-function auto-fire (SMTP never configured — 6 failed attempts) with opt-in mailto: approach matching PM reminder pattern. Reuses `PM_REMINDER_CC`. Detail modal opens automatically after WO creation. Playwright-verified across all 3 roles.
  - `7f8ab60` — `fix(test): correct XLSX button text filter in test-matrix.js`. Test looked for "Upload XLSX" but button label is "XLSX". Pre-existing false failure since button was renamed.
  - All 3 commits deployed to production. Matrix 59/59, 0 JS errors.
  - STATE.md refreshed to current truth (this commit).

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
