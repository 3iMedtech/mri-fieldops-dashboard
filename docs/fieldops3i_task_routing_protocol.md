# FieldOps3i — Task Routing Protocol, Quality Gates, and Automation Roadmap

**Status:** Documentation-only governance file.
**Authored on branch:** `feat/v1.4.1-phase2-review`
**Audience:** human operator + Claude Code agents.
**Companion to:** [`docs/fieldops3i_agent_orchestration_model.md`](fieldops3i_agent_orchestration_model.md), [`AGENTS.md`](../AGENTS.md), [`CLAUDE.md`](../CLAUDE.md).

This document defines (a) how tasks are routed through the agent hierarchy, (b) what quality gates each track enforces, (c) what is automated vs manual, and (d) the realistic automation maturity roadmap. It complements — does not replace — the orchestration model.

---

## 1. Hierarchy Snapshot

```
                  ┌─────────────────────────────────────────┐
                  │   Operator (human)                      │
                  │   - issues approval phrases             │
                  │   - reads PASS/HOLD/STOP from agents    │
                  └───────────────────┬─────────────────────┘
                                      │
                  ┌───────────────────▼─────────────────────┐
                  │   fieldops-delivery-orchestrator        │
                  │   - phase sequencing                    │
                  │   - PR gates                            │
                  │   - PASS / HOLD / STOP / ESCALATE       │
                  └───┬───────────────┬───────────────┬─────┘
                      │               │               │
              ┌───────▼──────┐ ┌──────▼──────┐ ┌─────▼──────┐
              │  Database    │ │   Runtime   │ │  Release   │
              │  PM          │ │   PM        │ │  PM        │
              └───┬──────┬───┘ └───┬─────┬───┘ └──┬─────┬───┘
                  │      │         │     │        │     │
   ┌──────────────▼┐ ┌───▼──────┐  │     │        │     │
   │ sql-rls-safety│ │ runbook- │  │     │        │     │
   │               │ │ verifier │  │     │        │     │
   └───────────────┘ └──────────┘  │     │        │     │
   ┌───────────────────────────────▼┐ ┌──▼─────┐  │     │
   │ data-reconciliation             │ │qa-test-│  │     │
   │                                 │ │auto    │  │     │
   └─────────────────────────────────┘ └────────┘  │     │
                                  ┌──▼──────────┐  │     │
                                  │ runtime-    │  │     │
                                  │ integration │  │     │
                                  └─────────────┘  │     │
                                                  ┌▼─────▼────────┐
                                                  │ release-agent │
                                                  │ test-agent    │
                                                  │ (legacy)      │
                                                  └───────────────┘

   Cross-cutting (report directly to delivery-orchestrator on demand):
     - fieldops-automation-memory-agent (state persistence: automation/STATE.md)
     - product-design advisory team (advisory-only; see PRODUCT_DESIGN_TEAM.md)
     - fieldops-orchestrator (legacy, module coordination)
     - fieldops-ui-agent / fieldops-bug-agent / fieldops-supabase-agent / fieldops-observability-agent (legacy/module)
```

**Reading the hierarchy:**
- The Delivery Orchestrator is the ONLY node that reconciles cross-track verdicts.
- A PM owns a track and synthesizes its specialists' findings into ONE verdict.
- Specialists have hard stops and forbidden actions; PMs do not paraphrase them.
- The operator approves at the gates the orchestrator names; never at the specialist level directly.

---

## 2. Task Routing Decision Tree

Use this to decide where to enter the hierarchy for a new task.

### 2.1 Single-domain tasks (skip the orchestrator + PM)

| Task shape | Direct entry point |
|---|---|
| Pure documentation edit | author directly; `fieldops-migration-runbook-verifier` if it's a runbook |
| Single-line comment fix in migration | `fieldops-sql-rls-safety-agent` |
| Read-only diagnostic query design | `fieldops-data-reconciliation-agent` |
| Pure CSS/copy tweak | `fieldops-ui-agent` (legacy) |
| Bug RCA in single module | `fieldops-bug-agent` (legacy) |
| Single-table SELECT verification | `fieldops-supabase-agent` (legacy) |

### 2.2 Multi-specialist tasks (route through PM)

