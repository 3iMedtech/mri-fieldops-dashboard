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

## Roll Back Main

```bash
git fetch --tags
git checkout main
git reset --hard <tag>
git push --force-with-lease origin main
```

Use `--force-with-lease`, not plain `--force`.

---

## Verify Production

```bash
curl -sI https://3imedtech.github.io/mri-fieldops-dashboard/index.html | grep -iE "etag|last-modified"
```

Compare with `releases/<tag>/MANIFEST.txt`.

Open app and verify affected flow.

---

## Roll Back Staging Too

If staging still points to the broken commit, roll it back so the next staging promotion does not reintroduce the issue:

```bash
git checkout staging
git reset --hard <tag>
git push --force-with-lease origin staging
```

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
- Do not patch directly on `main` during panic.
- Do not skip team communication.
- Do not ignore database/schema impact.
- Do not claim rollback succeeded without production verification.
