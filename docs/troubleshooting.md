# Troubleshooting — claude-audit-gate

## Common issues

### Exit 21 — Auth failure

```
[claude_audit] AUTH FAILURE: not authenticated
```

**Cause**: Claude Code is not logged in.

**Fix**: Run `claude` interactively in a terminal. Complete the browser-based login (opens `claude.ai`). Do NOT run `claude setup-token` — that endpoint is currently blocked.

### Exit 23 — Rate limited

```
[claude_audit] RATE LIMIT detected during headless ping
[claude_audit] reset hint: 6pm (Asia/Shanghai)
```

**Cause**: Daily Claude Pro session limit reached. Reset is typically 6pm Asia/Shanghai.

**Fix**: Wait for reset. The audit script writes `.audit\CLAUDE_RATE_LIMIT.json` with the reset hint. Do not retry aggressively.

### Exit 24 — Not a git repo

```
[claude_audit] NOT A GIT REPOSITORY — audit requires git repo
```

**Cause**: Current directory is not a git repository (or git is not installed).

**Fix**: 
```powershell
git init
git add .
git commit -m "initial"
```
Or `cd` to a git repository.

### Exit 22 — Invalid JSON

```
[claude_audit] unparseable JSON output — no JSON object found
```

**Cause**: Claude output did not contain parseable JSON with a `status` field.

**Fix**: Check `.audit\claude-review.raw.json` for the raw output. This can happen if the prompt is ambiguous. If recurring, check `--json-schema` support in your Claude version.

### Exit 25 — Claude not found

```
[claude_audit] claude executable not found in PATH
```

**Cause**: Claude Code is not installed or not in PATH.

**Fix**: 
```powershell
winget install --id Anthropic.ClaudeCode
```

### Proxy issues

If `HTTP_PROXY` / `HTTPS_PROXY` are not set, the script falls back to direct connection. Most domestic users need the proxy:

```powershell
$env:HTTP_PROXY = "http://127.0.0.1:7897"
$env:HTTPS_PROXY = "http://127.0.0.1:7897"
```

The script sets these automatically. Override by pre-setting them in your environment.

## Gathering diagnostic info

```powershell
# Run doctor
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\doctor.ps1

# Check last audit output
Get-Content .audit\claude-review.raw.json

# Check rate limit record
Get-Content .audit\CLAUDE_RATE_LIMIT.json
```
