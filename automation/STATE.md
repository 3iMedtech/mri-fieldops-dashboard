# FieldOps3i — Persistent State Snapshot

**Owner:** `fieldops-automation-memory-agent`
**Updated by:** operator-approved commit, with content drafted by `fieldops-automation-memory-agent` at verified gates. The agent does not directly commit state changes.
**Read by:** every agent at session start (especially the Delivery Orchestrator and the three PMs).
**Authority:** advisory snapshot. The repository + Supabase are the truth; this file is the cache.
**Scope:** *current truth* (PRs, branches, environment state, open gates, stale assumptions). For *durable lessons*, see [`memory/MEMORY_PROTOCOL.md`](memory/MEMORY_PROTOCOL.md), [`memory/GLOBAL_LESSONS.md`](memory/GLOBAL_LESSONS.md), and [`memory/tracks/`](memory/tracks).

If this file disagrees with `git log` / `gh pr list` / Supabase, the repo and Supabase win — and the disagreement itself is a finding the memory agent must surface (`STALE` or `INCONSISTENT`).

---

## Last verified

- **Snapshot timestamp:** 2026-05-11 (B6 manual role matrix PASS on staging at `cb6fa19`)
- **Snapshot author:** Claude (acting as Delivery Orchestrator + Runtime PM + QA + Release PM + automation-memory)

---

## Branch + commit

- **Active runtime branch:** `feat/v1.4.1-phase2-impl`
- **Latest commit on runtime branch:** `cb6fa19` — `B5.6: simplify Install Base + Contracts column information architecture`
- **Active governance branch:** `feat/v1.4.1-phase2-review`
- **Latest commit on governance branch:** `62c5018` — `Update STATE.md + database-track memory after Phase 2 staging SQL apply`
- **Commits ahead of `main`:** 21 on the runtime branch (the governance branch is an ancestor)
- **Working tree:** clean (as of last verified snapshot)

---

## Open PRs

| # | Title | State | Draft | Head branch | Latest commit | Owner verdict |
|---|---|---|---|---|---|---|
| 27 | Draft: v1.4.1 Phase 2 runtime implementation | OPEN | YES | `feat/v1.4.1-phase2-impl` | `cb6fa19` | B5.6 interactive verification PASS; B6 manual role matrix PASS (Sessions C/D/F/O/X/I); staging serves `cb6fa19`; PR remains DRAFT pending production runbook + production-side gates |
| 26 | Draft: v1.4.1 Phase 2 review package | OPEN | YES | `feat/v1.4.1-phase2-review` | `62c5018` | Phase 2 governance package (review doc + runbook + memory + agent definitions). Phase 2 staging SQL apply COMPLETE. Held for merge pending PR #27 ready + production gates. |
| 25 | Draft: v1.4.1 Phase 1 production-apply runbook (review-only) | OPEN | YES | `docs/v1.4.1-phase1-production-runbook` | `d59f41b` | Held until Phase 2 production discussion |

---

## Recently merged

| # | Merged at | Merge SHA | Note |
|---|---|---|---|
| 24 | (Phase 1 ship) | `8c54334` | Phase 1 schema + helpers + RLS + user_roles seed; recursion-fix baked in |

---

## Staging Supabase state

- **Project:** `fieldops-staging`
- **URL ref:** `qupkpprptopyejbnslev`
- **Org:** Abhijit Sen (FREE)
- **Last verified:** 2026-05-11 (B6 Session C pre-flight SQL PASS; Session I final baseline confirmation)
- **Migrations applied:**
  - 0001 (pm_completions_engineer_ids)
  - 0002 (lock_audit_log_writes)
  - 0003 (asset_lifecycle_phase1) — Phase 1 baseline; 11 v141_* policies on lifecycle tables; 4 SECURITY DEFINER helpers + recursion guard; 1 `v141_history_insert_app_can_write` policy on `asset_lifecycle_history`
  - 0004 (additive write policies) — **APPLIED 2026-05-10**; 6 new `v141_*_app_can_write` policies on `config_assets`/`pm_schedule`/`cmc_contracts` (verified runbook §3.3, B6 C-R3)
  - 0005 (install base master backfill) — **APPLIED 2026-05-10 09:36:55 UTC**; 1 row inserted (`AN025`); marker set = pre-state missing set per `L-REC-001` (verified runbook §4.3)

