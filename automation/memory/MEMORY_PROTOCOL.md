# FieldOps3i — Agent Memory Protocol

**Status:** Documentation-only governance file.
**Audience:** human operator + every Claude Code agent working on FieldOps3i.
**Companion to:** [`docs/fieldops3i_agent_orchestration_model.md`](../../docs/fieldops3i_agent_orchestration_model.md), [`docs/fieldops3i_task_routing_protocol.md`](../../docs/fieldops3i_task_routing_protocol.md), [`AGENTS.md`](../../AGENTS.md), [`CLAUDE.md`](../../CLAUDE.md).

This document defines how the FieldOps3i agent team uses persistent memory to learn from past work without letting memory become uncontrolled truth.

---

## 1. Purpose

The agent team gets smarter only if it remembers. Without memory, each session re-derives context and risks repeating prior mistakes (RLS recursion, force-push rollback, staging-phrase carry-over, the Downloads path, the email allowlist).

Memory captures durable lessons so the team:

- avoids repeated mistakes
- calibrates risk faster on familiar paths
- preserves continuity across sessions
- transfers knowledge between agents
- moves toward higher automation safely

Memory does NOT:

- replace the source of truth
- authorize SQL, deploy, merge, tag, mark-ready, or any production action
- override operator approval (or its absence)
- substitute for verification

---

## 2. Source-of-Truth Priority

When memory disagrees with anything above it, **memory is wrong** (or stale) for this task. Update or skip.

1. Current repository files (HEAD content)
2. Current git branch + commit (`git status`, `git log`)
3. Current PR state (`gh pr view`)
4. Current runbook (active `docs/v1.4.1_phase[12]_*_runbook.md`)
5. Current Supabase / environment outputs (operator paste-back)
6. Current operator approval phrases (literal text in chat)
7. `automation/STATE.md` (current-truth snapshot — operator-committed)
8. `automation/memory/**` (lessons / advisory historical context)

---

## 3. Memory Architecture

```
automation/STATE.md                          ← current truth snapshot (NOT lessons; see §3.1)
automation/memory/
├── MEMORY_PROTOCOL.md                       ← this file: rules, routing, format, safety
├── GLOBAL_LESSONS.md                        ← cross-agent durable patterns
└── tracks/
    ├── delivery-orchestrator.md             ← Tier 0 + automation-memory
    ├── database-track.md                    ← db-pm + sql-rls-safety + runbook-verifier + reconciliation
    ├── runtime-track.md                     ← runtime-pm + runtime-integration + qa-test-automation
    └── release-track.md                     ← release-pm + legacy release/test agents
```

Why this shape (and not more files):

- One protocol file (this one) avoids duplicated rules across agents.
- One global file holds rules that apply to every track.
- One file per track keeps related agents' lessons together so a PM reads its track in one pass.
- Per-agent files were rejected: too many files for an active set of 10 agents; per-track files give the same locality with a third the count.

### 3.1 STATE.md vs memory/

- **`automation/STATE.md`** — current truth snapshot. PRs, branches, environment state, open approval gates, *stale assumptions*. Operator-committed; agent-drafted. Overwritten on each verified gate.
- **`automation/memory/**`** — durable lessons. Append-mostly. Why something failed; what pattern to apply next time; what trap to avoid. Entries persist across phases.

