# FieldOps3i — Persistent State Snapshot

**Owner:** `fieldops-automation-memory-agent`
**Updated by:** operator-approved commit, with content drafted by `fieldops-automation-memory-agent` at verified gates. The agent does not directly commit state changes.
**Read by:** every agent at session start (especially the Delivery Orchestrator and the three PMs).
**Authority:** advisory snapshot. The repository + Supabase are the truth; this file is the cache.
**Scope:** *current truth* (PRs, branches, environment state, open gates, stale assumptions). For *durable lessons*, see [`memory/MEMORY_PROTOCOL.md`](memory/MEMORY_PROTOCOL.md), [`memory/GLOBAL_LESSONS.md`](memory/GLOBAL_LESSONS.md), and [`memory/tracks/`](memory/tracks).

If this file disagrees with `git log` / `gh pr list` / Supabase, the repo and Supabase win — and the disagreement itself is a finding the memory agent must surface (`STALE` or `INCONSISTENT`).

---

## Last verified

- **Snapshot timestamp:** 2026-05-09 (Round 2 specialist review at `e0da6a2`)
- **Snapshot author:** Claude (acting as Delivery Orchestrator at that time)

---

## Branch + commit

- **Branch:** `feat/v1.4.1-phase2-review`
- **Latest commit:** `e0da6a2` — `docs(v1.4.1): apply phase2 round-2 specialist-review medium fixes (M4, M5)`
- **Commits ahead of `main`:** 5 (`87c026c`, `9f24b70`, `20fab53`, `5bebc1d`, `e0da6a2`)
- **Working tree:** clean (as of last verified snapshot)

---

## Open PRs

| # | Title | State | Draft | Head branch | Latest commit | Owner verdict |
|---|---|---|---|---|---|---|
| 26 | Draft: v1.4.1 Phase 2 review package | OPEN | YES | `feat/v1.4.1-phase2-review` | `e0da6a2` | Round 2 review PASSED with M4+M5 fixes; pre-flight PASSED; staging apply paused for operating-system upgrade |
| 25 | Draft: v1.4.1 Phase 1 production-apply runbook (review-only) | OPEN | YES | (Phase 1 production runbook branch) | (held) | Held until Phase 2 staging passes |

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
- **Last verified:** 2026-05-09 (Phase 2 staging pre-flight)
- **Migrations applied:**
  - 0001 (pm_completions_engineer_ids)
  - 0002 (lock_audit_log_writes)
  - 0003 (asset_lifecycle_phase1) — Phase 1 baseline
  - 0004 (additive write policies) — **NOT APPLIED** (Phase 2; pending operator approval)
  - 0005 (install base master backfill) — **NOT APPLIED** (Phase 2; pending operator approval)

- **Row counts (last verified):**
  - `config_assets`: 24
  - `pm_schedule`: 22
  - `cmc_contracts`: 13
  - `audit_log`: ≥ 1489
  - `user_roles`: 3 (admin / manager / viewer — one each)
  - `asset_lifecycle`: 0
  - `asset_lifecycle_history`: 0

- **Helpers present (5):**
  - `app_user_role()` — SECURITY DEFINER, search_path=public ✓
  - `app_can_write()` — SECURITY DEFINER, search_path=public ✓
  - `app_is_admin()` — SECURITY DEFINER, search_path=public ✓
  - `_other_active_admin_exists(uuid)` — SECURITY DEFINER, search_path=public ✓
  - `_user_roles_block_last_admin_delete()` — trigger function ✓

- **v141_* policies on lifecycle tables:** 11
- **Legacy admin_* policies on 4 legacy tables:** 16
- **V2 fingerprint:** `965ffcec48aa3ddfbfb7b975bc48dca9` (md5 of AN001..AN025 in sorted order)
- **V2 missing code on staging:** `AN025` (will be inserted by 0005)