- **Row counts (last verified 2026-05-11, B6 Session I):**
  - `config_assets`: **27** (25 active + 2 de-installed; baseline = 25 V2 codes after 0005 backfill + 2 app-created test fixtures AN026/AN027)
  - `config_assets` active: 25
  - `config_assets` de-installed: 2 (AN026, AN027 — intentional staging fixtures; cleanup operator-deferred)
  - `pm_schedule`: 22
  - `cmc_contracts`: 13
  - `audit_log`: ≥ 1500+ (B6 Session O Audit Log read showed 500 of 500 most recent events)
  - `user_roles`: 3 (admin / manager / viewer — one each; verified B6 C-R1)
  - `asset_lifecycle`: 0 (no lifecycle rows yet; Renew workflow gated on `0006_*`)
  - `asset_lifecycle_history`: 6 (3 events each for AN026 + AN027: `created` + `updated`(s) + `de_installed`)

- **Helpers present (5):**
  - `app_user_role()` — SECURITY DEFINER, search_path=public ✓ (verified B6 C-R2)
  - `app_can_write()` — SECURITY DEFINER, search_path=public ✓
  - `app_is_admin()` — SECURITY DEFINER, search_path=public ✓
  - `_other_active_admin_exists(uuid)` — SECURITY DEFINER, search_path=public ✓
  - `_user_roles_block_last_admin_delete()` — trigger function ✓

- **v141_* policies on lifecycle tables:** 11 (from 0003)
- **v141_*_app_can_write policies on legacy tables (config_assets, pm_schedule, cmc_contracts):** 6 (3 INSERT + 3 UPDATE; added by 0004 on 2026-05-10)
- **v141_history_insert_app_can_write policy on asset_lifecycle_history:** 1 (from 0003)
- **Legacy admin_* policies on 4 legacy tables:** 16 (unchanged; 0004 is strictly additive)
- **V2 fingerprint:** `965ffcec48aa3ddfbfb7b975bc48dca9` (md5 of AN001..AN025 in sorted order)
- **V2 missing code on staging:** none (was `AN025`; inserted by 0005 at 2026-05-10 09:36:55 UTC)

- **GRANT vs RLS for `authenticated` role on (config_assets, pm_schedule, cmc_contracts):** INSERT=true, UPDATE=true, DELETE=variable (not required for Phase 2)

- **B6 XLSX preservation regression:** PASS at 2026-05-11. Synthetic `TEST-IB-AAA` created (operator-approved), survived full 402-ticket XLSX upload (43 new ambiguities auto-detected), cleaned up via operator-approved DELETE. See `L-RTI-005`.

---

## Staging Pages state

- **Staging Pages URL:** `https://3imedtech.github.io/mri-fieldops-dashboard/staging/index.html`
- **Currently served commit:** `cb6fa19` (B5.6)
- **etag:** `"6a01a200-99b24"`
- **content-length:** 629,540 B (byte-identical to local `index.html` at `cb6fa19`)
- **last-modified:** 2026-05-11T09:31:44 GMT
- **Deploy history (most recent first):**
  - 2026-05-11T09:31:50Z — `cb6fa19` (B5.6 column simplification)
  - 2026-05-11T04:30:37Z — `d61e907` (B5.5 status visibility)
  - 2026-05-10T18:33:04Z — `5d33f8c` (B5.4 History viewer)
- **Deploy authorization phrases consumed:** `approved, deploy 5d33f8c to staging`, `approved, deploy d61e907 to staging`, `approved, deploy cb6fa19 to staging`

---

## Production Supabase state

- **Last verified:** 2026-05-09 (Phase 1 baseline) — **STALE; must re-verify before any Phase 2 production discussion**
- **Migrations applied:** same as staging through 0003. **0004 + 0005 NOT applied.**
- **Row counts (last verified 2026-05-09):** same shape as staging baseline pre-0005. Re-verify before Phase 2 production discussion.
- **Helpers + policies:** same as staging.
- **V2 missing code on production:** assumed `AN025` matching staging; **must be re-verified via §1.3 query before any production 0005 approval.**

---

## Production Pages state