If a fact is volatile (PR #26's latest commit) → STATE.md.
If a fact is durable (RLS recursion will recur unless every helper is SECURITY DEFINER) → memory.

---

## 4. Memory Entry Format

Every entry uses this template. Do not invent variations.

```markdown
### L-<scope>-<NNN> — <short title>

- **Date:** YYYY-MM-DD
- **Commit / PR:** <sha or PR #>
- **Agent:** <which agent recorded this>
- **Event:** <one line — what happened>
- **Mistake or discovery:** <what was wrong or what was learned>
- **Root cause:** <why it happened>
- **Prevention rule:** <what to do next time — testable / checklist-able>
- **Applies to:** <task shape / file pattern / agent set>
- **Staleness risk:** <when does this stop applying>
- **Action added:** <checklist item / new pre-flight query / new hard stop / "advisory only">
- **Linked files:** <repo paths that reference this lesson>
```

ID scheme: `L-<scope>-<NNN>` where `<scope>` is one of:

- `G` (global)
- `DO` (delivery-orchestrator), `AM` (automation-memory)
- `DBPM` (database-pm), `SQL` (sql-rls-safety), `RB` (runbook-verifier), `REC` (data-reconciliation)
- `RTPM` (runtime-pm), `RTI` (runtime-integration), `QA` (qa-test-automation)
- `RPM` (release-pm), `RA` (release-agent legacy), `TA` (test-agent legacy)

Entries without a Prevention rule are **notes**, not lessons. Notes don't belong here. Put them in PR comments or commit messages.

---

## 5. Read Protocol

| Tier | What to read | When |
|---|---|---|
| Always | `automation/STATE.md` | Before any phase-level / cross-track task |
| Always | `automation/memory/GLOBAL_LESSONS.md` | Before any high-risk task (SQL apply, runtime change, release, rollback, production) |
| Track | own track file (`automation/memory/tracks/<track>.md`) | Before starting work in that track |
| On demand | adjacent track files | When the Delivery Orchestrator delegates cross-track coordination |

### 5.1 Routing matrix

| Agent | Reads |
|---|---|
| `fieldops-delivery-orchestrator` | STATE + GLOBAL + all four track files (skim) |
| `fieldops-database-pm` | STATE + GLOBAL + tracks/database-track.md |
| `fieldops-runtime-pm` | STATE + GLOBAL + tracks/runtime-track.md |
| `fieldops-release-pm` | STATE + GLOBAL + tracks/release-track.md + tracks/database-track.md (release depends on DB) |
| `fieldops-sql-rls-safety-agent` | tracks/database-track.md (own section) + GLOBAL |
| `fieldops-migration-runbook-verifier` | tracks/database-track.md (own section) + GLOBAL |
| `fieldops-data-reconciliation-agent` | tracks/database-track.md (own section) + GLOBAL |
| `fieldops-runtime-integration-agent` | tracks/runtime-track.md (own section) + GLOBAL |
| `fieldops-qa-test-automation-agent` | tracks/runtime-track.md + tracks/release-track.md (regression) + GLOBAL |
| `fieldops-automation-memory-agent` | STATE + tracks/delivery-orchestrator.md (own section) + GLOBAL |
| Legacy Tier 3 agents | track file matching their domain + GLOBAL |
| Tier 4 product-design agents | none (advisory; no domain memory yet) |

Reading rule: **skim, don't memorize**. Cite the specific entry IDs (e.g., `L-G-003`, `L-SQL-001`) that influenced your decision in your final report.

---

## 6. Write Protocol

Memory updates are **proposed by the working agent** and **committed by an operator-approved commit**, exactly like STATE.md.

### 6.1 When to propose a memory update

- After a migration bug is found
- After a runbook mismatch is found
- After a production / staging verification issue
- After a rollback (success or failure)
- After a hallucination or wrong assumption is corrected
- After a useful prevention pattern is discovered
- After phase completion (consolidate phase-level lessons)
- After a failed or blocked task (record the blocker class)
- After a major architectural decision

### 6.2 When NOT to propose a memory update

- Routine task that succeeded as expected
- One-off cosmetic fix
- Lesson is already captured (cite the existing entry instead)
- Lesson is volatile state better suited to STATE.md
- "We did a thing" without a Prevention rule

### 6.3 Format of a proposed update

Agents propose updates in their final response under a `Memory updates proposed:` heading using the §4 entry format. Operator reviews and either commits or rejects. Agents do NOT directly edit memory files unless the task scope explicitly authorizes it.

### 6.4 Where the entry goes

| Lesson scope | File |
|---|---|
| Cross-cutting (applies to multiple tracks) | `GLOBAL_LESSONS.md` |
| Single track | `tracks/<track>.md` under the relevant agent section |
| Tier 0 / phase-level | `tracks/delivery-orchestrator.md` |
| Memory-agent / state | `tracks/delivery-orchestrator.md` (automation-memory section) |

Promote a track lesson to GLOBAL when the same lesson surfaces in 2+ tracks.

---

## 7. Cross-Agent Calibration

Agents do not read every memory file. The routing matrix above prevents context bloat and confusion. Calibration emerges from:

- **GLOBAL_LESSONS.md** — every high-risk task starts here. Project-wide rules.
- **PM track files** — PMs synthesize specialist lessons into a track-level pattern.
- **Delivery Orchestrator file** — phase-level pattern recognition.

When two agents' memory entries conflict, the Delivery Orchestrator owns the resolution. Conflicting entries trigger a **HOLD** until reconciled.

---

## 8. Memory Safety Rules

These are non-negotiable. Every agent inherits them.

1. Memory is advisory. Memory is never source of truth.
2. Stale memory must be labeled (`STALE — re-verify before relying`).
3. Conflicting memory triggers HOLD. Do not pick a side without operator input.
4. Memory cannot authorize SQL, staging, production, merge, tag, deploy, mark-ready.
5. Memory cannot override an operator approval phrase (or its absence).
6. Memory cannot hide uncertainty. If a task involves an unverified claim, say so.
7. Agents must cite which memory entries influenced their decision (one-line reference is enough).
8. Memory entries that contradict the current repo / git / runbook / Supabase output are wrong for this task. Update them or skip them.
9. Memory cannot be created from speculation. Every entry traces to a real event with a commit/PR reference.
10. Service-role keys, full UUIDs, raw email addresses must NOT appear in memory. Redact per `fieldops-automation-memory-agent` conventions (UUIDs → `<uuid:N>`; emails → `local-first-char***@domain`).

---

## 9. Mistake-Prevention Categories

Every entry should map to one of these categories so patterns are recognizable:

- **recurring errors** — same class of mistake seen 2+ times
- **hallucination traps** — confident wrong answers an agent is prone to give
- **SQL/RLS traps** — recursion, GRANT vs RLS layering, search_path, idempotency
- **runbook traps** — paste-as-SQL risk, missing stop points, wrong session role
- **Supabase environment traps** — staging/prod confusion, V2 drift, marker-row gaps
- **Git/PR traps** — wrong path, force-push, PR-link typos, stale branch
- **runtime/UI traps** — role gating gaps, auth fallback missing, XLSX overwrites
- **release/deploy traps** — version drift, missing snapshot, smoke skipped
- **rollback traps** — destructive vs forward, wrong target tag, schema vs bundle
- **operator-confusion traps** — phrase ambiguity, environment slippage, copy-paste edge cases

Tag each entry's `Applies to:` line with one or more category names.

---

## 10. Agent Evolution Rule

Memory changes agent behavior **only through this progression**:

1. **Lesson recorded** in the agent's track file.
2. **Lesson applied as a checklist item** in the agent's next runs (Action added in entry).
3. **Lesson repeats** (same class of mistake recorded twice) → upgrade to permanent rule.
4. **Permanent rule proposed** by the agent (or its PM) in a separate PR.
5. **Delivery Orchestrator reviews** the proposed rule.
6. **Operator approves** the rule by committing the agent-definition change.

Agents do **not** silently change their own behavior based on memory. Every behavior change is a visible commit to `.claude/agents/<agent>.md` or a governance doc.

---

## 11. Pruning + Anti-Bloat

Memory becomes a burden when entries pile up without value.

- Mark entries `OBSOLETE` (do not delete) when the underlying code/config no longer exists. Operator may delete OBSOLETE entries during phase boundaries.
- Promote duplicates: the same lesson in two track files moves to `GLOBAL_LESSONS.md`; track files link to the global ID.
- Cap track files at ~30 entries. Above that, prune or split.
- Cap `GLOBAL_LESSONS.md` at ~20 entries. Above that, the rules are no longer "lessons" — they're protocol; promote to AGENTS.md / CLAUDE.md / orchestration model.
- Skip memory updates for routine successes, cosmetic fixes, or lessons already captured.

If maintenance feels burdensome, you've added too many entries.

---

## 12. Integration with Task Lifecycle

Every agent's final response includes a one-line Memory section:

```
Memory consulted: <entry IDs cited>
Memory updates proposed: <list, or "none">
```

PASS / HOLD / STOP / ESCALATE verdicts must factor in memory but **never be authorized solely by memory**.

The Delivery Orchestrator's final response additionally includes:

```
Cross-track memory conflicts: <list, or "none">
```

PMs include a one-line memory consulted note in their reporting format. Specialists include the same.

---

## 13. Honest Maturity

This system is **STRUCTURED** — better than ad-hoc, well short of automated.

- Reads are manual (agents skim files).
- Writes are operator-committed (no auto-append).
- Conflicts are surfaced to humans, not auto-resolved.
- No retrieval scoring; no embeddings; no RAG; just disciplined markdown.

Move-up criteria for **ADVANCED**: structured entry schema (YAML), an indexer surfaces relevant entries by topic at task start, repeated lessons auto-promote to checklist items in agent definitions via PR.

Move-up to **HIGH-AUTOMATION READY**: machine-verifiable lesson schema, lessons lift into CI assertions, automated stale-detection from git/PR diff against entry's Linked files.

Today: STRUCTURED. Honest.