- **GRANT vs RLS for `authenticated` role on (config_assets, pm_schedule, cmc_contracts):** INSERT=true, UPDATE=true, DELETE=variable (not required for Phase 2)

---

## Production Supabase state

- **Last verified:** 2026-05-09 (Phase 1 baseline)
- **Migrations applied:** same as staging through 0003. 0004 + 0005 NOT applied.
- **Row counts (last verified):** same shape as staging baseline. Re-verify before Phase 2 production discussion.
- **Helpers + policies:** same as staging.
- **V2 missing code on production:** assumed `AN025` matching staging; **must be re-verified via §1.3 query before any production apply.**

---

## App runtime state

- **APP_VERSION on production:** `1.4.0.1`
- **APP_VERSION on staging:** `1.4.0.1` (Phase 2 runtime not deployed)
- **Latest tag:** `v1.4.0.1`
- **`index.html` line count:** 8,878
- **Drift vs `releases/v1.4.0.1/index.html`:** unchanged (Phase 2 runtime not started)

---

## Open approval gates (operator phrase needed)

| Gate | Phrase needed | Owner |
|---|---|---|
| Phase 2 staging apply | `approved, apply phase 2 to staging` | **ISSUED but paused for operating-system upgrade** — to be re-issued or operator may proceed with current phrase |
| Phase 2 runtime to staging branch | `approved, apply <runtime change> to feat/v1.4.1-phase2-impl` | not yet issued |
| Phase 2 production SQL apply | `approved, apply phase 2 to production` | not yet issued (gated on staging success) |
| Phase 2 production runtime deploy | `approved, deploy <version> to production` | not yet issued |
| Tag for Phase 2 release | `approved, tag <tag>` | not yet issued |
| PR #26 mark ready | `approved, mark PR #26 ready` | not yet issued |
| PR #26 merge | `approved, merge PR #26` | not yet issued |

---

## Open risks

| Risk | Severity | Owner | Recorded at |
|---|---|---|---|
| Phase 2 design done; runtime implementation not started; design will go stale if delayed >2-4 weeks | High | Runtime PM | round-2 audit / `e0da6a2` |
| Renew RPC `0006_*` referenced but not authored; Track B Renew UI blocked | Medium | Database PM | round-1 review M2 / `5bebc1d` |
| No automated tests in repo (Tier 1-5 PLANNED) | High | qa-test-automation | round-2 audit |
| Memory has no persistence (this file is the fix) | Medium | automation-memory | round-2 audit |
| `git push --force-with-lease origin main` is the documented rollback path | Medium | release-pm | round-2 audit |

---

## Stale assumptions (re-verify before relying)

| Item | Last verified | When to re-verify |
|---|---|---|
| Production row counts | 2026-05-09 (Phase 1 baseline) | Before any Phase 2 production discussion |
| Production V2 missing code | assumed `AN025` matching staging | Before any production 0005 approval |
| GitHub Actions deploy workflow correctness | implicit | Before next runtime release |
| Daily-alerts cadence | implicit | Weekly |

---

## Recent state changes since last snapshot

(This section is overwritten on each snapshot. Older entries archive into a future `automation/STATE_HISTORY.md` if needed.)

- **2026-05-09:** PR #26 advanced through Round 1 + Round 2 specialist review. M1, M2, M3, M4, M5 medium fixes applied across `db/migrations/0005_*.sql`, `docs/v1.4.1_phase2_review.md`, `docs/v1.4.1_phase2_staging_apply_runbook.md`. PR remains DRAFT. No SQL run.
- **2026-05-09:** Phase 2 staging pre-flight queries delivered to operator. Pre-flight PASSED. Operator issued `approved, apply phase 2 to staging` then immediately paused execution to upgrade the operating system.
- **2026-05-09:** Round 2 audit identified GOOD-BUT-HEAVY status (4.8/10 automation maturity). Recommended adding PM tier + QA test automation agent + state persistence + tag-based rollback.

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