- **Production Pages URL:** `https://3imedtech.github.io/mri-fieldops-dashboard/index.html`
- **Currently served content:** the latest deploy artifact built from `main`. `main` HEAD is `8c54334` (merge of PR #24 / Phase 1 review package). Production app content is byte-identical to `releases/v1.4.0.1/index.html`.
- **etag size suffix:** `-8f1c6`
- **content-length:** 586,182 B — matches `releases/v1.4.0.1/index.html` exactly (verified across the three staging deploys; production size did not change)
- **APP_VERSION on production:** `1.4.0.1`
- **Latest tag:** `v1.4.0.1`
- **Phase 2 runtime drift:** production has ZERO Phase 2 runtime changes. Production untouched throughout Phase 2 staging acceptance.

---

## App runtime state

- **APP_VERSION on production:** `1.4.0.1`
- **APP_VERSION on staging:** `1.4.0.1` (Phase 2 runtime IS deployed but VERSION was not bumped — version bump deferred to the production release gate)
- **Latest tag:** `v1.4.0.1`
- **`index.html` line count on impl branch:** approximately 9,200+ (post-B1..B5.6 runtime work; refer to current `cb6fa19` checkout for exact count)
- **`index.html` drift vs `releases/v1.4.0.1/index.html`:** significant drift on impl branch (B1 async role resolution + B2 allowlist removal + B3 onAuthStateChange refresh + B4 XLSX safe upsert + B5.0 V2 overlay fix + B5.1..B5.4 lifecycle UI + B5.5 status visibility + B5.6 column simplification). Production still serves the unchanged `releases/v1.4.0.1/index.html` content.

---

## Open approval gates (operator phrase needed)

| Gate | Phrase needed | Status |
|---|---|---|
| Phase 2 staging SQL apply (0004 + 0005) | `approved, apply phase 2 to staging` | **CONSUMED** 2026-05-10 |
| Phase 2 runtime impl on `feat/v1.4.1-phase2-impl` | `approved, begin runtime track B implementation on feat/v1.4.1-phase2-impl` | **CONSUMED** 2026-05-10 |
| Phase 2 staging runtime deploys | `approved, deploy <commit> to staging` | **CONSUMED 3×** (5d33f8c, d61e907, cb6fa19) |
| Test asset create on staging (TEST-IB-AAA) | `approved, create TEST-IB-AAA on staging` | **CONSUMED** 2026-05-11 (B6 X1) |
| Test asset cleanup on staging (TEST-IB-AAA) | `approved, cleanup TEST-IB-AAA on staging` | **CONSUMED** 2026-05-11 (B6 X5) |
| Documentation/memory commit after B6 | `commit STATE.md + memory updates after B6` | **CONSUMED** 2026-05-11 (this commit) |
| Production runbook drafting for Phase 2 | `approved, draft production runbook for phase 2` | not yet issued |
| Phase 2 production SQL apply | `approved, apply phase 2 to production` | not yet issued |
| Phase 2 production runtime deploy | `approved, deploy <commit> to production` | not yet issued |
| Tag for Phase 2 release | `approved, tag v1.4.1` | not yet issued |
| PR #27 mark ready | `approved, mark PR #27 ready` | not yet issued |
| PR #27 merge | `approved, merge PR #27` | not yet issued |
| PR #26 mark ready | `approved, mark PR #26 ready` | not yet issued |
| PR #26 merge | `approved, merge PR #26` | not yet issued |

---

## Open risks

| Risk | Severity | Owner | Recorded at |
|---|---|---|---|
| Realtime CHANNEL_ERROR warnings on 5 `_RT_TABLES` (tickets, pm_schedule, engineers, cmc_contracts, ambiguities) — cross-session realtime sync failing on staging | Low (single-user verification unaffected) | runtime-pm | B5.6 / B6 sessions |
| 43 new ambiguity flags auto-detected during B6 X2 XLSX upload — non-blocking but need operator review before production discussion | Low | runtime-pm + test-agent | B6 Session X 2026-05-11 |
| `cmc_contracts` XLSX safe-upsert deferred to v1.4.2 (needs UNIQUE constraint on `sn` via separate migration) | Medium | database-pm | B4-partial / `L-RTI-008` |
| AN026 + AN027 retained as staging de-installed fixtures; production never sees them | Low | runtime-pm | B6 Session I 2026-05-11 |
| Renew RPC `0006_*` not authored; Renew button intentionally deferred to second impl PR | Medium | database-pm | round-1 review M2 |
| No automated tests in repo (Tier 1-5 PLANNED) | High | qa-test-automation | round-2 audit |
| Production Supabase + Pages state last verified 2026-05-09 — staleness risk before production discussion | Medium | automation-memory | 2026-05-11 |

---

## Stale assumptions (re-verify before relying)

| Item | Last verified | When to re-verify |
|---|---|---|
| Production row counts | 2026-05-09 (Phase 1 baseline) | Before any Phase 2 production discussion |
| Production V2 missing code | assumed `AN025` matching staging | Before any production 0005 approval |
| GitHub Actions deploy workflow correctness | 2026-05-11 (3 staging deploys executed cleanly: 5d33f8c, d61e907, cb6fa19) | Before next production deploy |
| Daily-alerts cadence | implicit | Weekly |

---

## Recent state changes since last snapshot

(This section is overwritten on each snapshot. Older entries archive into a future `automation/STATE_HISTORY.md` if needed.)

- **2026-05-09:** PR #26 advanced through Round 1 + Round 2 specialist review. M1–M5 medium fixes applied across `db/migrations/0005_*.sql` and Phase 2 docs. No SQL run.
- **2026-05-09:** Round 2 audit identified GOOD-BUT-HEAVY status (4.8/10 automation maturity). Recommended adding PM tier + QA test automation agent + state persistence + tag-based rollback.
- **2026-05-10:** OS upgrade `2f4ca23`. Protected scope unchanged across `e0da6a2..2f4ca23` per consistency audit.
- **2026-05-10:** F8 + F9 documentation defects closed at `c3674f2`.
- **2026-05-10:** Memory system landed at `e18f8d8` (12 files: 6 new under `automation/memory/` + 6 governance edits).
- **2026-05-10:** Phase 2 staging SQL apply COMPLETE. 0004 + 0005 applied + verified. Marker reconciliation PASS per `L-REC-001`.
- **2026-05-10:** Runtime track B begun on new branch `feat/v1.4.1-phase2-impl` with operator authorization. Series of commits: B1 (`49df8a3`) RPC integration; B2 (`f7274d1`) email allowlist removal; B3 (`fb5dabf`) onAuthStateChange refresh; B4-partial (`661daee`) config_assets safe upsert; B4-complete (`34e5433`) cmc_contracts admin-only guard; B5.0 (`88c5555`) V2 overlay preserves DB-only rows; B5.1 (`eb36be5`) Add Asset; B5.2 (`7aa34a4`) Edit Asset; B5.3 (`9fe35d5`) De-install Asset; B5.4 (`5d33f8c`) read-only History viewer; B5.5 (`d61e907`) status visibility + active-workflow filtering; B5.6 (`cb6fa19`) Install Base + Contracts column simplification.
- **2026-05-10:** PR #27 opened as DRAFT for runtime impl. Head advanced from `5d33f8c` → `d61e907` → `cb6fa19` as commits landed.
- **2026-05-10..11:** Three staging Pages deploys executed (`5d33f8c` → `d61e907` → `cb6fa19`). Production untouched.
- **2026-05-11:** B5.6 interactive browser verification PASS on staging at `cb6fa19`. All 14 checks GREEN across Admin and Engineer sessions.
- **2026-05-11:** B6 manual role matrix PASS on staging at `cb6fa19`. Six sessions (C/D/F/O/X/I) all PASS. Headline outcomes: TEST-IB-AAA XLSX preservation regression PASS — confirms B4-partial safe-upsert preserves app-created rows under real production-shape XLSX upload (`L-RTI-005`); Manager role RPC promotion verified (`L-RTI-006`); RPC failure path verified safe — non-admin never escalates to admin (`L-RTI-007`); Manager XLSX upload remains admin-only (`L-RTI-008`).
- **2026-05-11:** Phase 2 staging acceptance COMPLETE. PR #27 stays DRAFT. Next gates: production runbook drafting → production SQL apply → production deploy → tag → PR ready/merge.

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
