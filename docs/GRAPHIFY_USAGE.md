# Graphify Usage Guide

Graphify helps with architecture and dependency understanding. It is not the source of truth.

---

## Current Status

Status: `needs refresh unless regenerated after the latest foundation and app changes`

The existing Graphify output may have been created during an early stage of FieldOps3i. If it predates recent changes, treat it as stale.

Before relying on Graphify for architecture decisions:

1. Confirm when it was generated.
2. Confirm which command generated it.
3. Confirm whether it reflects the current codebase.
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

## After Refresh

Update this section:

- Refresh date:
- Command used:
- Output folder:
- Major modules identified:
- Known limitations:
- Reviewer:

---

## Rule

If Graphify and current source files disagree, current source files win.
