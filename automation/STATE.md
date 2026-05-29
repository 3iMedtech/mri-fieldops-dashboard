# FieldOps3i — Persistent State Snapshot

**Owner:** `fieldops-automation-memory-agent`
**Updated by:** operator-approved commit, with content drafted by `fieldops-automation-memory-agent` at verified gates. The agent does not directly commit state changes.
**Read by:** every agent at session start (especially the Delivery Orchestrator and the three PMs).
**Authority:** advisory snapshot. The repository + Supabase are the truth; this file is the cache.
**Scope:** *current truth* (PRs, branches, environment state, open gates, stale assumptions). For *durable lessons*, see [`memory/MEMORY_PROTOCOL.md`](memory/MEMORY_PROTOCOL.md), [`memory/GLOBAL_LESSONS.md`](memory/GLOBAL_LESSONS.md), and [`memory/tracks/`](memory/tracks).

If this file disagrees with `git log` / `gh pr list` / Supabase, the repo and Supabase win — and the disagreement itself is a finding the memory agent must surface (`STALE` or `INCONSISTENT`).

---

## Last verified

- **Snapshot timestamp:** 2026-05-29 (v1.6.1 on production at `203e757`; staging at `daf7785` — model fix not yet in production)
- **Snapshot author:** Claude (Opus) acting as automation-memory-agent

---

## Branch + commit

- **Canonical branch:** `main`
- **Latest commit on `main`:** `203e757` — STATE.md doc update (v1.6.1 production verification)
- **Latest commit on `staging`:** `daf7785` — `fix: persist asset model on app-created service work orders` — **staging is 1 commit ahead of main**
- **Latest git tag:** `v1.6.1` (annotated, `b0abbff`) — aligned with `APP_BUILD.tag`. Intermediate v1.5.7 / v1.5.8 / v1.5.9 / v1.6.0 were folded into the v1.6.1 production release and intentionally not tagged separately. Previous tag: `v1.5.3` (`ba2351b`).
- **Working tree:** clean

---

## Open PRs

No open PRs.

---

## Recently shipped to staging → main (since v1.5.3)

All shipped directly on the `staging` branch, then fast-forwarded to `main`. Production jumped v1.5.5 → v1.6.1 in a single deploy on 2026-05-29.

| Commit | Description |
|---|---|
| `e2a6235` | v1.6.0 — WO workflow fixes: multi-field search, engineer execution, sub-WO visibility, parent-close guard, productivity tracking |
| `01f0760` | v1.5.7 — engineer WO execution: add ENG010 record for engineer@3imedtech.com (migration 0017) |
| `20f93d5` | v1.5.7 — field guard allows `sys_status` at resolution/closure (migration 0018) |
| `5573e41` | v1.5.8 — realtime WO visibility (`app_tickets` added to publication) + visit log in service history |
| `16e711e` | v1.5.9 — edit asset: overlay was discarding DB edits for XLSX codes |
| `b29dae9` | release: v1.6.1 — asset edit, visit log, contract renewal, engineer WO execution |
| `181e3d5` | fix: contract renewal view refresh (`renderContracts()` after `renderAll()`) + open-WO visits in service history |

---

## Staging Supabase state

- **Project:** `fieldops-staging` · **URL ref:** `qupkpprptopyejbnslev` · **Org:** Abhijit Sen (FREE)
- **Migrations present in repo:** 0009–0019 (latest: 0017 ENG010, 0018 field-guard-allow-sys_status, 0019 sub-WO RLS correlation fix).
- **Applied to staging:** through 0019, plus `app_tickets` added to `supabase_realtime` publication (v1.5.8).
- **Row counts (verified 2026-05-29):** `engineers`: **10** (now includes ENG010 Demo Engineer). Other counts (`config_assets` 27, `pm_schedule` 22, `cmc_contracts` 13) carried from 2026-05-21 — re-verify.
- **`asset_lifecycle` + `renew_asset_lifecycle` RPC:** present; renewals write active rows (verified 2026-05-29: AN001/AN005/AN012 etc.).
- **Edge function `notify-work-order`:** dormant — SMTP secrets never configured; app uses mailto:.

---

## Staging Pages state

- **URL:** `https://3imedtech.github.io/mri-fieldops-dashboard/staging/index.html`
- **Currently served commit:** `181e3d5` · **APP_VERSION:** `1.6.1`
- **Matrix:** 74/74, 0 failures, 0 JS errors (2026-05-29)

---

## Production Supabase state

- **URL ref:** `mvwhubatooliudbvythy`
- **Aligned 2026-05-29** to support the v1.5.7–v1.6.1 bundle. Four changes applied this date:
  1. `ALTER PUBLICATION supabase_realtime ADD TABLE public.app_tickets` (was missing — v1.5.8 engineer live WO visibility).
  2. Migration 0017 — inserted ENG010 engineer record (was missing).
  3. Migration 0018 — `_app_ticket_engineer_field_guard` no longer blocks `sys_status` (was old version).
  4. Migration 0016 then 0019 — sub-WO insert policy corrected. 0016's fix was a no-op (unqualified `parent_id` bound to subquery alias); 0019 qualifies it as `app_tickets.parent_id`. Verified on prod: engineer sub-WO insert allowed for valid open parent, denied for invalid.
