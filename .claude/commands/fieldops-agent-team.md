Recommended model: Claude Opus
Mode: Normal

For phase-level or cross-track work, invoke `fieldops-delivery-orchestrator` first. This command is for module-level or scoped work only and does not bypass Delivery Orchestrator, PM-layer, approval-phrase, SQL, staging, production, merge, tag, deploy, or release gates.

Use agents:
- fieldops-orchestrator
- fieldops-test-agent
- fieldops-release-agent

Review the requested FieldOps3i task before implementation.

Do not edit.
Do not commit.
Do not push.
Do not create PR.
Do not deploy production.
Do not change Supabase.

Read:
- FIELDOPS_QUICK_CONTEXT.md
- PROJECT_MAP.md
- CLAUDE.md
- TEST_MATRIX.md

Output:
- Task summary
- Affected modules
- Affected files likely
- Risk level
- Recommended specialist agents
- Test plan
- Rollback plan
- Approval needed Yes/No
