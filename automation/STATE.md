# FieldOps3i — Persistent State Snapshot

**Owner:** `fieldops-automation-memory-agent`
**Updated by:** operator-approved commit, with content drafted by `fieldops-automation-memory-agent` at verified gates. The agent does not directly commit state changes.
**Read by:** every agent at session start (especially the Delivery Orchestrator and the three PMs).
**Authority:** advisory snapshot. The repository + Supabase are the truth; this file is the cache.
**Scope:** *current truth* (PRs, branches, environment state, open gates, stale assumptions). For *durable lessons*, see [`memory/MEMORY_PROTOCOL.md`](memory/MEMORY_PROTOCOL.md), [`memory/GLOBAL_LESSONS.md`](memory/GLOBAL_LESSONS.md), and [`memory/tracks/`](memory/tracks).

If this file disagrees with `git log` / `gh pr list` / Supabase, the repo and Supabase win — and the disagreement itself is a finding the memory agent must surface (`STALE` or `INCONSISTENT`).

---

## Last verified

- **Snapshot timestamp:** 2026-05-13 (Phase 2 v1.4.1 fully shipped — release commit `905ac6f`, annotated tag `v1.4.1` at object `59a5da6`, production byte-equality verified)
- **Snapshot author:** Claude (acting as Delivery Orchestrator + Release PM + Runtime PM + Database PM + QA + automation-memory)
- **⚠️ PARTIAL STALE — 2026-05-15:** v1.4.2 work has begun. Staging branch has 5 new commits since `905ac6f` (see "Recent state changes" below). Production and Supabase state remain as last verified 2026-05-13. Staging Pages URL still serves `cb6fa19` runtime; staging branch tip is now `d378c5a`.

---

## Branch + commit

