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

### L-RPM-005 — APP_VERSION label may lag the runtime payload between production deploy and Gate F tag

- **Date:** 2026-05-12
- **Commit / PR:** PR #27 merge `0c4e9d1`; production smoke PASS at `APP_VERSION='1.4.0.1'`
- **Agent:** Release PM
- **Event:** Production serves the Phase 2 runtime payload (byte-identical to staging `cb6fa19`, content-length 629,540 B, etag `"6a033a22-99b24"`). DevTools `window.APP_VERSION` still reports `"1.4.0.1"` and `APP_BUILD.tag` reports `"v1.4.0.1"` because `VERSION`, `CHANGELOG.md`, `releases/v1.4.1/MANIFEST.txt`, and the `APP_VERSION` constant inside `index.html` were not bumped by the merge commit. Those edits are deferred to a future Gate F (`approved, tag v1.4.1`) Release-PM session that authors VERSION + CHANGELOG.md + releases/v1.4.1/MANIFEST.txt + the APP_VERSION constant bump together.
- **Mistake or discovery:** the merge-now-tag-later pattern produces a documented intermediate state where the runtime is Phase 2 but the version label is the pre-Phase-2 hotfix label. This is by design — the production runbook §3 gate matrix and §12.2 explicitly call this out. **Not a bug.**
- **Root cause:** clean separation between "ship the code" and "tag the release" — required because `pages-deploy.yml` auto-deploys on merge but VERSION/CHANGELOG/releases author steps are deliberately gated to a separate Release-PM session.
- **Prevention rule:** post-deploy verification must explicitly accept `APP_VERSION` lag as expected. The smoke checklist for v1.4.x and later phase work should set `APP_VERSION === "<pre-phase-version>"` as the expected pre-Gate-F value, **not** the in-progress phase label. Document this in any future production runbook. Gate F closes the lag by aligning all four artifacts (VERSION + APP_VERSION constant + CHANGELOG + snapshot) per `L-RPM-002` before pushing the tag.
- **Applies to:** every cross-environment phase that uses the merge-now-tag-later pattern. Category: release/deploy traps; operator-confusion traps.
- **Staleness risk:** invariant pattern.
- **Action added:** production runbook §12.2 documents the expected lag. Future runbooks must include the same note.
- **Linked entries:** `L-RPM-002` (VERSION+APP_VERSION+CHANGELOG+snapshot align before tag).
- **Linked files:** `docs/v1.4.1_phase2_production_apply_runbook.md` §12.2, `automation/STATE.md`.

### L-RPM-006 — Canonical tag gate: VERSION + index.html metadata + CHANGELOG + releases/<tag>/MANIFEST + production sha256 byte-equality

- **Date:** 2026-05-13
- **Commit / PR:** Release commit `905ac6f`; tag `v1.4.1` (object `59a5da6`)
- **Agent:** Release PM
- **Event:** v1.4.1 tag gate executed end-to-end with all four artifacts aligned per `L-RPM-002` plus an explicit **production-side byte-equality check**. The chain: (1) `VERSION` bumped `1.4.0.1` → `1.4.1`. (2) `index.html` metadata constants updated (`window.APP_VERSION`, `window.APP_BUILD` { version + released + tag }, `const APP_VERSION`, `const APP_RELEASE_DATE`) — **NO runtime logic edits**. (3) `CHANGELOG.md` new `## [1.4.1] — 2026-05-13` entry. (4) `scripts/release.sh 1.4.1` validated VERSION ↔ CHANGELOG heading ↔ `window.APP_VERSION = '1.4.1'` and produced `releases/v1.4.1/MANIFEST.txt` (sha256 `58118b41…`, size_bytes 629533) + `releases/v1.4.1/index.html` snapshot. (5) Commit `905ac6f`, push to main → `pages-deploy.yml` run 25776828153 succeeded in 30s. (6) Annotated tag `v1.4.1` on `905ac6f`, pushed. (7) **Byte-equality verification:** `curl -s prod/index.html | shasum -a 256` returned `58118b41…` exactly — match to MANIFEST sha256. The deployed bundle IS the repo's snapshot bit-for-bit.
- **Mistake or discovery:** the UTC-date pitfall. `release.sh` auto-stamps `date: $(date -u +%Y-%m-%d)` into MANIFEST.txt, which can disagree with operator-context dates if the tag gate fires near a UTC day boundary. First snapshot wrote `date: 2026-05-13` while CHANGELOG/index.html had `2026-05-12`; reconciled by updating CHANGELOG header + `released: '2026-05-13'` + `'13 May 2026'` and re-running release.sh after a `rm -rf releases/v1.4.1`. **Always reconcile after the first `release.sh` run if dates differ.**
- **Root cause:** UTC vs. local-time mismatch when working across the midnight boundary. `release.sh` is correct to use UTC for canonical date.
- **Prevention rule:** for future tag gates: (a) before running `release.sh`, confirm the current UTC date with `date -u +%Y-%m-%d` and use that date in CHANGELOG header + `window.APP_BUILD.released` + `const APP_RELEASE_DATE`. (b) If `release.sh` writes a different date than what you used, `rm -rf releases/v<tag>`, update CHANGELOG + index.html dates to match MANIFEST, re-run. (c) **After `pages-deploy.yml` completes, run `curl -s <prod-url>/index.html | shasum -a 256` and assert byte-equality with `grep ^sha256 releases/v<tag>/MANIFEST.txt`** — this is the canonical byte-equality acceptance check and is stronger than any single DevTools eval.
- **Applies to:** every tag gate. Category: release/deploy traps; recurring errors.
- **Staleness risk:** invariant pattern.
- **Action added:** the byte-equality check is added to the post-tag smoke checklist for v1.4.x and later. Future production runbooks must include the curl-sha256 verification step.
- **Linked entries:** `L-RPM-002` (four-artifact alignment baseline), `L-RPM-003` (post-deploy smoke mandatory), `L-RPM-005` (APP_VERSION label lag pre-tag), `L-RA-001` (hotfix `vMAJOR.MINOR.PATCH(.HOTFIX)?` accepted by release.sh).
- **Linked files:** `scripts/release.sh`, `releases/v1.4.1/MANIFEST.txt`, `releases/v1.4.1/index.html`, `CHANGELOG.md`, `VERSION`, `index.html`.

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