| Task shape | PM | Why |
|---|---|---|
| New SQL migration + rollback + runbook | Database PM | sql-rls-safety + runbook-verifier + reconciliation all needed |
| RLS policy change | Database PM | sql-rls-safety + runbook-verifier (test plan changes) |
| Data backfill (V2/PM/CMC) | Database PM | reconciliation lead + sql-rls-safety review |
| New runtime feature touching `index.html` | Runtime PM | runtime-integration + qa-test-automation; sometimes ui-agent |
| Auth/role/RPC integration change | Runtime PM | runtime-integration + qa-test-automation + Database PM coordination |
| XLSX flow change | Runtime PM | runtime-integration + qa-test-automation + reconciliation |
| Version bump / tag / deploy | Release PM | release-agent + qa-test-automation + memory snapshot |
| Production apply (any env-named action) | Delivery Orchestrator → Database PM → Release PM | requires phrase-matching gate |
| Rollback decision | Release PM | release-agent + observability concerns + rollback target verification |

### 2.3 Phase-level tasks (orchestrator entry)

Use the Delivery Orchestrator when the task crosses tracks:
- Phase 2 staging apply (DB track + Runtime track + Release track all in scope).
- Production apply for a phase (DB + Release).
- Cross-track conflict resolution.
- "What's the state of the project?" → orchestrator → automation-memory-agent.

---

## 3. Task Assignment Protocol

### 3.1 Breaking a complex feature into tracks

For any non-trivial task, the orchestrator decomposes into tracks:

1. **DB track** (if any `db/migrations/*` change) → Database PM
2. **Runtime track** (if any `index.html` change) → Runtime PM
3. **Release track** (if any tag/deploy/version impact) → Release PM
4. **Quality track** (cross-cutting) → qa-test-automation reports into whichever PM is primary

Each track produces ONE verdict. The orchestrator combines them.

### 3.2 Combining verdicts

| DB | Runtime | Release | Combined verdict |
|---|---|---|---|
| PASS | PASS | PASS | PASS — operator may issue the next approval phrase |
| PASS | HOLD | n/a | HOLD on Runtime PM specifics |
| HOLD | n/a | n/a | HOLD on Database PM specifics |
| STOP | * | * | STOP — fix or abandon |
| * | STOP | * | STOP — fix or abandon |
| * | * | STOP | STOP — fix or abandon |
| any with ESCALATE | ESCALATE — operator decides |

### 3.3 Implementation start trigger

Implementation (any actual file edit beyond review-only docs / migrations) starts ONLY when:
- The relevant track PM has produced PASS for the design.
- The operator has issued the matching approval phrase (`approved, apply <X> to <branch>` for runtime; `approved, apply <migration> to staging` for SQL).
- The Release PM has confirmed scope (no surprise version/tag/deploy implications).

### 3.4 Staging start trigger

Staging apply starts ONLY when:
- Database PM track verdict PASS (against the SHA being applied).
- Operator has issued `approved, apply <migration> to staging`.
- Pre-flight read-only inspection has been pasted back and accepted.

### 3.5 Production start trigger

Production action starts ONLY when:
- Staging apply has completed AND staging verification has PASSed (Database PM + Runtime PM + Release PM all PASS for staging).
- Production runbook exists and has been verified by `fieldops-migration-runbook-verifier` for the production environment.
- Operator has issued the **production-specific** approval phrase (e.g., `approved, apply phase 2 to production`). Staging phrase does NOT carry over.
- Rollback target tag exists and is on `releases/<tag>/`.

---

## 4. Quality Gates

### 4.1 SQL safety gate (Database PM)

Owned by `fieldops-sql-rls-safety-agent`. Required PASS before any apply approval:

| Check | Method | Today | Target |
|---|---|---|---|
| RLS recursion | manual read of policy expressions | manual | CI assertion |
| SECURITY DEFINER + locked search_path on helpers | manual | manual | CI: `select prosecdef, proconfig from pg_proc...` |
| GRANT alignment with RLS | manual `has_table_privilege()` | manual | CI assertion |
| Idempotency (every DDL guarded) | manual | manual | CI: re-apply migration twice; assert second is no-op |
| Rollback symmetry | manual | manual | CI: apply forward then rollback; assert state matches pre-apply |
| Service-role vs authenticated assumptions | manual | manual | manual |

### 4.2 Runbook gate (Database PM)

Owned by `fieldops-migration-runbook-verifier`:

| Check | Method | Today |
|---|---|---|
| Pre-flight queries cover baseline | manual | manual |
| Apply order matches dependencies | manual | manual |
| Expected outputs are concrete (not "should pass") | manual | manual |
| Cleanup statements name session role | manual | manual |
| Stop points numbered + gated by approval phrases | manual | manual |
| Approval phrase matches target environment | manual | manual |

### 4.3 Data integrity gate (Database PM)

