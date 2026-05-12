Recommended model: Claude Opus
Mode: Normal

For phase-level or cross-track work, invoke `fieldops-delivery-orchestrator` first. This command is for module-level or scoped work only and does not bypass Delivery Orchestrator, PM-layer, approval-phrase, SQL, staging, production, merge, tag, deploy, or release gates.

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
