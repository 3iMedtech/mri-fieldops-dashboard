# Releasing

How to cut a new tagged release of the MRI FieldOps Dashboard.

We use [Semantic Versioning](https://semver.org/):

- **MAJOR** (`x.0.0`) — breaking changes (DB schema rewrite, role model change, anything that requires user re-onboarding)
- **MINOR** (`1.x.0`) — new features, backward-compatible
- **PATCH** (`1.0.x`) — bug fixes only

Rule of thumb: if a careful user wouldn't notice anything different about how they use the app, it's a PATCH. If they'd notice a new tab or feature, it's a MINOR. If their workflow changes, it's a MAJOR.

---

## The release flow

```
feature branch  →  staging  →  main  →  tag  →  snapshot
   (dev)         (validate)   (prod)   (lock)  (archive)
```

Every tagged release must have:
1. Been merged to `main` (so the prod URL serves it)
2. Been validated on `staging` first (no exceptions for prod-only releases)
3. A row in `CHANGELOG.md`
4. A snapshot in `releases/<tag>/`
5. An updated `VERSION` file
6. An updated `window.APP_VERSION` block in `index.html`

---

## Cutting a release — step by step

### 0. Pre-flight
```bash
git checkout main
git pull origin main
git status                   # must be clean
```

### 1. Make sure staging is the source
The release commit lives on `main`, but it should already have lived on `staging` first. Confirm:
```bash
git log --oneline staging..main    # should be empty — main has nothing staging doesn't
git log --oneline main..staging    # should be empty too — fully merged
```
If either has commits, sort that out before tagging.

### 2. Pick the version
```bash
cat VERSION                    # current
```
Bump per semver. For this guide assume new version = `1.1.0`.

### 3. Update `VERSION` and the in-bundle version block
```bash
echo "1.1.0" > VERSION
```

In `index.html`, find the `APP VERSION` comment block near the top of the main `<script>` and update both lines:
```js
window.APP_VERSION = '1.1.0';
window.APP_BUILD   = { version: '1.1.0', released: 'YYYY-MM-DD', commit: '<short-sha-after-commit>' };
```
(Commit hash is filled in **after** the commit — use a placeholder, then amend in step 6.)

### 4. Update `CHANGELOG.md`
Add a new `## [1.1.0] — YYYY-MM-DD` block above the previous entry. Follow [Keep a Changelog](https://keepachangelog.com/) sections: `### Added`, `### Changed`, `### Fixed`, `### Removed`. Keep entries terse and user-facing.

### 5. Run the release script
```bash
./scripts/release.sh 1.1.0
```
This script:
- Verifies the working tree is clean and on `main`
- Verifies `VERSION` matches the argument
- Verifies `CHANGELOG.md` has a `## [1.1.0]` heading
- Snapshots `index.html` to `releases/v1.1.0/`
- Writes `releases/v1.1.0/MANIFEST.txt` with size, sha256, and source commit

If any check fails, the script aborts without modifying anything.

### 6. Commit, tag, push
```bash
git add VERSION CHANGELOG.md index.html releases/v1.1.0/
git commit -m "release: v1.1.0"
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin main
git push origin v1.1.0
```

(If you used a placeholder commit hash in `window.APP_BUILD`, amend it now: edit the file to the real short-sha from `git rev-parse --short HEAD`, then `git commit --amend --no-edit` and re-push. **Do this only if no one else has pulled yet.**)

### 7. Verify prod
Wait ~60s for Pages to rebuild:
```bash
curl -sI https://3imedtech.github.io/mri-fieldops-dashboard/index.html | grep -iE "etag|last-modified"
```
Open the app, hard-refresh, check console:
```js
window.APP_VERSION   // should be '1.1.0'
window.APP_BUILD     // should match the commit
```

### 8. Announce
Post in the team channel:
```
v1.1.0 released. Notes: <link to CHANGELOG section>. Rollback target if needed: v1.0.0.
```

---

## Hotfix flow

When prod is broken and you can't wait for normal staging cycle:

1. **Roll back first if users are blocked.** See `ROLLBACK.md`.
2. Branch from the last good tag: `git checkout -b hotfix/<bug> v1.0.0`
3. Make the minimal fix.
4. Push to `staging`, validate the failing flow.
5. Merge to `main`, cut a PATCH release (`1.0.1`) following the steps above.

Do **not** skip the staging validation step even for hotfixes. Ten extra minutes here prevents a rollback-of-rollback.

---

## What NOT to do

- ❌ Tag a commit that wasn't promoted via staging
- ❌ Edit a published tag (`git tag -d` + re-push) — pull from anyone tracking is now broken
- ❌ Skip the snapshot in `releases/` — that's the only thing that lets us diff bundles between releases when investigating regressions
- ❌ Skip the CHANGELOG entry — future-you will not remember what `v1.4.2` was
- ❌ Bump MAJOR for a new feature — bump MINOR. Reserve MAJOR for genuine breakage.
