# FieldOps3i — Persistent State Snapshot

**Owner:** `fieldops-automation-memory-agent`
**Updated by:** operator-approved commit, with content drafted by `fieldops-automation-memory-agent` at verified gates. The agent does not directly commit state changes.
**Read by:** every agent at session start (especially the Delivery Orchestrator and the three PMs).
**Authority:** advisory snapshot. The repository + Supabase are the truth; this file is the cache.
**Scope:** *current truth* (PRs, branches, environment state, open gates, stale assumptions). For *durable lessons*, see [`memory/MEMORY_PROTOCOL.md`](memory/MEMORY_PROTOCOL.md), [`memory/GLOBAL_LESSONS.md`](memory/GLOBAL_LESSONS.md), and [`memory/tracks/`](memory/tracks).

If this file disagrees with `git log` / `gh pr list` / Supabase, the repo and Supabase win — and the disagreement itself is a finding the memory agent must surface (`STALE` or `INCONSISTENT`).

---

## Last verified

- **Snapshot timestamp:** 2026-05-12 (Phase 2 v1.4.1 production smoke PASS at production-served `cb6fa19` runtime via merge commit `0c4e9d1`)
- **Snapshot author:** Claude (acting as Delivery Orchestrator + Runtime PM + Database PM + Release PM + QA + automation-memory)

---

## Branch + commit