Owned by `fieldops-data-reconciliation-agent`:

| Check | Method |
|---|---|
| V2 vs config_assets diff produces expected count | runbook §1.3 query + paste-back |
| Marker rows ⊇ pre-state missing set after backfill | runbook §4.3 query + paste-back |
| XLSX upsert diff (WILL_INSERT / WILL_UPDATE / SKIPPED) | manual review of three lists |
| Ambiguous customer-name flagged for ESCALATE | manual; recommend CSV review |

### 4.4 Runtime integration gate (Runtime PM)

Owned by `fieldops-runtime-integration-agent`:

| Check |
|---|
| SQL-apply-first sequencing constraint honored |
| Auth fallback path present (RPC failure → safe default) |
| Every new write button gated by `canManagePM()` (or stricter) |
| XLSX upsert payload excludes lifecycle fields |
| Add Asset form `code` immutable on existing rows |
| Renew workflow transactional (RPC) |
| De-install requires type-asset-code confirmation |

### 4.5 QA / Regression gate (Runtime PM + Release PM)

Owned by `fieldops-qa-test-automation-agent`:

| Tier | Pre-staging | Pre-prod |
|---|---|---|
| 1 — migration syntax | required | required |
| 2 — helpers prosecdef/search_path | required | required |
| 3 — RLS + GRANT | required | required |
| 4 — role-permission write tests | recommended | required |
| 5 — post-deploy smoke | n/a | required |
| 6 — manual matrix | recommended | required |

Today tiers 1-5 are PLANNED; only tier 6 is operational. The qa-test-automation agent's near-term mission is to land tier 1, then 2-3, then 4-5.

### 4.6 Release readiness gate (Release PM)

Owned by `fieldops-release-agent` (legacy) + automation-memory:

| Check |
|---|
| Working tree clean |
| Branch alignment (`staging..main` and reverse) |
| Database PM verdict PASS for the SHA being released |
| Runtime PM verdict PASS for the SHA being released |
| `VERSION` bump matches semver impact |
| `index.html` `APP_VERSION` and `APP_BUILD` align with `VERSION` |
| `CHANGELOG.md` entry present for this release |
| `releases/<tag>/` snapshot exists |
| Rollback target tag exists |
| Staging validated for the same SHA |
| Role testing complete (manual matrix or qa-test-automation) |

### 4.7 Rollback readiness gate (Release PM)

Per `ROLLBACK.md`:

| Check |
|---|
| Most recent known-good tag identifiable |
| Rollback procedure rehearsed on staging within last 30 days |
| Tag-based rollback used (no `--force` to `main`) |
| Schema rollback file exists for any forward migration in scope |
| `releases/<tag>/MANIFEST.txt` matches the `etag`/`last-modified` headers being targeted |

### 4.8 Production readiness gate (Release PM)

| Check |
|---|
| Staging passed all gates 4.1–4.7 above |
| Production runbook authored + verified by runbook-verifier |
| Operator issued production-specific approval phrase |
| Production Supabase baseline captured before apply |
| Post-apply verification queries pre-staged in production runbook |

### 4.9 Post-deploy verification gate (Release PM)

| Check |
|---|
| GitHub Pages headers `etag` / `last-modified` advanced |
| `APP_VERSION` console value matches expected tag |
| Console error-free across all 3 roles |
| Audit_log writes flowing (recent timestamp) |
| Daily-alert health check passing within 24h |

---

## 5. Speed Improvements (avoid bureaucracy)

The hierarchy is overhead unless it produces leverage. Use these rules to keep it fast.

### 5.1 Skip layers when only one specialist is needed

Single-domain tasks bypass PMs and the orchestrator. See §2.1.

### 5.2 Parallelize independent specialists

Within a track, specialists that don't depend on each other run in parallel:
- DB track: sql-rls-safety + runbook-verifier are independent. Reconciliation often depends on the SQL design first.
- Runtime track: runtime-integration design + qa-test-automation test plan run in parallel after track entry.

### 5.3 Batch read-only inspection

Pre-flight queries (read-only) can be batched into ONE paste-back rather than gated step-by-step. Only state-mutating steps require per-step stop points.

### 5.4 Cache state via `automation/STATE.md`

The memory agent persists verified state. Don't re-derive PR/commit/baseline state every session — read the persisted snapshot first.

### 5.5 What should be automated (ranked by leverage)

