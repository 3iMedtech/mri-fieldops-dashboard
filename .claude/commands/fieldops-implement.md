Recommended model: Claude Sonnet
Mode: Normal

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