- **Canonical branch:** `main`
- **Latest commit on `main`:** `0c4e9d1` — `Merge PR #27: v1.4.1 Phase 2 runtime implementation`
- **Production-deployed runtime payload:** `index.html` at `cb6fa19` content (B5.6) — commits after `cb6fa19` are docs/memory/runbook only
- **Retained feature branch (post-merge):** `feat/v1.4.1-phase2-impl` head `dcd0367` (kept per `gh pr merge --delete-branch=false`)
- **Retained governance branch:** `feat/v1.4.1-phase2-review` head `62c5018` (now MERGED via PR #27 ancestry)
- **Working tree:** clean (as of last verified snapshot)

---

## Open PRs

| # | Title | State | Draft | Head branch | Latest commit | Owner verdict |
|---|---|---|---|---|---|---|
| 25 | Draft: v1.4.1 Phase 1 production-apply runbook (review-only) | OPEN | YES | `docs/v1.4.1-phase1-production-runbook` | `d59f41b` | Phase 2 production discussion now complete; PR #25 may be revisited or closed separately — operator-deferred |

---

## Recently merged

| # | Merged at | Merge SHA | Note |
|---|---|---|---|
| 27 | 2026-05-12T14:32:18Z | `0c4e9d1` | v1.4.1 Phase 2 runtime implementation. 34 files / +7,797 / −70 lines. Brought B1..B5.6 runtime + 0004/0005 migrations + Phase 2 docs + agent definitions + memory system into main. |
| 26 | (auto-marked merged via PR #27 ancestry path) | n/a (no separate merge commit) | Phase 2 review package. Its branch (`feat/v1.4.1-phase2-review` head `62c5018`) was an ancestor of `feat/v1.4.1-phase2-impl`, so PR #27's merge brought its content onto main; GitHub auto-marked PR #26 MERGED. |
| 24 | (Phase 1 ship) | `8c54334` | Phase 1 schema + helpers + RLS + user_roles seed; recursion-fix baked in |

---

## Staging Supabase state

- **Project:** `fieldops-staging`
- **URL ref:** `qupkpprptopyejbnslev`
- **Org:** Abhijit Sen (FREE)
- **Last verified:** 2026-05-11 (B6 Session C pre-flight SQL PASS; Session I final baseline confirmation)
- **Migrations applied:** 0001, 0002, 0003 (Phase 1), 0004 (Phase 2 additive write policies, 2026-05-10), 0005 (Phase 2 IB master backfill, 2026-05-10 09:36:55 UTC). All operator-applied + verified per `L-DBPM-001` / `L-REC-001`.
- **Row counts (last verified 2026-05-11, B6 Session I):**
  - `config_assets`: **27** (25 active + 2 de-installed; baseline = 25 V2 codes after 0005 backfill + 2 app-created test fixtures AN026/AN027 retained as staging-only)
  - `config_assets` active: 25
  - `config_assets` de-installed: 2 (AN026, AN027 — staging fixtures; production never sees them)
  - `pm_schedule`: 22
  - `cmc_contracts`: 13
  - `audit_log`: ≥ 1500+
  - `user_roles`: 3 (admin / manager / viewer)
  - `asset_lifecycle`: 0
  - `asset_lifecycle_history`: 6 (3 events each for AN026 + AN027)
- **Helpers + policies + V2 fingerprint:** same as Phase 1 / earlier snapshot — see `automation/memory/tracks/database-track.md` for full reconciliation.

---

## Staging Pages state

- **Staging Pages URL:** `https://3imedtech.github.io/mri-fieldops-dashboard/staging/index.html`
- **Currently served commit:** `cb6fa19` (B5.6)
- **content-length:** 629,540 B (byte-identical to local `index.html` at `cb6fa19`)
- **etag:** `"6a01a200-99b24"`
- **Deploy authorization phrases consumed:** `approved, deploy 5d33f8c to staging`, `approved, deploy d61e907 to staging`, `approved, deploy cb6fa19 to staging`

---

## Production Supabase state

- **Last verified:** 2026-05-12 (operator-applied SQL Gate B PASS + production runtime smoke PASS as indirect confirmation that `app_can_write()` / `app_user_role()` resolve correctly)
- **Migrations applied:** 0001, 0002, 0003 (Phase 1), **0004 (Phase 2 additive write policies, 2026-05-12)**, **0005 (Phase 2 IB master backfill, 2026-05-12)**. Operator-applied per `docs/v1.4.1_phase2_production_apply_runbook.md` §6-§9.
- **Row counts (operator-asserted post-Gate-B):**
  - `config_assets`: **25** (active=25, de_installed=0 — no staging fixtures on production)
  - `pm_schedule`: 22
  - `cmc_contracts`: 13
  - `asset_lifecycle`: 0
  - `asset_lifecycle_history`: 0 (no lifecycle activity on production yet; future de-installs / renews will populate)
  - `user_roles`: 3 (admin / manager / viewer, verified by Gate A pre-flight query B)
- **AN025 backfill row (production):** `AN025 | KVC Diagnostics | Mysore | KA | 1.5T | Philips 1.5 T Achieva | active | CDAS 16CH | 281 | R5.7.1 | HC-8E | F2000 | note='v1.4.1 phase 2 install_base_v2 backfill'` — verified by runbook §9.2.
- **Helpers present (5):** same as staging — `app_user_role` / `app_can_write` / `app_is_admin` / `_other_active_admin_exists` / `_user_roles_block_last_admin_delete` (SECURITY DEFINER + locked search_path; verified by Gate A query A).
- **v141_* lifecycle-table policies:** 11 (from 0003).
- **v141_*_app_can_write policies on legacy tables:** 6 (3 INSERT + 3 UPDATE from 0004).
- **Legacy admin_* policies on 4 legacy tables:** 16 (unchanged).
- **V2 fingerprint:** `965ffcec48aa3ddfbfb7b975bc48dca9` (operator-verified equal to staging by runbook §5.4 query E3).
- **V2 missing code on production at pre-flight:** was `AN025` (matched staging; verified by runbook §5.4 query E); now backfilled.

---

## Production Pages state

- **Production Pages URL:** `https://3imedtech.github.io/mri-fieldops-dashboard/`
- **Currently served commit:** main HEAD `0c4e9d1` (merge of PR #27). The served `index.html` content is byte-identical to the runtime payload at `cb6fa19` (commits after `cb6fa19` are docs/memory/runbook only).
- **etag:** `"6a033a22-99b24"` (was `*-8f1c6` pre-Phase-2)
- **content-length:** 629,540 B (was 586,182 B pre-Phase-2 — matches `releases/v1.4.0.1/index.html`). **Old baseline 586,182 is no longer served.**
- **last-modified:** Tue, 12 May 2026 14:33:06 GMT
- **Most recent Pages workflow:** run `25741285166` — completed/success in 47s, push event from the merge commit (2026-05-12T14:32:24Z).
- **Deploy authorization phrases consumed:** `approved, deploy cb6fa19 to production` (Gate C — coupled to the merge mechanism), `approved, mark PR #27 ready` (Gate D), `approved, merge PR #27` (Gate E — actual deploy trigger via `pages-deploy.yml on: push: branches: [main]`).

---

## App runtime state

- **APP_VERSION on production:** `1.4.0.1` (label intentionally lags runtime payload until Gate F bumps `VERSION` / `CHANGELOG.md` / `releases/v1.4.1/MANIFEST.txt` / the `APP_VERSION` constant — see `L-RPM-005`).
- **APP_VERSION on staging:** `1.4.0.1` (same reasoning).
- **Latest tag:** `v1.4.0.1` (the `v1.4.1` tag is not yet created — pending Gate F).
- **`index.html` content on main:** the Phase 2 runtime payload from `cb6fa19` (B1 RPC integration + B2 allowlist removal + B3 onAuthStateChange refresh + B4 XLSX safe upsert + B5.0 V2 overlay fix + B5.1..B5.4 lifecycle UI + B5.5 status visibility + B5.6 column simplification).

---

## Production runtime smoke (2026-05-12)

Browser-driven smoke verification per `docs/v1.4.1_phase2_production_apply_runbook.md` §12. All gates PASS.

| Gate | Result |
|---|---|
| §A Pre-login payload | PASS — APP_VERSION="1.4.0.1", APP_BUILD.tag="v1.4.0.1", supabase client loaded, login screen renders |
| §B Admin / Superadmin | PASS — `client_userRole="admin"`, RPC 200/"admin", `app_can_write=true`, `app_is_admin=true`, `superadmin_mode=true`, IB=25 systems (AN001..AN025), de_installed=0, Add/Edit/De-install/History visible, Audit Log opens with 500 rows, Upload XLSX visible, no FieldOps app-code errors |
| §C Manager | PASS — `client_userRole="manager"` (Phase 1.5 gap CLOSED on production), RPC 200/"manager", `bodyClasses="viewer-mode manager-mode"`, `manager_mode=true`, `superadmin_mode=false`, `can_manage_pm=true`, IB=25 systems, Add/Edit/De-install/History visible, **Upload XLSX hidden** (`L-RTI-008`), **Audit Log nav hidden + route-gated** (direct `location.hash='#/auditlog'` redirected to Dashboard without rendering audit table), no FieldOps app-code errors |
| §D Engineer / Viewer | PASS — `client_userRole="viewer"`, RPC 200/"viewer", `app_can_write=false`, `app_is_admin=false`, `bodyClasses="viewer-mode"` only, `can_manage_pm=false`, IB=25 systems, **Edit/De-install hidden via `.mgr-plus` CSS** (DOM contains buttons for defense-in-depth; `getBoundingClientRect`/`getComputedStyle` report `visible=false`), Add Asset hidden, History visible (read-only all-roles per `L-RTI-004`), Upload XLSX hidden, Audit Log hidden, no FieldOps app-code errors |
| §E RPC failure path (security) | PASS — Manager with `app_user_role` RPC blocked via JS-level fetch interceptor degraded to `_userRole="viewer"`, `manager_mode=false`, `superadmin_mode=false`, `can_manage_pm=false`; **no non-admin role escalated to admin** (`L-RTI-007`). Interceptor uninstalled cleanly; Manager recovered to `_userRole="manager"` after RPC restored + `applyRoleRestrictions()` re-run. |

Console: aggregate ~40 exceptions across all role sessions, **all** matching the browser-extension async-listener pattern (`"A listener indicated an asynchronous response by returning true, but the message channel closed before a response was received"`) — explicitly in the ignore list. **Zero** Uncaught TypeError / Uncaught ReferenceError / SyntaxError / FieldOps app-code errors.

---

## Open approval gates (operator phrase needed)

| Gate | Phrase needed | Status |
|---|---|---|
| Phase 2 staging SQL apply (0004 + 0005) | `approved, apply phase 2 to staging` | **CONSUMED** 2026-05-10 |
| Phase 2 runtime impl on `feat/v1.4.1-phase2-impl` | `approved, begin runtime track B implementation on feat/v1.4.1-phase2-impl` | **CONSUMED** 2026-05-10 |
| Phase 2 staging runtime deploys | `approved, deploy <commit> to staging` | **CONSUMED 3×** (5d33f8c, d61e907, cb6fa19) |
| Test asset create on staging (TEST-IB-AAA) | `approved, create TEST-IB-AAA on staging` | **CONSUMED** 2026-05-11 |
| Test asset cleanup on staging (TEST-IB-AAA) | `approved, cleanup TEST-IB-AAA on staging` | **CONSUMED** 2026-05-11 |
| Documentation/memory commit after B6 | `commit STATE.md + memory updates after B6` | **CONSUMED** 2026-05-11 (`5cde80b`) |
| Production runbook drafting | `approved, draft production runbook for phase 2` | **CONSUMED** 2026-05-12 (`dcd0367`) |
| Production SQL pre-flight | `approved, run production SQL pre-flight for phase 2` | **CONSUMED** 2026-05-12 (Gate A) |
| Phase 2 production SQL apply (0004 + 0005) | `approved, apply phase 2 to production` | **CONSUMED** 2026-05-12 (Gate B) |
| Phase 2 production runtime deploy | `approved, deploy cb6fa19 to production` | **CONSUMED** 2026-05-12 (Gate C — coupled to merge) |
| PR #27 mark ready | `approved, mark PR #27 ready` | **CONSUMED** 2026-05-12 (Gate D) |
| PR #27 merge | `approved, merge PR #27` | **CONSUMED** 2026-05-12 (Gate E — merge commit `0c4e9d1`) |
| Documentation/memory commit after production smoke | `commit STATE.md + memory updates after production smoke PASS` | **CONSUMED** 2026-05-12 (this commit) |
| Tag for Phase 2 release | `approved, tag v1.4.1` | **PENDING** (Gate F — next forward gate) |
| PR #26 mark ready | `approved, mark PR #26 ready` | **N/A** (PR #26 auto-merged via PR #27 ancestry; no separate ready toggle needed) |
| PR #26 merge | `approved, merge PR #26` | **N/A** (see above) |

---

## Open risks

| Risk | Severity | Owner | Recorded at |
|---|---|---|---|
| `APP_VERSION` label lags runtime payload — production reports `"1.4.0.1"` while serving Phase 2 runtime; resolved by Gate F | Low (documented intermediate state per `L-RPM-005`) | release-pm | 2026-05-12 |
| Merged PR #27 title still carries `"Draft:"` prefix (cosmetic; not edited because PR-metadata edits were not separately authorized) | Low (cosmetic) | release-pm | 2026-05-12 |
| Realtime CHANNEL_ERROR warnings on `_RT_TABLES` (tickets, pm_schedule, engineers, cmc_contracts, ambiguities) — did not surface in 2026-05-12 production smoke window but observed on staging during B6 | Low (single-user UX unaffected) | runtime-pm | B6 Session O; not observed on 2026-05-12 production smoke |
| 43 ambiguity flags auto-detected during B6 X2 XLSX upload (staging) — staging-only artefact; production XLSX upload not exercised yet | Low | runtime-pm + test-agent | B6 Session X 2026-05-11 |
| `cmc_contracts` XLSX safe-upsert deferred to v1.4.2 — needs UNIQUE constraint on `sn` via separate migration | Medium | database-pm | B4-partial / `L-RTI-008` |
| AN026 + AN027 retained as staging de-installed fixtures; production never sees them (verified by Gate A query E2) | Low | runtime-pm | 2026-05-12 production smoke |
| Renew RPC `0006_*` not authored; Renew button intentionally deferred to second impl PR | Medium | database-pm | round-1 review M2 |
| No automated tests in repo (Tier 1-5 PLANNED; only Tier 6 manual matrix operational) | High | qa-test-automation | round-2 audit |
| No tag yet — production runtime is live but `v1.4.1` tag, `VERSION` / `CHANGELOG.md` / `releases/v1.4.1/MANIFEST.txt` artifacts are not yet authored | Medium (Gate F's known scope) | release-pm | 2026-05-12 |

---

## Stale assumptions (re-verify before relying)

| Item | Last verified | When to re-verify |
|---|---|---|
| Production row counts | 2026-05-12 (operator-asserted post-Gate-B; indirectly confirmed by runtime smoke role-resolution) | If future SQL is applied or significant time passes |
| Production V2 missing code | 2026-05-12 (was `AN025`; now backfilled per `L-REC-001`) | invariant unless V2 baseline changes |
| Production Pages content + etag | 2026-05-12 14:33 UTC (etag `"6a033a22-99b24"`, content-length 629,540) | Re-verify after any future deploy |
| GitHub Actions Pages workflow correctness | 2026-05-12 (4th successful run since OS upgrade: staging x3 + production merge x1) | Before next production deploy or workflow change |
| Daily-alerts cadence | implicit | Weekly |

---

## Recent state changes since last snapshot

(This section is overwritten on each snapshot. Older entries archive into a future `automation/STATE_HISTORY.md` if needed.)

- **2026-05-11:** Phase 2 staging acceptance COMPLETE. Documentation/memory commit `5cde80b` recorded B6 PASS + 5 lessons (`L-DO-005`, `L-RTI-005..008`, `L-SQL-005`).
- **2026-05-12:** Production runbook drafted at `dcd0367` (1,159 lines, `docs/v1.4.1_phase2_production_apply_runbook.md`). PR #27 still DRAFT at this point.
- **2026-05-12:** Gate A production SQL pre-flight PASS (operator-applied; 11 queries verified per runbook §5).
- **2026-05-12:** Gate B production SQL apply PASS — 0004 + 0005 applied + verified on production. AN025 / KVC Diagnostics backfilled.
- **2026-05-12:** Gate D PR #27 marked ready (DRAFT → ready-for-review; head still `dcd0367`; no SHA change).
- **2026-05-12:** Gate E PR #27 merged into main via `gh pr merge 27 --merge --delete-branch=false --subject "Merge PR #27: v1.4.1 Phase 2 runtime implementation"`. Merge commit `0c4e9d1`. Feature branch retained at `dcd0367` on origin. PR #26 auto-marked MERGED by GitHub (via ancestry path).
- **2026-05-12 14:32:24Z–14:33:11Z:** Pages workflow run `25741285166` succeeded in 47s. Production now serves `cb6fa19` runtime payload (content-length 629,540, was 586,182).
- **2026-05-12:** Production runtime smoke PASS across §A (pre-login), §B (Admin), §C (Manager), §D (Engineer/Viewer), §E (RPC failure path security). Phase 1.5 manager-role gap confirmed CLOSED on production; `L-RTI-007` security invariant production-evidenced.
- **2026-05-12:** This commit — `docs: record production smoke acceptance` — refreshes STATE.md and proposes `L-DO-006`, `L-RTI-009`, `L-RTI-010`, `L-RPM-005`, `L-DBPM-005` (full text in respective track files).

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