| # | Item | Owner | Estimate | Closes audit gap |
|---|---|---|---|---|
| 1 | Migration syntax + helper assertions in CI (Tier 1-3) | qa-test-automation | half-day | R1, R2, audit N2 |
| 2 | Memory persistence (`automation/STATE.md`) | automation-memory | hours | audit N3, R11 |
| 3 | Tag-based rollback pattern (replace force-with-lease) | release-pm | doc edit only | audit N4, R7 |
| 4 | V2 fingerprint check in CI | qa-test-automation + reconciliation | hours | R13, audit N5 |
| 5 | Playwright role-permission tests (Tier 4) | qa-test-automation | days | R6, audit M1 |
| 6 | Post-deploy smoke (Tier 5) | qa-test-automation + release-pm | hours | R8, audit M2 |
| 7 | Sentry / error tracking | release-pm + observability concerns | hours | R5, audit M2 |
| 8 | Single-source V2 data (`db/seed/install_base_v2.json`) | data-reconciliation | days | R13, audit M3 |
| 9 | Authoritative `scripts/release.sh` (full release flow) | release-agent | days | audit M5 |

### 5.6 What should remain manual

- Approval phrases (operator types in chat). The discipline IS the safety.
- Staging project visual confirmation (operator looks at the dashboard before pasting).
- Production runbook walk-through (read-twice-paste-once pattern).
- Rollback decision (human judgment about user impact).
- Product / UX direction (advisory, not gated).

### 5.7 Anti-pattern: process-without-leverage

If a gate requires the operator to paste a query that nothing automates, ask: **"What is this gate catching that the agents above it didn't already catch?"** If the answer is "nothing — it's belt-and-suspenders", the gate is bureaucracy.

Tightening rule: every gate should either (a) catch a class of error no upstream agent does, or (b) be automated. If neither, retire it.

---

## 6. Automation Maturity Roadmap

Honest positioning of FieldOps3i against a 6-level scale:

### Level 1 — Manual but Safe
Each task driven by the human; no agent layer; safety relies on human discipline. **Predates this project's current state.**

### Level 2 — Agent-Assisted
Specialist agents check artifacts (SQL / runbook / runtime / release) before execution; human triggers every step; explicit stop points; approval phrases.

> **FieldOps3i is here as of `e0da6a2`.**
> Verification tier strong; execution + memory tiers weak. Operator load high.

### Level 3 — Scripted Verification
Most pre-flight + post-apply checks are CI-asserted, not paste-backs. Memory persists. Rollback is tag-based. SQL fingerprints automated.

> **FieldOps3i target within 4-8 weeks.**
> Requires: CI verify-migrations workflow, `automation/STATE.md` populated, tag-based rollback, V2 fingerprint check, formal definitions for all referenced agents.

### Level 4 — Automated Test Harness
Playwright role-permission tests + RLS assertion suite + post-deploy smoke run on every PR and every deploy. Tier 6 (manual matrix) is supplementary, not gating.

> **FieldOps3i target within 3 months.**
> Requires: tests/rls-harness/ implemented, post-deploy smoke in pages-deploy.yml, regression tests landing alongside every fix.

### Level 5 — Self-Checking Release Pipeline
Release flow is a single `scripts/release.sh` that automates VERSION + APP_VERSION + CHANGELOG insertion + tag + Pages deploy + post-deploy smoke + rollback rehearsal. Operator approves at fewer, higher-leverage gates.

> **FieldOps3i target within 6 months.**
> Requires: `scripts/release.sh` authoritative, single-source V2 data, observability service wired, audit_log of SQL applies.

### Level 6 — Near-Autonomous Delivery
End-to-end flow from task spec → agent design → agent implementation → staging apply → automated verification → production approval gate → automated deploy with rollback-on-failure. Human appears only at production apply, security policy change, release tag.

> **FieldOps3i target: long-term.**
> Requires: every Level 5 capability + canary deploys + observable rollback metrics + shadow-database CI for migrations + audit chain machine-verifiable.

**Honest current score:** Level 2.0 (some Level 3 elements in agents but no automation actually in CI yet).

---

## 7. Phase 2 Integration Walkthrough

How a Phase 2 lifecycle change should flow through the upgraded operating system.

### 7.1 Review (already complete for PR #26)
- Delivery Orchestrator opens task package: "Phase 2 review for v1.4.1".
- Database PM gets DB track (0004 + 0005 + their rollbacks + runbook).
  - sql-rls-safety reviews 0004 + 0005 + rollbacks.
  - runbook-verifier reviews staging runbook.
  - data-reconciliation reviews V2 vs config_assets diff.
  - Database PM reports PASS to orchestrator.
