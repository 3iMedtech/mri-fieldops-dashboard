# MRI FieldOps Dashboard — Deployment Guide

This project is a single-page dashboard deployed through GitHub Pages and backed by Supabase.

This guide describes deployment concepts and safety expectations. Do not use it as permission to deploy production without approval.

---

## Environments

### Local

Use for development and early testing.

### Staging

Use for validation before production.

Staging must be used for:

- role testing
- UI validation
- dashboard checks
- Supabase integration verification
- release candidate review

### Production

Production changes require explicit approval.

---

## Deployment Safety Rules

Do not deploy, push, publish, or change production config without explicit approval.

Before production deployment:

- working tree is clean
- branch is correct
- staging validation is complete
- role checks are complete where relevant
- changelog/version impact is handled
- rollback target is known
- production approval is explicit

---

## Supabase Safety

The anon public key may exist in frontend code if intended. The service-role key must never be used in the dashboard or committed.

Never expose:

- service-role key
- database password
- private tokens
- personal passwords
- production-only secrets

Supabase/Auth/RLS changes require separate review and approval.

---

## GitHub Pages Verification

After deployment, verify headers:

```bash
curl -sI https://3imedtech.github.io/mri-fieldops-dashboard/index.html | grep -iE "etag|last-modified"
```

Verify app version in browser console:

```js
window.APP_VERSION
window.APP_BUILD
```

---

## Deployment-Related Testing

Use `TEST_MATRIX.md` based on affected areas.

At minimum for runtime changes:

- Admin/Superadmin login
- Manager login if affected
- Engineer/Viewer login if affected
- Dashboard loads
- affected page loads
- role gates remain correct
- browser console has no new app errors

---

## Product Design Deployment Note

Product design changes must be tested like runtime UI changes.

Confirm:

- design tokens are preserved
- role workflows remain familiar
- mobile layout is usable
- accessibility is not weakened
- changes improve function, not just appearance
