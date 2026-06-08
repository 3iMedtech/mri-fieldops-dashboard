#!/bin/sh
# Activate FieldOps3i git hooks (commit-guard). Run once per clone.
#
#   sh scripts/install-hooks.sh
#
# Points git at the version-controlled hooks in scripts/githooks so the
# CLAUDE.md §7 review gates fire on every commit that touches index.html or a
# migration. Undo with: git config --unset core.hooksPath
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
chmod +x "$ROOT/scripts/githooks/pre-commit"
git -C "$ROOT" config core.hooksPath scripts/githooks
echo "Installed: core.hooksPath → scripts/githooks"
echo "commit-guard active. Bypass after running gates with: FIELDOPS_GATES_OK=1 git commit ..."
