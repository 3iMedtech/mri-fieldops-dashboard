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

### L-DO-005 — Phase 2 staging acceptance complete via multi-stop-point B5+B6 sequence

- **Date:** 2026-05-11
- **Commit / PR:** PR #27 / B6 PASS at `cb6fa19`
- **Agent:** Delivery Orchestrator
- **Event:** Phase 2 v1.4.1 staging acceptance reached PASS through a disciplined sequence: 0004 + 0005 SQL apply (2026-05-10) → runtime impl B1..B5.6 (12 commits) → B5.6 interactive verification PASS → B6 manual role matrix PASS across pre-flight SQL (Session C), Manager interactive (Session D), RPC failure path (Session F), Audit Log + realtime (Session O), XLSX preservation regression (Session X with operator-approved TEST-IB-AAA setup), and cleanup (Session I). Multiple stop points caught real defects: the B5.5 status-visibility gap, the cmc_contracts unique-key uncertainty (deferred to v1.4.2), and the load-mapper-drops-status finding.
- **Mistake or discovery:** the multi-stop-point sequencing (each gate operator-approved + per-stop paste-back + Runtime PM HOLDing between substeps) was decisive in catching the B5.5 status visibility gap before any production action. Without per-stop discipline, B5.5 would have shipped silently and de-install would have appeared as a no-op visually.
- **Root cause:** Phase 2 crossed SQL + runtime + role-gating + visual table simplification + lifecycle UI. The earlier orchestration model (Tier 0 + PMs + specialists + hard stops) was the right structure; the per-stop-point B-series was the right execution discipline.
- **Prevention rule:** every multi-track phase MUST run a B-style sequenced staging matrix before production gates open. Per-stop paste-back is mandatory. STATE.md captures verified state after each PASS. Operator approval phrases are environment-specific (`L-G-003`) and per-step (production never inherits from staging).
- **Applies to:** every multi-track phase. Category: recurring errors; release/deploy traps.
- **Staleness risk:** invariant pattern.
- **Action added:** B5 + B6 sequence is the canonical multi-track acceptance template for future Phase work (v1.4.2 cmc_contracts conversion, v1.4.x Renew RPC `0006_*`, etc.).
- **Linked files:** `docs/v1.4.1_phase2_review.md`, `docs/v1.4.1_phase2_staging_apply_runbook.md`, `automation/STATE.md`.

### L-DO-006 — Phase 2 production acceptance executed end-to-end via 7-gate sequence

- **Date:** 2026-05-12
- **Commit / PR:** PR #27 merge `0c4e9d1`; production runtime smoke PASS
- **Agent:** Delivery Orchestrator
- **Event:** Phase 2 v1.4.1 production acceptance completed through 7 sequential operator-phrase gates (A: SQL pre-flight → B: SQL apply 0004+0005 → C: deploy decision → D: PR ready → E: merge — which is the actual deploy trigger via `pages-deploy.yml on: push: branches: [main]` — → §12 runtime smoke verification → documentation/memory commit). Gate F (`approved, tag v1.4.1`) remains separate and not yet consumed.
- **Mistake or discovery:** the strict per-gate phrasing held end-to-end. No gate inheritance occurred — every advance required a fresh literal phrase typed in chat. The merge-equals-deploy coupling (which the production runbook §11.1 documents explicitly) worked correctly: Gate C authorized the deploy decision; Gates D + E executed the only sanctioned mechanism (`gh pr merge` → push to main → `pages-deploy.yml` fires; ~47s build/deploy). The runbook's pre-merge protected-scope diff (§11.2) caught zero anomalies before merge. B6 staging acceptance plus SHA-bound migration files made production apply low-risk; the multi-gate flow reduced operator-confusion risk to zero.
- **Root cause:** not a mistake — successful application of `L-G-003` / `L-DO-004` / `L-DBPM-002` on production, plus operator discipline.
- **Prevention rule:** for future cross-environment phase work, use `docs/v1.4.1_phase2_production_apply_runbook.md` §3 as the canonical 7-gate template (A pre-flight, B SQL apply, C deploy decision, D PR ready, E merge, §12 smoke, F tag). The "tag is separate from deploy" pattern is load-bearing — runtime deploys and verifies safely before VERSION/CHANGELOG/releases author work, which makes the tag gate cleaner because the runtime is already production-evidenced.
- **Applies to:** every multi-track production phase. Category: release/deploy traps; recurring errors.
- **Staleness risk:** invariant pattern.
- **Action added:** Phase 2 production gate set is the canonical template for v1.4.x and later production phase work. The browser-driven §12 smoke (Admin + Manager + Engineer + RPC failure path) is the canonical post-deploy regression.
- **Linked files:** `docs/v1.4.1_phase2_production_apply_runbook.md`, `automation/STATE.md`, `.claude/agents/fieldops-delivery-orchestrator.md`.

### L-DO-007 — Production release closes with a STATE/memory refresh AFTER the tag, never bundled with the release commit

- **Date:** 2026-05-13
- **Commit / PR:** v1.4.1 tag (`59a5da6` → `905ac6f`); this doc-memory commit
- **Agent:** Delivery Orchestrator
- **Event:** Phase 2 v1.4.1 closes with a 4-step post-acceptance documentation cycle: (1) `commit STATE.md + memory updates after B6` (`5cde80b`, 2026-05-11) — staging acceptance. (2) `commit STATE.md + memory updates after production smoke PASS` (`cd7ec6c`, 2026-05-12) — post-deploy but pre-tag. (3) `release: v1.4.1` (`905ac6f`, 2026-05-13) — tag gate; touches ONLY VERSION + CHANGELOG.md + index.html metadata + releases/v1.4.1/. (4) `commit STATE.md + memory updates after v1.4.1 tag` (this commit) — closes the loop. STATE.md is refreshed AFTER each verified gate, never before, and never bundled with the release commit.
- **Mistake or discovery:** the STATE.md "Gate F PENDING" line correctly persisted through the release commit `905ac6f` and is only being updated to "CONSUMED" now via a separately-authorized doc gate. Splitting the tag from the STATE refresh keeps the audit chain clean: diffing `cd7ec6c..905ac6f` shows only version artifacts; diffing `905ac6f..<this commit>` shows only documentation. No mixing.
- **Root cause:** good operator discipline + separate gate phrases.
- **Prevention rule:** after every release tag, the next gate is a doc-memory-refresh gate (separate phrase: `commit STATE.md + memory updates after v<X.Y.Z> tag`). Do NOT bundle STATE.md / memory edits into the release commit itself — keep release commits version-only. The doc-memory commit captures the tag/release in STATE.md, proposes new memory entries, and explicitly marks the prior gate set CONSUMED.
- **Applies to:** every release tag in v1.4.x and later. Category: release/deploy traps; documentation traps.
- **Staleness risk:** invariant pattern.
- **Action added:** the 4-step post-acceptance cycle (staging doc → production smoke doc → release commit + tag → post-tag doc) is the canonical close-out template for phase-level work.
- **Linked entries:** `L-DO-005` (multi-stop-point staging acceptance), `L-DO-006` (production 7-gate sequence), `L-RPM-006` (tag gate four-artifact alignment + byte-equality), `L-AM-001` (agent drafts, operator commits).
- **Linked files:** `automation/STATE.md`, `automation/memory/tracks/release-track.md`, `automation/memory/tracks/delivery-orchestrator.md`.

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