- Runtime PM gets Runtime track (Phase 2 review §4-§7 design).
  - runtime-integration reviews RPC integration, canManagePM(), XLSX upsert, lifecycle UI.
  - qa-test-automation produces test plan + flags coverage gaps (today: tiers 1-5 are PLANNED).
  - Runtime PM reports PASS-with-coverage-gaps to orchestrator.
- Release PM confirms scope (review-only PR; no version/tag/deploy implications).
- Orchestrator combined verdict: PASS for review; HOLD on apply pending operator approval phrases.

### 7.2 Staging pre-flight
- Operator issues `approved, apply phase 2 to staging`.
- Database PM provides §1.2/§1.3 pre-flight queries (read-only, batch paste-back).
- After paste-back, Database PM PASSes pre-flight → Stop Point #1 advances.

### 7.3 0004 apply (staging)
- Database PM provides §3 apply instructions (single paste of 0004).
- After paste-back of SQL Editor output, Database PM verifies §3.3 queries → Stop Points #3, #4 advance.

### 7.4 0004 verification
- Database PM confirms 6 new `v141_*_app_can_write` policies present.
- Legacy admin_* policies untouched.
- qa-test-automation Tier 1-3 (when implemented) re-confirms helper/policy state via CI.

### 7.5 0005 apply (staging)
- Database PM provides §4 apply instructions (single paste of 0005, now with explicit BEGIN/COMMIT).
- After paste-back including the multi-line NOTICE format, Database PM verifies §4.3 queries → Stop Points #5, #6 advance.

### 7.6 0005 verification
- data-reconciliation confirms marker rows ⊇ pre-state missing set.
- count(config_assets) = 25 confirmed.

### 7.7 Role tests (staging)
- qa-test-automation runs Tier 4 if implemented; otherwise reports COVERAGE GAP and falls back to manual `TEST_MATRIX.md`.
- test-agent (legacy) executes the manual matrix per role.
- Runtime PM PASSes role-test gate.

### 7.8 Runtime implementation (staging)
- Runtime PM authorizes `feat/v1.4.1-phase2-impl` branch.
- runtime-integration produces final diff for `index.html`.
- Operator issues `approved, apply <runtime change> to feat/v1.4.1-phase2-impl`.
- Implementation lands on the impl branch; Runtime PM coordinates with qa-test-automation for new tests.

### 7.9 QA (staging)
- qa-test-automation runs full test suite against staging Supabase.
- test-agent runs manual matrix as backup.
- Release PM confirms regression coverage.

### 7.10 Release readiness
- Release PM checks all gates 4.6 + 4.7.
- Rollback target identified (most recent known-good tag, e.g., `v1.4.0.1`).
- Snapshot built for the new version.

### 7.11 Production
- Operator drafts production runbook (separate doc, modeled on staging).
- runbook-verifier PASSes production runbook.
- Operator issues `approved, apply phase 2 to production`.
- Same DB-PM-led flow as §7.3-§7.6 but against production.
- Then `approved, deploy <version> to production` for the runtime.
- Post-deploy smoke (Tier 5) executes; Release PM PASSes.

### 7.12 Rollback (if needed at any step)
- Release PM initiates per `ROLLBACK.md`.
- Tag-based rollback to most recent known-good (do NOT force-push to main).
- DB rollback file applied if forward migration was in scope.
- Post-rollback smoke executes.
- Forward fix authored on a fresh branch.

---

## 8. Anti-Overengineering Rules

Every new agent or process must justify itself.

### 8.1 Test for "is this useful?"

