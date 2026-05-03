Recommended model: Claude Opus
Mode: Normal

Use agents:
- fieldops-release-agent
- fieldops-test-agent
- fieldops-orchestrator

Review FieldOps3i release readiness.

Do not deploy production unless explicitly instructed.
Do not push.
Do not tag.
Do not change Supabase.

Review:
- VERSION
- CHANGELOG.md
- RELEASING.md
- ROLLBACK.md
- TEST_MATRIX.md
- git status
- changed files

Output:
- Release type: none/patch/minor/major
- Version impact
- Changelog status
- Staging verification status
- Role testing status
- Rollback target
- Blockers
- Ready for production Yes/No
