Recommended model: Claude Sonnet
Mode: Normal

For phase-level or cross-track work, invoke `fieldops-delivery-orchestrator` first. This command is for module-level or scoped work only and does not bypass Delivery Orchestrator, PM-layer, approval-phrase, SQL, staging, production, merge, tag, deploy, or release gates.

Use agents:
- fieldops-orchestrator
- specialist agent based on affected module
- fieldops-test-agent

Implement only the approved FieldOps3i change.

Do not deploy production.
Do not change Supabase unless explicitly approved.
Do not edit protected areas unless explicitly approved.
Do not make broad rewrites.

Before editing, confirm:
- files to change
- risk level
- test plan
- rollback plan

After editing, output:
- Summary
- Files changed
- Root cause or reason
- Test result
- What could not be tested
- Rollback steps
- Ready for commit Yes/No
