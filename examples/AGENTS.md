# AGENTS.md — claude-audit-gate integration

This workspace has `claude-audit-gate` installed.

## Audit gate

Before completing any task, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_claude_audit.ps1
```

If exit code is 20 (HIGH/CRITICAL), read `.audit/claude-review.raw.json`, fix the findings, and re-audit.
If exit code is 10 (LOW/MEDIUM), review but may proceed.
If exit code is 0, proceed.

## Prohibited

- Do NOT call `claude setup-token`
- Do NOT call `claude --bare`
- Do NOT kill node.exe
- Do NOT expose token values in logs

## Auth

Current auth path: local Claude Pro login state.
`CLAUDE_CODE_OAUTH_TOKEN` may be set as an alternative (masked in logs).
