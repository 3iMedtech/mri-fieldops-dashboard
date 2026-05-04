# Graphify Usage Guide

Graphify helps with architecture and dependency understanding. It is not the source of truth.

---

## Current Status

Status: **fresh** — regenerated 2026-05-04 on branch `docs/fieldops-ai-foundation-v3-design-ready` at HEAD `0ff0a9f`.

| Field | Value |
|---|---|
| Refresh date | 2026-05-04 |
| Branch | `docs/fieldops-ai-foundation-v3-design-ready` |
| HEAD | `0ff0a9f` (`docs: strengthen FieldOps AI foundation and product design guidance`) |
| Command | `graphify update .` |
| Output folder | `graphify-out/` (15 nodes · 27 edges · 2 communities · 0 LLM tokens) |
| Previous output archived to | `docs/archive/graphify-out-pre-foundation-v3/` (was generated 2026-04-27) |

Before relying on Graphify for architecture decisions:

1. Confirm when it was generated (see refresh date above).
2. Confirm which command generated it (see above).
3. Confirm whether it reflects the current codebase (see HEAD above).
4. Compare findings against current source files.

---

## Source of Truth Order

1. Current source files
2. Current documentation
3. Current changelog/release notes
4. Fresh Graphify output
5. Archived Graphify output as historical reference only

---

## When To Use Graphify

Use Graphify for:

- architecture review
- dependency mapping
- impact analysis
- major refactor planning
- codebase structure questions
- identifying affected modules before risky changes

---

## When Not To Use Graphify

Do not use Graphify for:

- normal UI polish
- small bug fixes
- text changes
- styling changes
- release notes
- simple documentation updates
- routine staging verification
- product design trend review unless architecture impact is involved

---

## Safe Refresh Process

1. Confirm `graphify-out/` exists.
2. Archive old output first.
3. Do not delete old output permanently.
4. Confirm the exact command before running.
5. Ask approval before overwriting `graphify-out/`.
6. Regenerate.
7. Update this file with refresh date, command, and status.
8. Treat generated output as support context, not final truth.

Example archive command:

```bash
mkdir -p docs/archive
mv graphify-out docs/archive/graphify-out-pre-foundation-v3
```

Example refresh command, only if confirmed for this repo:

```bash
graphify update .
```

---

## After Refresh — 2026-05-04

- **Refresh date:** 2026-05-04
- **Command used:** `graphify update .`
- **Output folder:** `graphify-out/` (4 entries: `GRAPH_REPORT.md`, `graph.html`, `graph.json`, `cache/`)
- **Major modules identified by graphify:**
  - **Community 0 — render helpers** (cohesion 0.33): `esc()`, `renderEmail()`, `renderPMTable()`, `renderRenewalsTable()`, `renderSlaTable()`
  - **Community 1 — data fetch + date helpers** (cohesion 0.6): `getOverduePMs()`, `getSlaBreaches()`, `getUpcomingRenewals()`, `isoDate()`, `sbSelect()`, `todayUTCDate()`
  - **Cross-community bridges:** `sbSelect()`, `todayUTCDate()` (high betweenness centrality)
  - **Top god node:** `renderEmail()` — 5 edges
- **Known limitations:**
  - **Single-file SPA blind spot.** Graphify only catches small named utility helpers. The major page renderers (`renderDashboard`, `renderHistory`, `renderAssets`, `renderTeam`, `renderEngperf`, `renderAuditLog`, etc.), the auth pipeline, role gates, XLSX upload parser, PM completion logic, and 4 modals are **not** in the graph.
  - **Structurally identical to 2026-04-27 run** despite v1.2.0 adding ~99,713 words to `index.html` (sortable headers, KPI operational indicators, Reports merged into Dashboard, Cmd+K search, empty states, radiogroup polish). Same 15 nodes / 27 edges / 2 communities / `graph.json` SHA1 = `a7d69cb0…`. v1.2.0 features did not introduce new top-level utility functions.
  - **No cross-file edges.** SQL migrations (`db/migrations/`), GitHub Actions workflows, archived releases, and other docs are not in the corpus — only `index.html`.
  - **High-risk dependency areas not represented** (auth/RLS/audit-log/XLSX/PM logic). For protected-area work, follow `CLAUDE.md` §4 + direct source review, not Graphify.
- **Reviewer:** Claude Sonnet 4.6 — automated refresh per FieldOps Graphify rules (CLAUDE.md §6). Human approval pending before commit.

### Old vs new comparison

| Field | 2026-04-27 (archived) | 2026-05-04 (current) | Diff |
|---|---|---|---|
| Nodes | 15 | 15 | unchanged |
| Edges | 27 | 27 | unchanged |
| Communities | 2 | 2 | unchanged |
| Top god node | `renderEmail()` (5 edges) | `renderEmail()` (5 edges) | unchanged |
| Corpus words | 126,535 | 226,248 | +99,713 (+78.8%) |
| `graph.json` SHA1 | `a7d69cb0…` | `a7d69cb0…` | identical |
| `GRAPH_REPORT.md` | dated 2026-04-27 | dated 2026-05-04 | only date + word count differ |

**Interpretation:** v1.2.0 grew `index.html` significantly but did not change the high-level utility-function shape. Graphify confirms no architectural drift at the helper layer; it does not (and cannot) confirm that v1.2.0's new feature surface area is structurally healthy — that requires source review and the staging audit (see `docs/STAGING_AUDIT_2026-04-26.md`).

---

## Rule

If Graphify and current source files disagree, current source files win.
