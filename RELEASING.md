# Releasing

How to cut a new tagged release of the MRI FieldOps Dashboard.

We use Semantic Versioning:

- MAJOR (`x.0.0`): breaking changes, role model redesign, schema rewrite, or workflow changes requiring user re-onboarding
- MINOR (`1.x.0`): backward-compatible new features
- PATCH (`1.0.x`): bug fixes only

All production releases must be validated on staging first.

---

## Release Flow

```text
feature branch → staging → main → tag → snapshot
```

Every tagged release must have:

1. Been merged to `main`
2. Been validated on `staging`
3. A `CHANGELOG.md` entry
4. Updated `VERSION`
5. Updated in-bundle version block in `index.html`
6. Snapshot in `releases/<tag>/`
7. Known rollback target

---

## Pre-flight

```bash
git checkout main
git pull origin main
git status
```

Working tree must be clean.

Confirm staging and main are aligned before release:

```bash
git log --oneline staging..main
git log --oneline main..staging
```

Resolve differences before tagging.

---

## Version Update

1. Check current version:

```bash
cat VERSION
```

2. Update `VERSION`.
3. Update `window.APP_VERSION` and `window.APP_BUILD` in `index.html`.
4. Add a new `CHANGELOG.md` entry.

Do not update version for documentation-only guidance changes unless the release process requires it.

---

## Release Script

Run the project release script only after staging validation and approval:

```bash
./scripts/release.sh <version>
```

The script should verify:

- clean working tree
- correct branch
- `VERSION` matches argument
- changelog heading exists
- snapshot is created
- manifest is written

---

## Commit, Tag, Push

```bash
git add VERSION CHANGELOG.md index.html releases/<tag>/
git commit -m "release: v<tag>"
git tag -a v<tag> -m "Release v<tag>"
git push origin main
git push origin v<tag>
```

Do not push production without explicit approval.

---

## Production Verification

After GitHub Pages rebuilds:

```bash
curl -sI https://3imedtech.github.io/mri-fieldops-dashboard/index.html | grep -iE "etag|last-modified"
```

Open app and verify:

```js
window.APP_VERSION
window.APP_BUILD
```

Run relevant role checks from `TEST_MATRIX.md`.

---

## Release Agent Checklist

Use `fieldops-release-agent` before release.

Confirm:

- semver level is correct
- staging validation completed
- role testing completed where relevant
- changelog updated
- version updated
- snapshot created
- rollback target identified
- production approval received

---

## Hotfix Flow

If production is broken:

1. Roll back first if users are blocked.
2. Branch from last known good tag.
3. Apply minimal fix.
4. Push to staging and validate failing flow.
5. Merge to main.
6. Cut PATCH release.

Do not skip staging validation for hotfixes.

---

## What Not To Do

- Do not tag a commit that was not validated on staging.
- Do not edit published tags.
- Do not skip release snapshot.
- Do not skip changelog.
- Do not bundle unrelated changes.
- Do not deploy production from a normal implementation prompt.
