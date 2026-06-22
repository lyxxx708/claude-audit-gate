# Design — claude-audit-gate

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Workspace                         │
│                                                      │
│  .opencode/tools/claude_audit.ts  (OpenCode tool)   │
│         │                                            │
│         ▼                                            │
│  scripts/run_claude_audit.ps1  (CLI wrapper)         │
│         │                                            │
│         ▼                                            │
│  scripts/claude_audit.ps1  (core audit engine)       │
│         │                                            │
│         ├─ preflight: claude auth status             │
│         ├─ preflight: claude -p headless ping        │
│         ├─ git diff → .audit/input.diff              │
│         ├─ claude -p (audit) → .audit/review.raw.json│
│         └─ severity gate → exit code                 │
│                                                      │
│  .audit/  (runtime artifacts, gitignored)            │
└─────────────────────────────────────────────────────┘
```

## Layers

### Layer 0: Core engine (`scripts/claude_audit.ps1`)

The only file that calls `claude`. All flags (`--output-format json`, `--max-turns 3`, `--no-session-persistence`) are set here. Supports:

- Preflight: `claude auth status` + `claude -p` ping
- `--json-schema` with file-path fallback (writes schema to temp file)
- Markdown code block JSON extraction from Claude wrapped output
- Severity derivation from `findings[].severity` if top-level missing
- Rate-limit detection (429 → exit 23) before JSON parse
- `-UseFixture` mode for offline gate testing
- `-SkipClaude` mode for diff-only validation
- `-SelfTest` mode for isolated smoke tests

### Layer 1: CLI wrapper (`scripts/run_claude_audit.ps1`)

Single-argument wrapper that canonicalizes proxy env vars and delegates to Layer 0. This is the **only entry point** that OpenCode/watchdog should call.

### Layer 2: OpenCode tool (`.opencode/tools/claude_audit.ts`)

TypeScript tool definition that lets OpenCode agents invoke the audit via `task()` with proper argument passing.

## Exit codes

| Code | Meaning | Trigger |
|------|---------|---------|
| 0 | PASS | NONE severity |
| 10 | Non-blocking | LOW/MEDIUM findings |
| 11 | No changes | Empty diff |
| 20 | Blocking | HIGH/CRITICAL findings |
| 21 | Auth failure | Not logged in, ping failed |
| 22 | Invalid JSON | Claude output unparseable |
| 23 | Rate limited | 429 session limit |
| 24 | Not a git repo | Wrong directory |
| 25 | Claude missing | Not in PATH |

## Auth strategy (see docs/auth.md)

1. **Preferred**: Local Claude Pro login state (`claude auth status` → `loggedIn: true`)
2. **Optional**: `CLAUDE_CODE_OAUTH_TOKEN` (for CI)
3. **Deferred**: `claude setup-token` (OAuth device flow blocked in current environment)

## No-force policy

- No `claude setup-token` calls
- No `claude --bare`
- No `Taskkill /F /IM node.exe`
- No token/callback URL written to logs or commits
