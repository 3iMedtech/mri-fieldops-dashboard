# Memory — Delivery Orchestrator + Automation Memory

**Read by:** `fieldops-delivery-orchestrator`, `fieldops-automation-memory-agent`.
**Format:** see [`../MEMORY_PROTOCOL.md`](../MEMORY_PROTOCOL.md) §4.
**Cap:** ~30 entries.

---

## fieldops-delivery-orchestrator

### L-DO-001 — Read STATE.md and re-verify before assuming phase state

- **Date:** 2026-05-10
- **Commit / PR:** memory system landing
- **Agent:** Delivery Orchestrator
- **Event:** session-start drift can produce incorrect phase assumptions.
- **Mistake or discovery:** state must be (re)established at session start, not inferred from prior conversation.
- **Root cause:** orchestrator reads chat memory instead of `automation/STATE.md` + git/gh truth.
- **Prevention rule:** every Delivery Orchestrator session begins by reading `automation/STATE.md` and confirming branch + commit + PR state via `git status`, `git log -5`, `gh pr view <current>`. STATE.md is the cache; the repo is the truth.
- **Applies to:** every Delivery Orchestrator invocation. Category: recurring errors; Git/PR traps.
- **Staleness risk:** invariant.
- **Action added:** orchestrator's first three tool calls are `git status`, `git log -5`, `gh pr view <current>`.
- **Linked files:** `automation/STATE.md`, `.claude/agents/fieldops-delivery-orchestrator.md`.

### L-DO-002 — Specialist findings are append-only audit chain; never paraphrase

- **Date:** 2026-05-09 (Round-2 review)
- **Commit / PR:** `e0da6a2`
- **Agent:** Delivery Orchestrator
- **Event:** orchestrator was tempted to summarize specialist findings into a single condensed verdict.
- **Mistake or discovery:** condensing loses attribution and silently changes a verdict.
- **Root cause:** efficiency bias.
- **Prevention rule:** orchestrator relays attributed verdicts verbatim. PM verdicts are aggregated, never paraphrased. Past PASS/STOP findings are append-only.
- **Applies to:** every multi-specialist task. Category: hallucination traps; recurring errors.
- **Staleness risk:** invariant.
- **Action added:** orchestrator's reporting format names each specialist on its own line.
- **Linked files:** `.claude/agents/fieldops-delivery-orchestrator.md`, `docs/fieldops3i_agent_orchestration_model.md` §10.

### L-DO-003 — Governance commits must not touch in-flight artifacts

- **Date:** 2026-05-10
- **Commit / PR:** `2f4ca23` (OS upgrade), audited at `c3674f2`
- **Agent:** Delivery Orchestrator
- **Event:** when the agent OS was upgraded, there was a real risk of touching `db/migrations/*` or the staging runbook, which would have invalidated the prior specialist PASS at `e0da6a2`.
- **Mistake or discovery:** governance changes must be SHA-isolated from in-flight artifacts.
- **Root cause:** broad commits sweep up unrelated files.
- **Prevention rule:** before any governance / OS-upgrade commit while a phase is in flight, run `git diff --stat <last-PASS>..HEAD -- db/migrations/ docs/v1.4.1_phase[12]_*.md index.html VERSION CHANGELOG.md releases/`. The diff must be empty, otherwise the prior specialist PASS is no longer binding.
- **Applies to:** every OS upgrade or governance commit during an in-flight phase. Category: Git/PR traps; recurring errors.
- **Staleness risk:** review when phase boundaries shift.
- **Action added:** consistency-audit checklist includes the diff-stat command.
- **Linked files:** `docs/fieldops3i_task_routing_protocol.md` §3, `automation/STATE.md`.

### L-DO-004 — Production gate requires fresh phrase even after staging PASS

- **Date:** 2026-05-09
- **Commit / PR:** Phase 1 → Phase 2 transition
- **Agent:** Delivery Orchestrator
- **Event:** staging gate may PASS while production phrase is still pending.
- **Mistake or discovery:** advancing across environment boundary without a literal production phrase is a hard stop.
- **Root cause:** combined-environment thinking.
- **Prevention rule:** production action only proceeds after the operator types `approved, apply <X> to production` (or `approved, deploy <version> to production`, or `approved, tag <tag>`). Cross-reference [`GLOBAL_LESSONS.md`](../GLOBAL_LESSONS.md) L-G-003.
- **Applies to:** every cross-environment promotion. Category: operator-confusion traps; Supabase environment traps.
- **Staleness risk:** invariant.
- **Action added:** orchestrator gate matrix lists per-action production phrases explicitly.
- **Linked files:** `.claude/agents/fieldops-delivery-orchestrator.md`.

---

## fieldops-automation-memory-agent

### L-AM-001 — Memory ownership: agent drafts, operator commits

- **Date:** 2026-05-10
- **Commit / PR:** `c3674f2` (F8 fix)
- **Agent:** automation-memory
- **Event:** STATE.md header originally said "Updated by: the memory agent" — contradicting the agent's forbidden action of editing/committing files.
- **Mistake or discovery:** ownership wording must distinguish "drafts" from "commits".
- **Root cause:** copy-paste convenience.
- **Prevention rule:** memory agent drafts content; operator commits. Every memory file's header repeats this.
- **Applies to:** STATE.md, MEMORY_PROTOCOL.md, every track file. Category: Git/PR traps; hallucination traps.
- **Staleness risk:** invariant.
- **Action added:** STATE.md header rewritten; MEMORY_PROTOCOL.md §6 codifies the write protocol.
- **Linked files:** `automation/STATE.md`, [`../MEMORY_PROTOCOL.md`](../MEMORY_PROTOCOL.md), [`../GLOBAL_LESSONS.md`](../GLOBAL_LESSONS.md) L-G-004.

### L-AM-002 — Cross-environment facts decay; require re-verify timer

- **Date:** 2026-05-09
- **Commit / PR:** Phase 1 → Phase 2 transition
- **Agent:** automation-memory
- **Event:** production row counts and "AN025 missing on production matches staging" were carried into a session without a re-verify timer.
- **Mistake or discovery:** any cross-environment assumption decays between Supabase queries.
- **Root cause:** agent didn't surface staleness with timestamps.
- **Prevention rule:** every cross-environment fact in STATE.md has a `Last verified:` and `When to re-verify:` field. Cross-env facts older than the previous verified gate are marked `STALE` and must be re-queried before relying.
- **Applies to:** every STATE.md update referring to staging or production. Category: Supabase environment traps; recurring errors.
- **Staleness risk:** invariant — the rule itself, not the data, is invariant.
- **Action added:** STATE.md "Stale assumptions" section is mandatory on every snapshot.
- **Linked files:** `automation/STATE.md`.

### L-AM-003 — Redact secrets and identifiers in memory

- **Date:** 2026-05-09
- **Commit / PR:** automation-memory agent definition
- **Agent:** automation-memory
- **Event:** memory entries can leak service-role keys, full UUIDs, or raw email addresses if the agent pastes verbatim from operator output.
- **Mistake or discovery:** secrets in memory are secrets in git.
- **Root cause:** convenience pasting.
- **Prevention rule:** redact UUIDs to `<uuid:N>`, emails to `local-first-char***@domain`, never paste service-role keys or PATs. Operator may reject a memory PR that fails redaction.
- **Applies to:** every memory write across every track. Category: hallucination traps; Git/PR traps.
- **Staleness risk:** invariant.
- **Action added:** memory-agent hard stop rejects entries containing patterns matching service-role keys or full UUID/email patterns.
- **Linked files:** `.claude/agents/fieldops-automation-memory-agent.md`.
