# Memory — Runtime Track

**Read by:** `fieldops-runtime-pm`, `fieldops-runtime-integration-agent`, `fieldops-qa-test-automation-agent`, `fieldops-ui-agent` (legacy advisory).
**Format:** see [`../MEMORY_PROTOCOL.md`](../MEMORY_PROTOCOL.md) §4.
**Cap:** ~30 entries.

---

## fieldops-runtime-pm

### L-RTPM-001 — SQL apply precedes runtime deploy on the same env

- **Date:** Phase 2 design
- **Commit / PR:** PR #26
- **Agent:** Runtime PM
- **Event:** Phase 2 runtime depends on `app_can_write()` policies (0004) and the V2 backfill (0005).
- **Mistake or discovery:** deploying runtime first surfaces RLS rejections in the live app.
- **Root cause:** track-independent thinking.
- **Prevention rule:** Runtime PM HOLDs deploy until Database PM PASS for the same environment is recorded in STATE.md.
- **Applies to:** every Phase 2+ change that depends on new policies/helpers. Category: runtime/UI traps; recurring errors.
- **Staleness risk:** until Phase 2 ships fully to production.
- **Action added:** Runtime PM hard stop checks DB PM verdict on target env.
- **Linked files:** `.claude/agents/fieldops-runtime-pm.md`, `docs/fieldops3i_task_routing_protocol.md` §3.4.

---

## fieldops-runtime-integration-agent

### L-RTI-001 — Manager UX comes from `_userRole`, not email allowlist

- **Date:** Phase 2 design
- **Commit / PR:** PR #26
- **Agent:** Runtime integration
- **Event:** legacy `canManagePM()` had an email allowlist branch. Phase 2 removes it.
- **Mistake or discovery:** client-side role checks must use the DB-resolved `_userRole` (via `_sb.rpc('app_user_role')`), not hardcoded emails.
- **Root cause:** historical bootstrap convenience before `user_roles` existed.
- **Prevention rule:** every `canManagePM()` call site reads `_userRole`. No email comparisons in role checks.
- **Applies to:** `index.html` role gating; new write buttons; `manager-mode` body class. Category: runtime/UI traps.
- **Staleness risk:** until Phase 2 runtime ships.
- **Action added:** runtime-integration design hard stop. QA Tier 4 (planned) tests every role × write-path combination.
- **Linked files:** `index.html` (`canManagePM`, `_userRole` references), `.claude/agents/fieldops-runtime-integration-agent.md`.

### L-RTI-002 — Auth fallback is mandatory; default to viewer, never admin

- **Date:** Phase 2 design
- **Commit / PR:** PR #26
- **Agent:** Runtime integration
- **Event:** `_sb.rpc('app_user_role')` may fail (network, missing seed, RPC error).
- **Mistake or discovery:** without a fallback, the app would either crash or grant admin by accident.
- **Root cause:** RPC integration designs commonly omit failure paths.
- **Prevention rule:** RPC failure → JWT-claim fallback → `'viewer'` default. Never default to `'admin'` or `'manager'`.
- **Applies to:** every RPC-resolved role check. Category: runtime/UI traps; SQL/RLS traps.
- **Staleness risk:** until Phase 2 runtime ships.
- **Action added:** runtime-integration hard stop.
- **Linked files:** `.claude/agents/fieldops-runtime-integration-agent.md`.

### L-RTI-003 — XLSX upsert excludes lifecycle fields

- **Date:** Phase 2 design
- **Commit / PR:** PR #26
- **Agent:** Runtime integration
- **Event:** XLSX upsert-by-code rewrite must NOT overwrite Manager-set `status` / `de_installed_at`.
- **Mistake or discovery:** naive upsert overwrites every column from the XLSX, destroying lifecycle state.
- **Root cause:** PostgREST `upsert(rows)` defaults to writing all columns.
- **Prevention rule:** XLSX-owned column list is explicit. Lifecycle fields (`status`, `de_installed_at`, `lifecycle_event_id`, etc.) are excluded from the payload.
- **Applies to:** every XLSX upload path. Category: runtime/UI traps; Supabase environment traps.
- **Staleness risk:** invariant after Phase 2.
- **Action added:** runtime-integration hard stop. QA Tier 4 (planned) test asserts lifecycle fields unchanged after XLSX re-upload.
- **Linked files:** `index.html` (XLSX upload section), `.claude/agents/fieldops-runtime-integration-agent.md`.