- **Pre-existing in prod:** `asset_lifecycle` table, `renew_asset_lifecycle` RPC, `app_tickets.visit_log` column, migrations 0001–0015.
- **Row counts (verified 2026-05-29):** `engineers`: **10** (ENG010 added). Others carried from 2026-05-21 — re-verify.

---

## Production Pages state

- **URL:** `https://3imedtech.github.io/mri-fieldops-dashboard/`
- **Currently served commit:** `181e3d5` · **APP_VERSION:** `1.6.1`
- **Pages workflow run (latest):** `26618021854` — manual dispatch from `main`, completed/success, 2026-05-29.
- **Matrix:** `scripts/test-matrix.js production 1.6.1` → 74/74, 0 failures, 0 JS errors, all 3 roles (2026-05-29; **re-verified 2026-05-29** post-tag — identical result). Engineer login verified with prod credentials; 10 engineer cards. APP_VERSION=1.6.1 confirmed on Admin/Manager/Engineer.

---

## App runtime state

- **APP_VERSION on production:** `1.6.1` · **on staging:** `1.6.1`
- **Version constants on `main` (181e3d5):** `window.APP_VERSION = '1.6.1'`; `window.APP_BUILD = { version:'1.6.1', released:'2026-05-29', tag:'v1.6.1' }`; `const APP_VERSION = '1.6.1'`; `const APP_RELEASE_DATE = '29 May 2026'`.

---

## Open approval gates (operator phrase needed)

| Gate | Phrase needed |
|---|---|
| Configure Zoho SMTP secrets to activate server-side WO email | Operator sets secrets in Supabase dashboard |

No code deploy gates open. Staging and production in sync at v1.6.1.

---

## Open risks

| Risk | Severity | Recorded at |
|---|---|---|
| No automated tests in repo (only manual matrix + ad-hoc Playwright). | High | ongoing |
| `notify-work-order` edge function deployed but SMTP secrets not configured. | Low | app uses mailto: now; edge fn dormant |
| AN026 + AN027 retained as staging de-installed fixtures; production never sees them. | Low | 2026-05-12 |

---

## Stale assumptions (re-verify before relying)

| Item | Last verified | When to re-verify |
|---|---|---|
| Staging/production row counts (except `engineers`=10) | 2026-05-21 | After any SQL applied or significant time passes |
| Production Pages content | 2026-05-29 (`181e3d5`, APP_VERSION=1.6.1) | After any future deploy |
| Sub-WO engineer INSERT behavior | 2026-05-29 (FIXED by 0019; verified allow/deny on staging + prod) | If sub-WO RLS policy changes again |

---

## Recent state changes since last snapshot

(This section is overwritten on each snapshot.)

- **2026-05-29 (this session):**
  - `b29dae9` — `release: v1.6.1`.
  - `181e3d5` — `fix: contract renewal view refresh + open-WO visits in service history` (Bug 1: `renderContracts()` after `renderAll()`; Bug 2: include open WOs with visits in Service History).
  - Both bug fixes verified live on staging (renewal persists + re-renders for Admin & Manager; visit log visible in Service History for all 3 roles).
  - Production DB aligned (realtime publication, ENG010, field guard 0018, sub-WO policy).
  - `main` fast-forwarded `0f84cd2 → 181e3d5`; Pages deploy run `26618021854` success.
  - Staging matrix 74/74 and production matrix 74/74 (0 failures) on 2026-05-29.
  - **Discovered + fixed:** migration 0016 sub-WO fix was a no-op on both environments (unqualified `parent_id` bound to subquery alias). Migration `0019` qualifies it as `app_tickets.parent_id`; applied + verified (allow valid / deny invalid) on staging AND production. DB-only — no redeploy.
  - `main` fast-forwarded to `b0abbff` (STATE.md + migration 0019); annotated tag `v1.6.1` created on `b0abbff` and pushed. `main` later levelled to `203e757` (STATE.md doc).
  - Production matrix re-run post-tag: 74/74, 0 failures, 0 JS errors, APP_VERSION=1.6.1 on all 3 roles — production stable.
  - **New bug fixed (staging only):** app-created service WOs stored `model = NULL` — `submitNewTicket()` never included `model` in the `dbSaveAppTicket()` payload. Root cause confirmed live: 32/33 app-created service WOs missing model vs 0/17 XLSX rows. Fix: derive model from selected asset (`data-model` attribute, fallback `CONFIG_ASSETS` lookup) and include in insert payload. Commit `daf7785` on `staging`; deployed + verified all 3 roles on live staging — model stored in DB and rendered in Service History. Staging matrix 74/74 (0 failures). **Not yet deployed to production — awaiting approval phrase.**
  - **Staging DB backfill:** 20 pre-existing app-created service WOs backfilled with model via `UPDATE app_tickets SET model = config_assets.model WHERE asset_code matches`. 8 rows remain NULL (unrecognised/manual asset codes — no source data). DB-only, no redeploy.

---

## Update protocol

This file is updated by `fieldops-automation-memory-agent` after: any commit on a tracked branch; any PR open/mark-ready/merge; any SQL apply; any deploy; any specialist PASS/STOP; any operator approval phrase. Each update overwrites the relevant section. Append-only audit history lives in chat / PR comments / commit messages — NOT here. If two agents disagree about state, the memory agent flags `INCONSISTENT` and ESCALATEs to the operator before further action.
