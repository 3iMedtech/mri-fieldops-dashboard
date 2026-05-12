# FieldOps3i — Global Lessons

**Status:** durable cross-agent rules. Read before any high-risk task.
**Owner:** all agents (read); operator (commits via Delivery Orchestrator review).
**Format:** see [`MEMORY_PROTOCOL.md`](MEMORY_PROTOCOL.md) §4.
**Cap:** ~20 entries. Above that, promote to a governance doc.

These entries apply to **every** track. Lessons specific to one track live in `tracks/<track>.md`.

---

## L-G-001 — Project path is canonical at `/Users/abhijit/Projects/FieldOps3i`

- **Date:** 2026-05-10
- **Commit / PR:** path relocation event (operator-confirmed)
- **Agent:** Delivery Orchestrator
- **Event:** repo relocated from `/Users/abhijit/Downloads/FieldOps3i` to `/Users/abhijit/Projects/FieldOps3i`. Old path retired.
- **Mistake or discovery:** any agent that hard-codes the old path will read stale state, write to a defunct working tree, or push from the wrong checkout.
- **Root cause:** path was previously canonical for many sessions; carry-over assumption.
- **Prevention rule:** at session start, read the `Primary working directory` from the environment block. Never reference `/Users/abhijit/Downloads/FieldOps3i` in new code, docs, or commands.
- **Applies to:** every agent, every session. Category: operator-confusion traps; Git/PR traps.
- **Staleness risk:** none — path is now stable.
- **Action added:** every agent's first action is `pwd`. STATE.md records the canonical path.
- **Linked files:** `automation/STATE.md`, `CLAUDE.md`.

---

## L-G-002 — Source-of-truth priority puts memory last

- **Date:** 2026-05-10
- **Commit / PR:** memory system landing
- **Agent:** Delivery Orchestrator
- **Event:** memory system added; risk that agents trust memory over current repo.
- **Mistake or discovery:** memory is last in the priority list, not first.
- **Root cause:** AI agents tend to over-trust their own prior reasoning.
- **Prevention rule:** when memory disagrees with repo / git / PR / runbook / Supabase output / operator approval, memory is wrong for this task. Update or skip.
- **Applies to:** every agent, every session. Category: hallucination traps.
- **Staleness risk:** invariant.
- **Action added:** every agent cites consulted memory IDs; PM/Orchestrator double-check the cite against current state.
- **Linked files:** [`MEMORY_PROTOCOL.md`](MEMORY_PROTOCOL.md) §2, §8.

---

## L-G-003 — Approval phrases are environment-specific

- **Date:** 2026-05-09
- **Commit / PR:** Phase 1 → Phase 2 transition discussion
- **Agent:** Delivery Orchestrator
- **Event:** there is a real risk that an operator's `approved, apply phase 2 to staging` could be silently applied to production by an over-eager agent.
- **Mistake or discovery:** approval phrases name the environment for a reason. They are not interchangeable.
- **Root cause:** convenience-bias toward "approval is approval".
- **Prevention rule:** any production action requires a phrase that **literally contains the word `production`**. Staging phrases never carry to production. Delivery Orchestrator HOLDs if the phrase doesn't match.
- **Applies to:** every gate; every agent that touches Supabase, deploy, or tag. Category: operator-confusion traps; Supabase environment traps.
- **Staleness risk:** invariant.
- **Action added:** Database PM and Release PM hard stops both check the phrase target.
- **Linked files:** `.claude/agents/fieldops-delivery-orchestrator.md`, `docs/fieldops3i_agent_orchestration_model.md` §10.

---

## L-G-004 — Memory and STATE.md cannot authorize action

- **Date:** 2026-05-10
- **Commit / PR:** `c3674f2` (F8 fix)
- **Agent:** Delivery Orchestrator + automation-memory
- **Event:** STATE.md previously read "Updated by: the memory agent", which contradicted the agent's forbidden actions ("never edits files, never commits"). Resolved at `c3674f2`.
- **Mistake or discovery:** memory components must be authored as advisory caches, not authorities.
- **Root cause:** copy-paste / convenience-phrasing in original STATE.md header.
- **Prevention rule:** every memory file (this set + STATE.md) is operator-committed with agent-drafted content. No memory file commits itself; no memory file authorizes execution.
- **Applies to:** STATE.md, every `automation/memory/*` file, every agent that mentions memory. Category: hallucination traps; Git/PR traps.
- **Staleness risk:** invariant.
- **Action added:** STATE.md header clarified; every new memory file repeats the rule.
- **Linked files:** `automation/STATE.md`, `MEMORY_PROTOCOL.md` §6, §8.

---

## L-G-005 — Default rollback is non-destructive `git revert`

- **Date:** 2026-05-09
- **Commit / PR:** ROLLBACK.md update during OS upgrade (`2f4ca23`)
- **Agent:** Release PM
- **Event:** prior rollback guidance defaulted to `git push --force-with-lease`, which destroys history and breaks others' clones.
- **Mistake or discovery:** force-push should be the escape hatch, not the default.
- **Root cause:** original guidance prioritized speed over safety.
- **Prevention rule:** rollback uses `git revert` to produce forward commits. Force-push is gated by an explicit operator phrase `approved, force rollback main to <tag>`.
- **Applies to:** every rollback decision; every Release PM action. Category: rollback traps; Git/PR traps.
- **Staleness risk:** invariant.
- **Action added:** Release PM hard stop blocks force-push without phrase. ROLLBACK.md is canonical.
- **Linked files:** `ROLLBACK.md`, `.claude/agents/fieldops-release-pm.md`.

---

## L-G-006 — Slash commands do not bypass orchestration gates

- **Date:** 2026-05-10
- **Commit / PR:** `c3674f2` (F9 fix)
- **Agent:** Delivery Orchestrator
- **Event:** legacy `.claude/commands/*.md` referenced only Tier 3 agents; risk that a user invoking `/fieldops-release` for Phase 2 work would skip the Release PM.
- **Mistake or discovery:** slash commands are convenience entry points; they do not have authority to bypass PM-tier gates.
- **Root cause:** slash commands predate the PM tier.
- **Prevention rule:** every slash command preamble explicitly states it does not bypass orchestration gates. New slash commands must state it too.
- **Applies to:** every `.claude/commands/*.md` author; every agent that respects gate hierarchy. Category: operator-confusion traps.
- **Staleness risk:** review when new commands are added.
- **Action added:** preambles added to `fieldops-implement.md`, `fieldops-release.md`, `fieldops-agent-team.md`.
- **Linked files:** `.claude/commands/fieldops-implement.md`, `.claude/commands/fieldops-release.md`, `.claude/commands/fieldops-agent-team.md`.

---

## L-G-007 — Stale memory is worse than missing memory

- **Date:** 2026-05-10
- **Commit / PR:** memory system landing
- **Agent:** Delivery Orchestrator
- **Event:** memory entries can outlive the code/config they describe.
- **Mistake or discovery:** an unlabeled stale entry will mislead a future agent more than no entry would.
- **Root cause:** entries written without a `Staleness risk` line.
- **Prevention rule:** every entry must have a `Staleness risk` field. Entries that reference a deleted file/policy/agent are marked `OBSOLETE`. Pruning happens at phase boundaries.
- **Applies to:** every memory write. Category: hallucination traps; recurring errors.
- **Staleness risk:** invariant.
- **Action added:** entry template enforces `Staleness risk`; orchestrator skims for OBSOLETE entries before phase transitions.
- **Linked files:** `MEMORY_PROTOCOL.md` §4, §11.