### L-RTI-004 — De-install requires type-asset-code confirmation

- **Date:** Phase 2 design (product decision #7)
- **Commit / PR:** PR #26
- **Agent:** Runtime integration
- **Event:** de-install is destructive UX (asset disappears from active list).
- **Mistake or discovery:** a single click without confirmation risks accidental de-install.
- **Root cause:** original design used a plain confirm() dialog.
- **Prevention rule:** de-install modal requires the operator to type the asset code literally. Submit button is disabled until typed input matches.
- **Applies to:** de-install workflow. Category: runtime/UI traps; operator-confusion traps.
- **Staleness risk:** until de-install workflow ships.
- **Action added:** runtime-integration hard stop.
- **Linked files:** `.claude/agents/fieldops-runtime-integration-agent.md`.

### L-RTI-005 — XLSX safe-upsert preserves app-created config_assets rows on real production-shape data

- **Date:** 2026-05-11
- **Commit / PR:** PR #27 / B6 Session X PASS at `cb6fa19`
- **Agent:** Runtime Integration
- **Event:** B6 Session X (Phase 2 review §6.4 critical regression test) ran the full production-shape XLSX upload (402 tickets, 24 IB assets, 13 contracts, 43 new ambiguities auto-detected) against staging with a synthetic `TEST-IB-AAA` row present in `config_assets`. The synthetic row survived unchanged across all 13 columns and was later cleaned up via operator-approved DELETE.
- **Mistake or discovery:** the B4-partial `xlsxOwnedConfigCols` whitelist (13 columns) plus `_sb.from('config_assets').upsert(deduped, { onConflict: 'code' })` correctly preserves rows whose codes are NOT in the XLSX. The pre-B4 `delete().neq('code','__sentinel__') + insert()` pattern would have wiped TEST-IB-AAA.
- **Root cause:** safe-upsert pattern is correct; whitelist is correct; on-conflict key (`code`) is correct.
- **Prevention rule:** every change to the XLSX upload path must preserve the synthetic-row regression test (insert manual row → upload XLSX that excludes it → confirm row survives). Once QA Tier-4 Playwright harness lands, add this as an automated check. Operator approval phrases for the test setup: `approved, create TEST-IB-AAA on staging` (insert) and `approved, cleanup TEST-IB-AAA on staging` (delete).
- **Applies to:** XLSX upload path; future XLSX-related changes. Category: runtime/UI traps; release/deploy traps; recurring errors.
- **Staleness risk:** invariant unless the XLSX flow changes.
- **Action added:** B6 Session X (X1 setup → X2 upload → X3 verify survival → X5 cleanup) is the canonical regression test for the XLSX flow.
- **Linked files:** `index.html` (`xlsxOwnedConfigCols` whitelist, `applyUploadedData` flow); `docs/v1.4.1_phase2_review.md` §6.4.

### L-RTI-006 — Manager role MUST be driven by `app_user_role` RPC + `_userRole`; never email allowlists

- **Date:** 2026-05-11
- **Commit / PR:** PR #27 / B6 Session D M1 PASS at `cb6fa19`
- **Agent:** Runtime Integration
- **Event:** B6 Session D M1 confirmed Manager (`manager@3imedtech.com`) signed in on staging at `cb6fa19` resolved to `_userRole: "manager"` via RPC 200/`"manager"`, with `viewer_mode: true`, `manager_mode: true`, `superadmin_mode: false`. Phase 1.5 gap closed (in v1.4.0.1 baseline this same user resolved to `_userRole: "viewer"` because JWT `app_metadata.role='viewer'`).
- **Mistake or discovery:** the RPC + user_roles seed mechanism is the operational source of truth for Manager-tier privilege, not any email comparison.
- **Root cause:** verified empirically; B1 RPC integration + B2 email-allowlist removal both work as designed for Manager.
- **Prevention rule:** never reintroduce any email-based check for Manager privilege in `canManagePM()`, `applyRoleRestrictions()`, route gates, or any handler. Always use `_userRole === 'manager'` (or `canManagePM()` which composes admin + manager). B2 removed the email allowlist in two places (`canManagePM` body and the `manager-mode` body class branch). Reaffirms and provides B6 evidence for `L-RTI-001`.
- **Applies to:** every role-gating site in runtime code. Category: runtime/UI traps.
- **Staleness risk:** invariant until B1 RPC is replaced or `user_roles` schema changes.
- **Action added:** B6 Session D M1 is the canonical regression test for Manager role resolution.
- **Linked entries:** `L-RTI-001` (original Manager-UX-from-`_userRole` rule).
- **Linked files:** `index.html` (`applyRoleRestrictions`, `canManagePM`, `manager-mode` body class — refer to current `cb6fa19` content for exact line numbers).

### L-RTI-007 — RPC failure path: Manager degrades to viewer; admin only via valid JWT; non-admin NEVER becomes admin

- **Date:** 2026-05-11
- **Commit / PR:** PR #27 / B6 Session F PASS at `cb6fa19`
- **Agent:** Runtime Integration
- **Event:** B6 Session F (F1–F4) blocked `*rpc/app_user_role*` via DevTools network condition and verified failure behavior across all three roles:
  - F1 Admin: `_userRole='admin'` via JWT fallback (Admin's JWT `app_metadata.role='admin'`); admin UI works.
  - F2 Manager: `_userRole='viewer'` via JWT fallback (Manager's JWT is v1.4.0.1 baseline `'viewer'`); `manager_mode: false`; admin UI hidden; **degrades safely without privilege escalation**.
  - F3 Engineer: `_userRole='viewer'`; no change.
  - F4 Unblock + reload as Manager: `_userRole='manager'` restored; `manager_mode: true`; admin UI returns.
- **Mistake or discovery:** the B1 implementation's `try/catch` + `let resolvedRole = 'viewer'` safe default + JWT fallback correctly produces a NEVER-escalates outcome under RPC failure.
- **Root cause:** B1 design is correct; staging behavior matches design.
- **Prevention rule:** never modify `applyRoleRestrictions()` in a way that allows `resolvedRole` to be `'admin'` without a valid corresponding source (RPC returning literal `'admin'` AND the `app_user_role` schema check OR JWT `app_metadata.role === 'admin'`). The default-to-viewer pattern is load-bearing. Reaffirms and provides B6 evidence for `L-RTI-002`.
- **Applies to:** `applyRoleRestrictions()` and any future role-resolution function. Category: runtime/UI traps; recurring errors; **security**.
- **Staleness risk:** invariant.
- **Action added:** B6 Session F (F1–F4) is the canonical RPC-failure regression test. Repeat for any change to the role-resolution path.
- **Linked entries:** `L-RTI-002` (original auth-fallback / never-default-admin rule).
- **Linked files:** `index.html` (`applyRoleRestrictions` — refer to current `cb6fa19` content).

### L-RTI-008 — Manager XLSX upload remains admin-only until cmc_contracts safe-upsert ships

- **Date:** 2026-05-11
- **Commit / PR:** PR #27 / B6 Session D M6 PASS at `cb6fa19`
- **Agent:** Runtime Integration
- **Event:** B6 Session D M6 confirmed that the XLSX upload control is not visible/usable to Manager on staging at `cb6fa19`. The function-level Admin gate at `applyUploadedData` (`if(_userRole !== 'admin'){ alert('This action requires admin access.'); return; }`) correctly blocks Manager. Inner `cmc_contracts` admin guard from B4-complete is also intact as defense-in-depth.
- **Mistake or discovery:** per Phase 2 review §1 Q1 ("Manager XLSX permission: allow, but only after XLSX upload is converted to safe upsert behavior"), Manager XLSX permission is conditional on cmc_contracts conversion. B4-partial converted config_assets safely (proven via `L-RTI-005`). cmc_contracts conversion was deferred to v1.4.2 pending a UNIQUE constraint on `sn`. **Until cmc_contracts conversion ships, Manager XLSX must remain admin-only.**
- **Root cause:** the function-level Admin gate is the operative safety. The cmc_contracts section also has an inner Admin guard (B4-complete) as defense-in-depth.
- **Prevention rule:** any commit that relaxes the function-level Admin gate at `applyUploadedData` MUST coincide with: (a) cmc_contracts safe-upsert ready, (b) a UNIQUE constraint on `cmc_contracts.sn` via a separate migration approved by sql-rls-safety, and (c) updated B6 Session D M6 expected behavior. Until all three land, the gate stays at `_userRole !== 'admin'`.
- **Applies to:** future v1.4.2 cmc_contracts conversion work. Category: runtime/UI traps; release/deploy traps; recurring errors.
- **Staleness risk:** retires when v1.4.2 cmc_contracts safe-upsert ships with the UNIQUE constraint.
- **Action added:** B6 Session D M6 is the regression test for this gate.
- **Linked files:** `index.html` (Admin gate inside `applyUploadedData`); B4-complete commit `34e5433`; future `0007_*` migration if it lands.

### L-RTI-009 — Production confirmation of role-gating three-layer defense (CSS / JS / RLS) + Audit Log dual gate

- **Date:** 2026-05-12
- **Commit / PR:** PR #27 merge `0c4e9d1`; production runtime smoke browser-driven
- **Agent:** Runtime Integration
- **Event:** Browser-driven production smoke verified the full three-layer role gate on the production-deployed runtime payload (`cb6fa19` content served via merge commit `0c4e9d1`, content-length 629,540 B). Three roles tested in sequence. Manager resolved to `_userRole='manager'` via RPC 200 (production-side confirmation of Phase 1.5 gap closure). Engineer's per-row Edit / De-install buttons exist in DOM (defense-in-depth, 25 each via `title` attribute query) but are CSS-hidden — `getBoundingClientRect()` reports `height=0` and `getComputedStyle()` reports the `.mgr-plus { display: none; }` rule active for `viewer-mode`. IB Header index 13 (Actions column) carries `class="mgr-plus"` and is CSS-hidden for Engineer; header index 12 (History column) is unclassed and visible to all roles, with 25 visible History buttons for Engineer (matches `L-RTI-004` read-only-all-roles spec). Manager XLSX upload control hidden on production (`upload_xlsx_visible_count: 0`) — production confirmation of `L-RTI-008`. **Manager's Audit Log access is gated at TWO layers**: nav-hidden (no Audit Log nav item in Manager's sidebar) AND route-gated (direct `location.hash='#/auditlog'` redirects to Dashboard without rendering the audit table — `audit_table_present: false`, `has_showing_500_banner: false`).
- **Mistake or discovery:** confirmation, not surprise — reaffirms `L-RTI-001` / `L-RTI-006` / `L-RTI-008` with production evidence. The Audit Log gate is more robust than a nav-only gate would be: nav-level hiding alone would be bypassable via DevTools URL navigation, but the route-level redirect prevents the audit data from rendering regardless of how the URL is set. Defense-in-depth works.
- **Root cause:** not a defect; design held on production.
- **Prevention rule:** future role-related changes to `applyRoleRestrictions()`, `canManagePM()`, the `.mgr-plus` CSS rule, or any route handler must preserve **all three layers** of defense AND **route-level gates** for sensitive UI surfaces (Audit Log today; future Renew UI; future v1.4.2 cmc_contracts upload). Surface-level nav-hiding alone is insufficient.
- **Applies to:** every role-gating site in runtime code. Category: runtime/UI traps; **security**.
- **Staleness risk:** invariant until role architecture changes.
- **Action added:** production-side regression baseline captured in `automation/STATE.md` production smoke table.
- **Linked entries:** `L-RTI-001` (Manager UX from `_userRole`), `L-RTI-006` (Manager RPC role on staging), `L-RTI-008` (Manager XLSX admin-only), `L-RTI-004` (History read-only all-roles).
- **Linked files:** `index.html` (`applyRoleRestrictions`, `canManagePM`, `.mgr-plus` CSS, route handlers), `automation/STATE.md`.

### L-RTI-010 — Production confirmation of RPC failure path security: Manager degrades to viewer, never to admin

- **Date:** 2026-05-12
- **Commit / PR:** PR #27 production runtime smoke §E
- **Agent:** Runtime Integration
- **Event:** Production §E security smoke confirmed Manager under blocked `app_user_role` RPC degrades to viewer (`_userRole='viewer'`, `manager_mode=false`, `superadmin_mode=false`, `can_manage_pm=false`). **Manager never escalated to admin under RPC failure.** Mechanism: a JS-level `window.fetch` wrapper intercepted any request whose URL matched `/rpc\/app_user_role/i` and returned `Promise.reject(new TypeError('NetworkError: Blocked by §E smoke test'))`. Direct `_sb.rpc('app_user_role')` then returned `{ data: null, status: 0, error: "NetworkError: …" }`; `_sb.rpc('app_can_write')` continued to succeed (only `app_user_role` blocked, by design). After `applyRoleRestrictions()` re-run under the block, `_userRole` resolved to `viewer` via JWT fallback (Manager's JWT `app_metadata.role` is the v1.4.0.1 baseline `'viewer'`). The interceptor was uninstalled after the test (`window._origFetchE5` restored to native `window.fetch` and deleted from `window` scope); Manager then recovered to `_userRole='manager'` after the next `applyRoleRestrictions()` call (RPC 200/"manager"). **Production server state was never altered** — the interceptor lived only in the operator's browser tab and is fully reversible.
- **Mistake or discovery:** reaffirms `L-RTI-002` and `L-RTI-007` with production-side evidence. The JWT fallback path correctly produces `viewer` for Manager (whose JWT `app_metadata.role` is `'viewer'`) and `admin` for Admin (whose JWT is `'admin'`). The default-to-viewer pattern at the top of `applyRoleRestrictions()` is load-bearing — `let resolvedRole = 'viewer'` plus a try/catch wrapping the RPC plus an explicit JWT fallback yields the security-correct outcome.
- **Root cause:** B1 design (`L-RTI-001` / `L-RTI-002`) is correct. Production matches staging Session F behavior verified at `cb6fa19` per `L-RTI-007`.
- **Prevention rule:** never modify `applyRoleRestrictions()` in a way that allows `resolvedRole` to become `'admin'` without a valid corresponding source — i.e., either RPC returning literal `'admin'` AND passing the `app_user_role` schema check, OR JWT `app_metadata.role === 'admin'`. Any future "default to higher privilege on uncertainty" change is a security regression. The production-side §E smoke can be re-run at any time without touching server state — the fetch-interceptor + `applyRoleRestrictions()` re-call is a fully client-side, fully reversible test.
- **Applies to:** `applyRoleRestrictions()` and any future role-resolution function. Category: runtime/UI traps; recurring errors; **security**.
- **Staleness risk:** invariant.
- **Action added:** production-side §E security smoke is the canonical regression for the RPC-failure security invariant. Repeat for any change to the role-resolution path. The fetch-interceptor mechanism is documented for reuse.
- **Linked entries:** `L-RTI-002` (original auth-fallback / never-default-admin rule), `L-RTI-007` (B6 Session F staging evidence).
- **Linked files:** `index.html` (`applyRoleRestrictions`), `docs/v1.4.1_phase2_production_apply_runbook.md` §12.5.

---

## fieldops-qa-test-automation-agent

### L-QA-001 — Coverage gaps must be surfaced before PM PASS

- **Date:** Round-2 audit
- **Commit / PR:** `e0da6a2`
- **Agent:** QA test automation
- **Event:** Tier 1-5 are PLANNED; Tier 6 (manual matrix) is the only operational layer.
- **Mistake or discovery:** without explicit coverage-gap reporting, PMs may PASS while assuming coverage they don't have.
- **Root cause:** absence-of-evidence feels like evidence-of-absence.
- **Prevention rule:** every QA report explicitly lists Tier 1-5 status (COVERED / PLANNED / GAP). Runtime PM and Release PM may not PASS without acknowledging the gaps.
- **Applies to:** every release decision until Tier 1-5 land. Category: recurring errors; release/deploy traps.
- **Staleness risk:** retire each tier as it lands in CI.
- **Action added:** QA reporting format requires the tier matrix.
- **Linked files:** `.claude/agents/fieldops-qa-test-automation-agent.md`, `docs/fieldops3i_task_routing_protocol.md` §4.5.

### L-QA-002 — Regression tests land in the same PR as the fix

- **Date:** memory system landing
- **Commit / PR:** N/A (forward rule)
- **Agent:** QA test automation
- **Event:** test-after-the-fact rarely happens in this project.
- **Mistake or discovery:** without CI enforcement, the bug class can recur.
- **Root cause:** no automated harness yet.
- **Prevention rule:** every fix PR includes the test that would have caught the bug. If test infrastructure for that tier doesn't exist yet, the PR notes the planned test and the tier needed.
- **Applies to:** every bug-fix PR. Category: recurring errors.
- **Staleness risk:** invariant.
- **Action added:** Release PM hard stop checks for matching test (or a planned-test note for non-existent tiers).
- **Linked files:** `.claude/agents/fieldops-qa-test-automation-agent.md`.
