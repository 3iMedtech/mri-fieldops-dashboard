# Rollback Guide

When to use: prod is broken and you need to get back to a known-good build fast.

The release tags (e.g. `v1.0.0`) are the rollback anchors. Each tag was a verified-on-staging, then-promoted-to-prod build.

---

## TL;DR — get prod back to v1.0.0 in 2 minutes

```bash
git fetch --tags
git checkout main
git reset --hard v1.0.0
git push --force-with-lease origin main
```

GitHub Pages will rebuild and serve the v1.0.0 bundle within ~1 minute. Verify with:

```bash
curl -sI https://3imedtech.github.io/mri-fieldops-dashboard/index.html | grep -iE "etag|last-modified"
```

The etag should match the one recorded in `releases/v1.0.0/MANIFEST.txt`.

---

## When to roll back vs. forward-fix

| Symptom | Roll back? | Why |
|---|---|---|
| App white-screens for everyone | **Yes** | Users blocked, fix later |
| KPI numbers obviously wrong | **Yes** | Trust damage compounds |
| One tab broken, rest works | Maybe | If admin-only or low-traffic, forward-fix |
| Cosmetic bug | No | Forward-fix in next push |
| Data looks wrong but app loads | **Investigate first** | Could be DB, not bundle — rollback won't help |

---

## Rollback procedure (full)

### 1. Confirm the bundle is the cause
Open browser DevTools → Console:
```js
console.log(window.APP_VERSION, window.APP_BUILD)
```
- If `APP_VERSION` matches the broken release, the bundle is at fault → continue.
- If `APP_VERSION` is older or undefined, the user is on a stale cache → ask them to hard-refresh first.

### 2. Pick the rollback target
```bash
git tag --list 'v*' --sort=-v:refname
```
Pick the most recent tag prior to the broken release.

### 3. Reset main to the target tag
```bash
git fetch --tags
git checkout main
git reset --hard <tag>          # e.g. v1.0.0
git push --force-with-lease origin main
```

> `--force-with-lease` (not `--force`) refuses the push if someone else updated `main` while you were rolling back. Always prefer it.

### 4. Verify prod
Wait ~60s for GitHub Pages to rebuild, then:
```bash
curl -sI https://3imedtech.github.io/mri-fieldops-dashboard/index.html | grep -iE "etag|last-modified"
```
Compare etag to `releases/<tag>/MANIFEST.txt`.

### 5. Roll staging back too
Otherwise the next staging push will re-promote the broken commit:
```bash
git checkout staging
git reset --hard <tag>
git push --force-with-lease origin staging
```

### 6. Communicate
- Post in the team channel: which version is now live, what was rolled back, who's fixing forward.
- Open a tracking issue with the bad commit hash so the fix lands on a fresh branch, not on `main` directly.

---

## Database rollback — separate concern

Bundle rollback does **not** roll back DB schema or data.

- **Schema migrations** are forward-only by convention. If a migration broke prod, write a *new* corrective migration — do not try to "un-apply" the old one.
- **Data corruption** from a bad XLSX upload: restore from the daily encrypted backup. See `scripts/RESTORE.md` for the procedure.
- **Always check before rolling back** whether the bad release ran a destructive migration. If yes, talk to the DB owner first; bundle rollback alone may leave the app pointing at a schema it doesn't understand.

---

## What to do AFTER a rollback

1. **Reproduce the bug locally** against the bad commit. Don't fix what you can't reproduce.
2. **Write a regression test or staging check** that would have caught it.
3. **Fix on a branch**, push to staging, exercise the failed path manually, then promote to main.
4. **Document the incident** in CHANGELOG under a `### Fixed` entry for the next release.

---

## Anti-patterns — don't do these

- ❌ `git push --force` (without `--with-lease`) — clobbers other people's pushes
- ❌ Reverting individual commits with `git revert` for an emergency rollback — slow, error-prone, and leaves a messy history. Use `git reset --hard <tag>` instead.
- ❌ Editing `index.html` on `main` directly to "patch around" the bug — bypasses staging, risks a second outage
- ❌ Rolling back without telling the team — someone will push a new commit on top of stale main and undo your rollback