- **Canonical branch:** `main`
- **Latest commit on `main`:** `905ac6f` — `release: v1.4.1`
- **Latest commit on `staging`:** `d378c5a` — `fix: excelToDateString outputs YYYY-MM-DD to prevent SheetJS format ambiguity`
- **Latest tag:** `v1.4.1` (annotated, tag object `59a5da621c4b12bc2d7d51c64eac65904bb4898a`, pointing to commit `905ac6f`)
- **Previous tag:** `v1.4.0.1`
- **Production-deployed runtime payload:** `index.html` at `905ac6f` content (v1.4.1 version metadata over the `cb6fa19` runtime payload). Net delta vs the prior production deploy `cb6fa19` runtime: 7 bytes (629540 → 629533), all version-metadata literals; **no runtime logic change** (see `L-RTI-011`).
- **Retained feature branches (post-merge):** `feat/v1.4.1-phase2-impl` head `dcd0367`; `feat/v1.4.1-phase2-review` head `62c5018` (now MERGED via PR #27 ancestry).
- **Working tree:** clean (as of last verified snapshot)

---

## Open PRs

| # | Title | State | Draft | Head branch | Latest commit | Owner verdict |
|---|---|---|---|---|---|---|
| 25 | Draft: v1.4.1 Phase 1 production-apply runbook (review-only) | OPEN | YES | `docs/v1.4.1-phase1-production-runbook` | `d59f41b` | **Stale after Phase 2 ship.** Operator decision pending: close, repurpose, or leave for archival reference. Not blocking v1.4.2 work. |

---

## Recently merged

| # | Merged at | Merge SHA | Note |
|---|---|---|---|
| 27 | 2026-05-12T14:32:18Z | `0c4e9d1` | v1.4.1 Phase 2 runtime implementation. 34 files / +7,797 / −70 lines. Brought B1..B5.6 runtime + 0004/0005 migrations + Phase 2 docs + agent definitions + memory system into main. |
| 26 | (auto via PR #27 ancestry) | n/a | Phase 2 review package. Its branch (`feat/v1.4.1-phase2-review` head `62c5018`) was an ancestor of `feat/v1.4.1-phase2-impl`, so PR #27's merge brought its content onto main; GitHub auto-marked PR #26 MERGED. |
| 24 | (Phase 1 ship) | `8c54334` | Phase 1 schema + helpers + RLS + user_roles seed; recursion-fix baked in |

---

## Staging Supabase state

- **Project:** `fieldops-staging`
- **URL ref:** `qupkpprptopyejbnslev`
- **Org:** Abhijit Sen (FREE)
- **Last verified:** 2026-05-11 (B6 Session C pre-flight SQL PASS; Session I final baseline confirmation)
- **Migrations applied:** 0001, 0002, 0003 (Phase 1), 0004 (Phase 2 additive write policies, 2026-05-10), 0005 (Phase 2 IB master backfill, 2026-05-10 09:36:55 UTC).
- **Row counts (last verified 2026-05-11):**
  - `config_assets`: **27** (25 active + 2 de-installed; baseline = 25 V2 codes after 0005 backfill + 2 staging-only test fixtures AN026/AN027)
  - `config_assets` active: 25
  - `config_assets` de-installed: 2 (AN026, AN027 — staging fixtures; production never sees them)
  - `pm_schedule`: 22
  - `cmc_contracts`: 13
  - `audit_log`: ≥ 1500+
  - `user_roles`: 3 (admin / manager / viewer)
  - `asset_lifecycle`: 0
  - `asset_lifecycle_history`: 6 (3 events each for AN026 + AN027)
- **Helpers + policies + V2 fingerprint:** see `automation/memory/tracks/database-track.md` for full reconciliation.

---

## Staging Pages state

- **Staging Pages URL:** `https://3imedtech.github.io/mri-fieldops-dashboard/staging/index.html`
- **Currently served commit:** `cb6fa19` (B5.6) — staging branch tip has not advanced since 2026-05-11
- **content-length:** 629,540 B (byte-identical to local `index.html` at `cb6fa19`)
- **etag:** `"6a01a200-99b24"`

---

## Production Supabase state

- **Last verified:** 2026-05-12 (operator-applied SQL Gate B PASS + production runtime smoke PASS as indirect confirmation that `app_can_write()` / `app_user_role()` resolve correctly)
- **Migrations applied:** 0001, 0002, 0003 (Phase 1), **0004 (Phase 2 additive write policies, 2026-05-12)**, **0005 (Phase 2 IB master backfill, 2026-05-12)**. Operator-applied per `docs/v1.4.1_phase2_production_apply_runbook.md` §6-§9.
- **Row counts (operator-asserted post-Gate-B):**
  - `config_assets`: **25** (active=25, de_installed=0 — no staging fixtures on production)
  - `pm_schedule`: 22
  - `cmc_contracts`: 13
  - `asset_lifecycle`: 0
  - `asset_lifecycle_history`: 0
  - `user_roles`: 3 (admin / manager / viewer, verified by Gate A pre-flight query B)
- **AN025 backfill row (production):** `AN025 | KVC Diagnostics | Mysore | KA | 1.5T | Philips 1.5 T Achieva | active | CDAS 16CH | 281 | R5.7.1 | HC-8E | F2000 | note='v1.4.1 phase 2 install_base_v2 backfill'` — verified by runbook §9.2.
- **Helpers present (5):** `app_user_role` / `app_can_write` / `app_is_admin` / `_other_active_admin_exists` / `_user_roles_block_last_admin_delete` (SECURITY DEFINER + locked search_path).
- **v141_*_app_can_write policies on legacy tables:** 6 (3 INSERT + 3 UPDATE from 0004).
- **V2 fingerprint:** `965ffcec48aa3ddfbfb7b975bc48dca9` (matches staging).

---

## Production Pages state

- **Production Pages URL:** `https://3imedtech.github.io/mri-fieldops-dashboard/`
- **Currently served commit:** main HEAD `905ac6f` (release: v1.4.1). The served `index.html` content is byte-identical to `releases/v1.4.1/index.html` in the repo.
- **etag:** `"6a03f2db-99b1d"` (was `"6a033a22-99b24"` between merge and tag; was `"…-8f1c6"` pre-Phase-2)
- **content-length:** 629,533 B (was 629,540 between merge and tag; was 586,182 pre-Phase-2). Delta vs the pre-tag deploy is 7 bytes — entirely version-metadata literals.
- **last-modified:** Wed, 13 May 2026 03:41:15 GMT
- **sha256 of served index.html:** `58118b41393077dac2b1cd928058898a01228c5dcf12e2cc9deea4329a9d8223` — **byte-equal to `releases/v1.4.1/MANIFEST.txt` sha256** (`L-RPM-006` byte-equality verification).
- **Pages workflow run (release deploy):** `25776828153` — push event from `905ac6f`, completed/success in 30s, 2026-05-13T03:40:51Z → 2026-05-13T03:41:21Z.
- **Pages workflow run (prior — post-smoke docs):** `25743889930` — push event from `cd7ec6c`, completed/success in 55s, 2026-05-12T15:16:58Z.
- **Pages workflow run (prior — PR #27 merge):** `25741285166` — push event from `0c4e9d1`, completed/success in 47s, 2026-05-12T14:32:24Z.
- **Deploy authorization phrases consumed:** `approved, deploy cb6fa19 to production` (Gate C), `approved, mark PR #27 ready` (Gate D), `approved, merge PR #27` (Gate E), `approved, tag v1.4.1` (Gate F — included version commit `905ac6f` that triggered the deploy of the v1.4.1 metadata).

---

## App runtime state

- **APP_VERSION on production:** `1.4.1` (lag from `L-RPM-005` now CLOSED).
- **APP_VERSION on staging:** `1.4.0.1` (staging branch tip has not advanced since pre-tag; the staging Pages URL still serves `cb6fa19` content. Future v1.4.2 work will refresh staging.)
- **Latest tag:** `v1.4.1` (annotated, object `59a5da6`).
- **`index.html` on `main`:** `window.APP_VERSION === '1.4.1'`, `window.APP_BUILD === { version: '1.4.1', released: '2026-05-13', tag: 'v1.4.1' }`, `const APP_VERSION === '1.4.1'`, `const APP_RELEASE_DATE === '13 May 2026'`. All four version constants aligned.

---

## Production runtime smoke (2026-05-12)

Browser-driven smoke verification per `docs/v1.4.1_phase2_production_apply_runbook.md` §12 ran 2026-05-12 against the post-merge production payload at `cb6fa19` runtime content (content-length 629,540). **All gates PASS.** Per `L-RTI-011`, the post-tag deploy at `905ac6f` differs from this smoke target only in 4 lines of version-metadata literals (629,533 vs 629,540 = 7 bytes); no runtime logic changed; **this 2026-05-12 smoke remains binding for the v1.4.1 tag**.

| Gate | Result |
|---|---|
| §A Pre-login payload | PASS — title "FieldOps · Medical Imaging" renders; supabase client loaded; APP_VERSION="1.4.0.1" pre-tag (now "1.4.1" post-tag). |
| §B Admin / Superadmin | PASS — `client_userRole="admin"`, RPC 200/"admin", `app_can_write=true`, `app_is_admin=true`, `superadmin_mode=true`. IB=25 systems (AN001..AN025), de_installed=0. Add/Edit/De-install/History visible. Audit Log opens with 500 rows. Upload XLSX visible. No FieldOps app-code errors. |
| §C Manager | PASS — `client_userRole="manager"` (Phase 1.5 gap CLOSED on production), RPC 200/"manager", `bodyClasses="viewer-mode manager-mode"`, `manager_mode=true`, `superadmin_mode=false`, `can_manage_pm=true`. IB=25 systems. Add/Edit/De-install/History visible. **Upload XLSX hidden** (`L-RTI-008`). **Audit Log nav hidden + route-gated** (direct `#/auditlog` redirects to Dashboard). No FieldOps app-code errors. |
| §D Engineer / Viewer | PASS — `client_userRole="viewer"`, RPC 200/"viewer", `app_can_write=false`, `app_is_admin=false`, `bodyClasses="viewer-mode"` only. IB=25 systems. **Edit/De-install hidden via `.mgr-plus` CSS** (DOM contains buttons for defense-in-depth; `getBoundingClientRect`/`getComputedStyle` report `visible=false`). Add Asset hidden. History visible (read-only all-roles). Upload XLSX hidden. Audit Log hidden. No FieldOps app-code errors. |
| §E RPC failure path (security) | PASS — Manager with `app_user_role` RPC blocked degraded to `_userRole="viewer"`, `manager_mode=false`, `superadmin_mode=false`. **No non-admin role escalated to admin** (`L-RTI-007`). Interceptor uninstalled cleanly; Manager recovered to `_userRole="manager"` after RPC restored. |

Aggregate console: zero FieldOps app-code errors. ~40 browser-extension async-listener exceptions (ignored per spec).

---

## Open approval gates (operator phrase needed)

| Gate | Phrase needed | Status |
|---|---|---|
| Phase 2 staging SQL apply (0004 + 0005) | `approved, apply phase 2 to staging` | **CONSUMED** 2026-05-10 |
| Phase 2 runtime impl on `feat/v1.4.1-phase2-impl` | `approved, begin runtime track B implementation on feat/v1.4.1-phase2-impl` | **CONSUMED** 2026-05-10 |
| Phase 2 staging runtime deploys (3) | `approved, deploy <commit> to staging` | **CONSUMED 3×** (5d33f8c, d61e907, cb6fa19) |
| Test asset create/cleanup on staging | `approved, create/cleanup TEST-IB-AAA on staging` | **CONSUMED** 2026-05-11 |
| Documentation/memory commit after B6 | `commit STATE.md + memory updates after B6` | **CONSUMED** 2026-05-11 (`5cde80b`) |
| Production runbook drafting | `approved, draft production runbook for phase 2` | **CONSUMED** 2026-05-12 (`dcd0367`) |
| Production SQL pre-flight | `approved, run production SQL pre-flight for phase 2` | **CONSUMED** 2026-05-12 (Gate A) |
| Phase 2 production SQL apply (0004 + 0005) | `approved, apply phase 2 to production` | **CONSUMED** 2026-05-12 (Gate B) |
| Phase 2 production runtime deploy | `approved, deploy cb6fa19 to production` | **CONSUMED** 2026-05-12 (Gate C) |
| PR #27 mark ready | `approved, mark PR #27 ready` | **CONSUMED** 2026-05-12 (Gate D) |
| PR #27 merge | `approved, merge PR #27` | **CONSUMED** 2026-05-12 (Gate E — merge commit `0c4e9d1`) |
| Documentation/memory commit after production smoke | `commit STATE.md + memory updates after production smoke PASS` | **CONSUMED** 2026-05-12 (`cd7ec6c`) |
| **Tag v1.4.1** | `approved, tag v1.4.1` | **CONSUMED** 2026-05-13 (Gate F — release commit `905ac6f`, tag object `59a5da6`) |
| **Documentation/memory commit after v1.4.1 tag** | `commit STATE.md + memory updates after v1.4.1 tag` | **CONSUMED** 2026-05-13 (this commit) |

**No open forward gates for Phase 2 v1.4.1.** Phase 2 is fully shipped and closed.

### Optional follow-up gates (operator-discretion, none currently authorized)

| Suggestion | Phrase suggested |
|---|---|
| Cosmetic: edit PR #27 title to remove `Draft:` prefix | `approved, edit PR #27 title to remove Draft: prefix` |
| Operator decision on PR #25 (stale Phase 1 production-apply runbook) | `approved, close PR #25` or `approved, repurpose PR #25 to <new scope>` |
| Begin v1.4.2 scope authoring (Renew RPC `0006_*`, `cmc_contracts` UNIQUE `0007_*`, Manager XLSX relaxation) | `approved, begin v1.4.2 scope review` |

---

## Open risks

| Risk | Severity | Owner | Recorded at |
|---|---|---|---|
| Merged PR #27 title still carries `"Draft:"` prefix | Low (cosmetic; not blocking) | release-pm | 2026-05-12, unchanged through tag |
| PR #25 is stale (Phase 1 production-apply runbook; superseded by Phase 2 production ship) | Low | release-pm | 2026-05-13 |
| `cmc_contracts` XLSX safe-upsert deferred to v1.4.2 — needs UNIQUE constraint on `sn` via separate migration (`0007_*`) | Medium | database-pm | `L-RTI-008` / `L-DBPM-005` |
| Renew RPC `0006_*` not authored; Renew button intentionally deferred to a second impl PR | Medium | database-pm | round-1 review M2 |
| Manager XLSX gate stays admin-only until `cmc_contracts` safe-upsert + UNIQUE migration ship | Medium (tracked) | runtime-pm | `L-RTI-008` |
| No automated tests in repo (Tier 1-5 PLANNED; only Tier 6 manual matrix operational) | High | qa-test-automation | round-2 audit |
| Realtime CHANNEL_ERROR warnings on `_RT_TABLES` (low-severity follow-up) — observed on staging B6 Session O; did not surface in 2026-05-12 production smoke window | Low | runtime-pm | reaffirm at v1.4.2 if recurs |
| AN026 + AN027 retained as staging de-installed fixtures; production never sees them (verified by Gate A query E2) | Low | runtime-pm | 2026-05-12, unchanged |

**Closed since prior snapshot:**
- `APP_VERSION` label lag — closed by Gate F (`L-RPM-005` retires for this release cycle; the rule itself remains an invariant pattern for future phases).
- "No tag yet" risk — closed by tag `v1.4.1`.

---

## Stale assumptions (re-verify before relying)

| Item | Last verified | When to re-verify |
|---|---|---|
| Production row counts | 2026-05-12 (operator-asserted post-Gate-B; indirectly confirmed by runtime smoke role-resolution) | If future SQL applied or significant time passes |
| Production V2 missing code | 2026-05-12 (was `AN025`; now backfilled per `L-REC-001`) | invariant unless V2 baseline changes |
| Production Pages content + etag + sha256 | 2026-05-13 03:41 UTC (etag `"6a03f2db-99b1d"`, content-length 629,533, sha256 `58118b41…`) | Re-verify after any future deploy |
| Production sha256 byte-equality with MANIFEST | 2026-05-13 (`58118b41…` matches `releases/v1.4.1/MANIFEST.txt`) | invariant for v1.4.1; re-check on next tag per `L-RPM-006` |
| GitHub Actions Pages workflow correctness | 2026-05-13 (5 successful runs since OS upgrade: staging ×3 + PR #27 merge + post-smoke docs + v1.4.1 release; tag-firing-deploy duration 30s) | Before next production deploy |
| Daily-alerts cadence | implicit | Weekly |

---

## Recent state changes since last snapshot

(This section is overwritten on each snapshot. Older entries archive into a future `automation/STATE_HISTORY.md` if needed.)

- **2026-05-12:** Documentation/memory commit `cd7ec6c` recorded production smoke PASS + 5 lessons (`L-DO-006`, `L-RTI-009..010`, `L-RPM-005`, `L-DBPM-005`). Pages workflow `25743889930` succeeded in 55s.
- **2026-05-13 ~03:40 UTC (~09:10 IST):** Gate F authorized. Release commit `905ac6f` ("release: v1.4.1") authored: VERSION `1.4.0.1`→`1.4.1`, `index.html` 4 version-metadata constants updated (no runtime logic), CHANGELOG.md `## [1.4.1] — 2026-05-13` entry added, `scripts/release.sh 1.4.1` produced `releases/v1.4.1/MANIFEST.txt` (sha256 `58118b41…`, size_bytes 629533) + `releases/v1.4.1/index.html` snapshot. UTC-date reconciliation per `L-RPM-006`: first `release.sh` run stamped `2026-05-13` while CHANGELOG/index.html drafted with `2026-05-12`; resolved by aligning CHANGELOG header + `released` + `APP_RELEASE_DATE` to `2026-05-13` / `13 May 2026` and re-running snapshot.
- **2026-05-13 03:40:51Z → 03:41:21Z:** Pages workflow `25776828153` triggered by push of `905ac6f` to main. Completed/success in 30s. Production now serves the v1.4.1 metadata over the unchanged Phase 2 runtime payload.
- **2026-05-13 03:41:17Z:** Annotated tag `v1.4.1` (object `59a5da6`) created on commit `905ac6f`, pushed to origin. No second Pages workflow fires on tag push (workflow listens on `push: branches: [main]`, not tag refs).
- **2026-05-13:** Production byte-equality verified per `L-RPM-006`: `curl -s prod/index.html | shasum -a 256` returned `58118b41…`, exact match to `releases/v1.4.1/MANIFEST.txt`. Quadruple alignment (VERSION ↔ APP_VERSION constants ↔ CHANGELOG header ↔ MANIFEST sha256/size_bytes) confirmed.
- **2026-05-13:** This commit — `docs: record v1.4.1 release acceptance` — refreshes STATE.md to reflect Phase 2 v1.4.1 fully shipped and proposes `L-DO-007`, `L-RPM-006`, `L-RTI-011` (full text in respective track files).
- **2026-05-13 → 2026-05-15 (v1.4.2 scope — staging branch only):** 5 commits landed on `staging` branch; none yet on `main`:
  - `a83be6f` — feat: Engineers tab + dashboard fixes
  - `6e82c6e` — fix: dashboard engineers sorted by call count; remove eng bar chart; PM persistence
  - `611c841` — fix: block XLSX uploads with out-of-range dates; correct seed data typos
  - `49dcf29` — fix: parseFlexDate month-overflow bug producing wrong years
  - `d378c5a` — fix: excelToDateString outputs YYYY-MM-DD to prevent SheetJS format ambiguity (staging tip)
  - All 5 commits are routine XLSX date-parsing + Engineers tab fixes. No SQL, no RLS, no auth/role-gating changes. No production action taken. Agent definitions also updated (2026-05-15): observability agent wired into release-pm; delivery orchestrator routing updated to PM tier; bug-agent escalation threshold clarified; test/QA agents aware of `/tmp/fieldops_matrix.js`.

**Phase 2 v1.4.1 is closed.** v1.4.2 scope is in progress on the `staging` branch.

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
