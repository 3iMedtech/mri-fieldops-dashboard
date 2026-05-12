# Rollback Guide

Use this when production is broken and needs to return to a known-good build quickly.

Release tags are rollback anchors. Each tag should represent a staging-verified build promoted to production.

---

## Rollback Decision

| Symptom | Roll back? | Notes |
|---|---|---|
| App white-screens for everyone | Yes | Users blocked |
| KPI numbers obviously wrong | Yes | Trust damage compounds |
| One low-traffic/admin-only tab broken | Maybe | Forward-fix may be safer |
| Cosmetic bug | No | Forward-fix |
| Data looks wrong but app loads | Investigate first | Could be DB/data, not bundle |

---

## Confirm Bundle Cause

Open browser console:

```js
console.log(window.APP_VERSION, window.APP_BUILD)
```

If the broken release is loaded, continue.

If version is old/undefined, ask user to hard refresh and verify cache first.

---

## Pick Rollback Target

```bash
git tag --list 'v*' --sort=-v:refname
```

Pick the most recent known-good tag before the broken release.

---

## Roll Back Main (preferred — tag-based revert; non-destructive)

**Default path: revert via a forward commit. Do NOT force-push to `main` unless the operator explicitly approves it.**

```bash
git fetch --tags
git checkout main
git pull --ff-only origin main

# Identify the commits introduced since <last-good-tag> on main
git log --oneline <last-good-tag>..HEAD

# Create a forward revert commit (no history rewrite)
git revert --no-edit <bad-commit-sha-1> [<bad-commit-sha-2> ...]

# Or for a clean range, use a single revert range:
# git revert --no-edit <last-good-tag>..HEAD --no-commit
# git commit -m "rollback: revert main to v<last-good-tag> state"

git push origin main
```

This produces a forward-moving commit that brings `main` to the same content as `<last-good-tag>` without rewriting history. Pages re-deploys from `main`. The audit trail (commits, tags, PRs) is preserved.

### Force-push escape hatch (operator-approved only)

If a forward revert is impractical (e.g., the bad release introduced data destruction that must be hidden in history, or there are too many merge commits to revert cleanly), the operator may explicitly authorize a destructive rollback. The exact approval phrase is:

> `approved, force rollback main to <tag>`

Only with that phrase, the destructive procedure is:

```bash
git fetch --tags
git checkout main
git reset --hard <tag>
git push --force-with-lease origin main
```

Even then, prefer `--force-with-lease` over plain `--force`. Communicate the rewrite to anyone with a local checkout.

---

## Verify Production

```bash
curl -sI https://3imedtech.github.io/mri-fieldops-dashboard/index.html | grep -iE "etag|last-modified"
```

Compare with `releases/<tag>/MANIFEST.txt`.

Open app and verify affected flow.

---

## Roll Back Staging Too

If staging still points to the broken commit, roll it back so the next staging promotion does not reintroduce the issue. Same default-vs-escape-hatch rule applies — prefer `git revert` to `git reset --hard`:

```bash
git checkout staging
git pull --ff-only origin staging
git revert --no-edit <bad-commit-sha-1> [<bad-commit-sha-2> ...]
git push origin staging
```

Force-push to `staging` is allowed only with an explicit `approved, force rollback staging to <tag>` phrase from the operator, and even then prefer `--force-with-lease`.

---

## Database Rollback Is Separate

Bundle rollback does not roll back schema or data.

- Schema migrations are forward-only by convention.
- If a migration broke production, write a corrective migration.
- If XLSX upload corrupted data, use the documented backup/restore process.
- Check whether the bad release included destructive database changes before assuming bundle rollback is enough.

---

## After Rollback

1. Communicate the rollback.
2. Open a tracking issue with broken release and bad commit.
3. Reproduce bug locally against bad commit.
4. Add a staging check or regression test.
5. Fix on a fresh branch.
6. Validate on staging.
7. Release a forward fix.

---

## Anti-patterns

- Do not use plain `git push --force`.
- Do not force-push to `main` or `staging` without the operator's explicit `approved, force rollback <branch> to <tag>` phrase. Default to `git revert` (forward commit, non-destructive).
- Do not patch directly on `main` during panic.
- Do not skip team communication.
- Do not ignore database/schema impact.
- Do not claim rollback succeeded without production verification.
- Do not assume a runtime rollback also rolls back schema — they are separate flows. Schema rollback uses `*_ROLLBACK_REVIEW_ONLY.sql` migrations, gated by the Database PM.