For every gate, ask:
1. **What risk does it reduce?** (concrete; "improves quality" doesn't count)
2. **What time does it save vs add?** (be honest; if it adds 30 min for every PR but catches 1 bug per quarter, run the math)
3. **When should it NOT be used?** (every gate has a skip condition; gates without one are bureaucracy)

### 8.2 New agents: minimum bar

A new agent file in `.claude/agents/*` is justified ONLY if:
- It owns a hard stop that no existing agent owns, OR
- It synthesizes outputs from 2+ existing agents (PM tier), OR
- It automates a check that is currently manual.

Reject "advisory only" or "nice to have" agents. The 6 product-design agents are an exception (already in place; advisory by design); no new advisory-only agents.

### 8.3 New gates: minimum bar

A new gate is justified ONLY if it catches a class of error that has actually happened, is likely to happen, or is regulatorily required.

Examples that pass: SQL recursion check (happened in Phase 1); last-admin guard (could lock out admin); approval phrase per environment (catches wrong-env paste).

Examples that fail: "review the README before merging" (no risk reduced); "all PRs must have 3 reviewers" (small team — bottleneck without leverage).

### 8.4 Documentation: SSOT rule

If the same fact is in 3+ docs, it's a drift risk. Pick ONE source-of-truth file and have the others reference it.

Examples requiring consolidation:
- Role model (`Admin/Superadmin / Manager / Engineer/Viewer`) is in 6+ files. SSOT candidate: `docs/ROLE_MODEL.md` (does not yet exist; recommended Phase 3).
- V2 row data is in 3 files (migration, review doc, runbook). SSOT candidate: `db/seed/install_base_v2.json` (recommended Phase 3).

### 8.5 Process: cost of process is real

The orchestration model has 14 governance docs and 12+ agents. That is at the upper bound of useful. Adding more without removing equivalent overhead reduces leverage, not increases it.

**If this doc is over 500 lines, it probably needs trimming.** (Currently designed at ~400.)

---

## 9. Memory Protocol Integration

Beyond `automation/STATE.md` (current-truth snapshot), the team uses a durable lessons layer at [`automation/memory/`](../automation/memory/) governed by [`automation/memory/MEMORY_PROTOCOL.md`](../automation/memory/MEMORY_PROTOCOL.md). Memory is integrated into routing as follows:

### 9.1 Task start protocol (additive to §3.1)

| Agent | Reads at task start |
|---|---|
| Delivery Orchestrator | `automation/STATE.md` + `memory/GLOBAL_LESSONS.md` + skim all four track files |
| Database PM | STATE + GLOBAL + `tracks/database-track.md` |
| Runtime PM | STATE + GLOBAL + `tracks/runtime-track.md` |
| Release PM | STATE + GLOBAL + `tracks/release-track.md` + `tracks/database-track.md` |
| Specialist | own section of its track file + GLOBAL |
| QA test automation | `tracks/runtime-track.md` + `tracks/release-track.md` (regression) + GLOBAL |
| Automation memory | STATE + own section in `tracks/delivery-orchestrator.md` + GLOBAL |
| Legacy Tier 3 | matching track file + GLOBAL |
| Tier 4 product-design | none (advisory) |

### 9.2 Task close protocol

Every agent's final response adds:

- `Memory consulted:` list of entry IDs cited (e.g., `L-G-003`, `L-SQL-001`)
- `Memory updates proposed:` lessons in `MEMORY_PROTOCOL.md` §4 format, or "none"

The Delivery Orchestrator additionally surfaces `Cross-track memory conflicts:` (or "none").

### 9.3 PASS / HOLD / STOP integration

- Memory **informs** verdicts; memory **cannot authorize** verdicts. Authorization traces to current source-of-truth.
- A memory entry that contradicts the current repo / git / PR / runbook / Supabase output is wrong for this task. Update or skip.
- Conflicting memory entries between agents trigger HOLD until the Delivery Orchestrator reconciles.

### 9.4 Phase transition + pruning

- Before any phase transition, the Delivery Orchestrator skims track files for `OBSOLETE` and `STALE` entries.
- Operator commits pruned/updated memory in a separate documentation PR.
- Memory entry caps: `GLOBAL_LESSONS.md` ~20; each track file ~30. Above caps → promote / split / prune.

### 9.5 Hard safety rules (additive to orchestration model §10)

- Memory cannot authorize SQL, staging, production, merge, tag, deploy, mark-ready.
- Memory cannot override operator approval phrases (or their absence).
- Stale memory must be labeled.
- Conflicting memory triggers HOLD.
- No agent silently rewrites memory; updates are operator-committed.

### 9.6 Anti-bloat rule (additive to §8)

The memory system follows the same anti-overengineering bar as the rest of the operating system. If maintenance feels burdensome, you've added too many entries. Skip memory updates for routine successes, cosmetic fixes, and lessons already captured.

---

## 10. Summary

The hierarchy in §1 is the structural change. The PM layer reduces orchestrator load on multi-specialist tasks; specialists are unchanged. The QA test-automation agent closes the biggest verification gap. The state persistence file (`automation/STATE.md`) closes the current-truth memory gap. The lessons layer at `automation/memory/` closes the durable-learning gap. The roadmap in §6 honestly positions FieldOps3i at Level 2 with a credible path to Level 3 within 4-8 weeks.

The agents and process exist to **deliver software faster and safer**. When a gate or agent slows you down without commensurate risk reduction, retire it. The memory system follows the same rule.
