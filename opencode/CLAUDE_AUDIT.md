# CLAUDE_AUDIT.md — Independent Code Auditor

This workspace has claude-audit-gate installed.

## Capability

You can invoke an independent Claude Code audit on your own changes:

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_claude_audit.ps1
```

## When to use

- Before staging code
- After completing a milestone
- When security or correctness is critical
- When asked "did you review your changes?"

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | PASS |
| 10 | Non-blocking findings |
| 20 | Blocking findings |
| 21/22/23/24/25 | Infrastructure issue (auth, JSON, rate-limit, repo, missing) |

## Integration

- Tool: `.opencode/tools/claude_audit.ts`
- Command: `/claude-audit`
- Script: `scripts/run_claude_audit.ps1`

## Restrictions

- Do NOT call `claude setup-token` — it is blocked in this environment
- Do NOT call `claude --bare`
- Do NOT kill node.exe
- Auth is via local Claude Pro login state; `CLAUDE_CODE_OAUTH_TOKEN` is optional
