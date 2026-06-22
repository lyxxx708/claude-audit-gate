# Authentication — claude-audit-gate

## Auth priority

claude-audit-gate uses the first available auth method in this order:

| Priority | Method | Variable | Status |
|----------|--------|----------|--------|
| 1 | Local Claude Pro login state | (none — `claude auth status`) | ✅ Active |
| 2 | CI OAuth token | `CLAUDE_CODE_OAUTH_TOKEN` | ⚠️ Optional |
| 3 | API key | `ANTHROPIC_API_KEY` | ❌ Not recommended |

## Local Claude Pro login state (current default)

```
claude auth status
→ loggedIn: true
→ authMethod: claude.ai
→ subscriptionType: pro
```

This is the path used when `CLAUDE_CODE_OAUTH_TOKEN` is empty. The audit preflight checks `claude auth status` and `claude -p` to confirm the auth path works.

**Risk**: Login state may expire. If audit fails with exit 21, run `claude` interactively to re-authenticate.

## `CLAUDE_CODE_OAUTH_TOKEN` (optional)

If you have a valid OAuth token, set it as a Windows user-level environment variable:

```powershell
[Environment]::SetEnvironmentVariable("CLAUDE_CODE_OAUTH_TOKEN", "<token>", "User")
```

The audit script loads it automatically from both User and Process scopes.

## `ANTHROPIC_API_KEY` (not recommended)

Setting this switches billing from Claude Pro subscription to API-metered billing. The audit script warns when this is set.

## `claude setup-token` status: DEFERRED

`claude setup-token` produces no output in the current environment (6+ attempts, all timeouts). The OAuth device-flow endpoint appears blocked at the network level.

- Watchdog/OpenCode MUST NOT run `claude setup-token`
- Only a human should re-try if network conditions change
- Currently not a blocker: local login state works for headless audit

## Auth preflight flow

```
Start
  │
  ├─ Load CLAUDE_CODE_OAUTH_TOKEN from env (User → Process)
  ├─ Load ANTHROPIC_API_KEY from env
  ├─ Load ANTHROPIC_AUTH_TOKEN from env
  │
  ├─ claude auth status          ← proves local login metadata exists
  │     └─ loggedIn=false → exit 21
  │
  └─ claude -p "reply only: ok" --output-format json  ← authoritative runtime check
        ├─ 429 → exit 23 (rate limit)
        ├─ 403 → exit 21 (stale session — run `claude` interactive to refresh)
        ├─ other FAIL → exit 21
        └─ OK  → continue to diff + audit
```

**Critical distinction**: `claude auth status` only proves local login metadata exists.
`claude -p --output-format json` is the authoritative runtime check.
If auth status says `loggedIn=true` but `claude -p` returns 403, the local session token is
**stale** — re-authenticate by running `claude` interactively (not `setup-token`).

## Proxy and OAuth bypass

The script sets `NO_PROXY=localhost,127.0.0.1,platform.claude.com,claude.com` by default.
This allows the OAuth authentication flow (`claude.com`, `platform.claude.com`) to bypass the
local proxy, which is required for `claude auth login` to succeed.
