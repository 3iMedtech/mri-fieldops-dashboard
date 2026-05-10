# Memory — Release Track

**Read by:** `fieldops-release-pm`, `fieldops-release-agent` (legacy), `fieldops-test-agent` (legacy). Also read by `fieldops-qa-test-automation-agent` for regression coverage.
**Format:** see [`../MEMORY_PROTOCOL.md`](../MEMORY_PROTOCOL.md) §4.
**Cap:** ~30 entries.

---

## fieldops-release-pm

### L-RPM-001 — Tag-based rollback is the default; force-push is gated

- **Date:** 2026-05-09
- **Commit / PR:** ROLLBACK.md update at `2f4ca23`
- **Agent:** Release PM
- **Event:** prior rollback path used `git push --force-with-lease`, which rewrites history and breaks others' clones.
- **Mistake or discovery:** force-push is an escape hatch, not a default.
- **Root cause:** original guidance prioritized speed.
- **Prevention rule:** `git revert` produces a forward commit that brings `main` to the desired tag's content. Force-push only with `approved, force rollback main to <tag>`. See [`../GLOBAL_LESSONS.md`](../GLOBAL_LESSONS.md) L-G-005.
- **Applies to:** every rollback decision. Category: rollback traps; Git/PR traps.
- **Staleness risk:** invariant.
- **Action added:** Release PM hard stop blocks force-push without phrase.
- **Linked files:** `ROLLBACK.md`, `.claude/agents/fieldops-release-pm.md`.

### L-RPM-002 — VERSION + APP_VERSION + CHANGELOG + snapshot align before tag

- **Date:** ongoing (every release)
- **Commit / PR:** every tag commit
- **Agent:** Release PM
- **Event:** any of the four artifacts out of sync produces an unverifiable release.
- **Mistake or discovery:** semver discipline fails silently when one of the four is missed.
- **Root cause:** four distinct files; manual coordination.
- **Prevention rule:** Release PM verifies all four match before tag. `releases/<tag>/MANIFEST.txt` matches the deployed bundle's `etag` / `last-modified`.
- **Applies to:** every tagged release. Category: release/deploy traps; recurring errors.
- **Staleness risk:** retires when `scripts/release.sh` becomes authoritative end-to-end (Level 5 maturity target).
- **Action added:** Release PM hard stop.
- **Linked files:** `.claude/agents/fieldops-release-pm.md`, `docs/fieldops3i_task_routing_protocol.md` §4.6.

### L-RPM-003 — Post-deploy smoke is mandatory on every runtime release

- **Date:** Round-2 audit
- **Commit / PR:** `e0da6a2`
- **Agent:** Release PM
- **Event:** prior to Round-2, post-deploy smoke was assumed; not always run.
- **Mistake or discovery:** "deployed and looks fine" is not verification.
- **Root cause:** human-in-the-loop step easy to skip when the visible UI looks normal.
- **Prevention rule:** every runtime release runs the post-deploy smoke (APP_VERSION matches, headers fresh, console clean across roles, audit_log writes flowing). STOP if any check fails; rollback per ROLLBACK.md.
- **Applies to:** every Pages deploy. Category: release/deploy traps.
- **Staleness risk:** invariant.
- **Action added:** Release PM hard stop.
- **Linked files:** `.claude/agents/fieldops-release-pm.md`.

### L-RPM-004 — DB-track readiness is a release prerequisite

- **Date:** Phase 2 design
- **Commit / PR:** PR #26
- **Agent:** Release PM
- **Event:** Phase 2 release decisions depend on Database PM PASS for the same SHA on the target environment.
- **Mistake or discovery:** Release PM cannot independently certify a release that includes SQL.
- **Root cause:** track interdependence.
- **Prevention rule:** Release PM reads `tracks/database-track.md` for any release that includes a migration. Database PM verdict for the target environment must be PASS.
- **Applies to:** every SQL-inclusive release. Category: release/deploy traps; cross-track coordination.
- **Staleness risk:** invariant.
- **Action added:** Release PM reporting format includes "Database PM verdict" line.
- **Linked files:** `.claude/agents/fieldops-release-pm.md`, `tracks/database-track.md`.

---

## fieldops-release-agent (legacy)

### L-RA-001 — Hotfix versions follow `vMAJOR.MINOR.PATCH.HOTFIX`

- **Date:** v1.4.0.1 ship
- **Commit / PR:** `cafc4c3` + `6e9f175`
- **Agent:** Release agent (legacy)
- **Event:** hotfix release used 4-part version `v1.4.0.1`. Original `release.sh` regex rejected it.
- **Mistake or discovery:** the release script must allow hotfix-suffix versions; otherwise hotfixes can't tag.
- **Root cause:** original regex assumed `v1.2.3`.
- **Prevention rule:** `release.sh` accepts `vMAJOR.MINOR.PATCH(.HOTFIX)?`. Verify before any hotfix tag.
- **Applies to:** every hotfix release. Category: release/deploy traps.
- **Staleness risk:** retires when scripts/release.sh becomes authoritative.
- **Action added:** Release agent verifies the regex on hotfix.
- **Linked files:** `scripts/release.sh`, `CHANGELOG.md` v1.4.0.1 entry.

---

## fieldops-test-agent (legacy)

### L-TA-001 — Manual matrix is supplementary once Tier 4-5 land

- **Date:** memory system landing
- **Commit / PR:** N/A (forward rule)
- **Agent:** Test agent (legacy)
- **Event:** today the manual `TEST_MATRIX.md` is the only operational coverage.
- **Mistake or discovery:** when Tier 4-5 land in CI, the manual matrix should reduce to a sampling check, not full execution.
- **Root cause:** absent automation today; manual is the floor.
- **Prevention rule:** revisit `TEST_MATRIX.md` scope at every QA tier graduation. Don't double-run automated coverage.
- **Applies to:** every release after Tier 4 lands. Category: release/deploy traps; recurring errors.
- **Staleness risk:** retire when Tier 4-5 are operational.
- **Action added:** Release PM checklist includes "manual matrix scope appropriate for current QA tier coverage?"
- **Linked files:** `TEST_MATRIX.md`, `.claude/agents/fieldops-qa-test-automation-agent.md`.
