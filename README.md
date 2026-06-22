# claude-audit-gate

**Independent Claude Code audit gate for OpenCode workspaces.**

Wrap any git diff with a structured Claude Code audit, get a deterministic exit code, and
block dangerous changes before they merge. Designed for human-out-of-loop code review.

## Quick Install

```powershell
# Clone the repo
cd C:\Users\lyxxx\repos
git clone <repo-url> claude-audit-gate

# Install into your workspace (creates symlinks)
powershell -File claude-audit-gate\scripts\install_to_workspace.ps1 -Workspace "C:\path\to\project"

# Or with copy mode
powershell -File claude-audit-gate\scripts\install_to_workspace.ps1 -Workspace "C:\path\to\project" -Mode copy
```

## Quick Use

```powershell
# Full audit (preflight + diff + Claude)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_claude_audit.ps1

# Skip preflight (for re-runs)
.\scripts\run_claude_audit.ps1 -SkipPreflight

# Skip Claude (diff check only)
.\scripts\run_claude_audit.ps1 -SkipClaude

# Test fixtures (no Claude needed)
.\tests\test-fixtures.ps1

# Run diagnostics
.\scripts\doctor.ps1
```

## Exit Codes

| Code | Meaning | Action |
|------|---------|--------|
| **0** | PASS | Proceed |
| **10** | LOW/MEDIUM | Review recommended |
| **11** | No changes | Nothing to audit |
| **20** | HIGH/CRITICAL | Blocking — must fix |
| **21** | Auth failure | Run `claude` to login |
| **22** | Invalid JSON | Check `.audit/*.raw.json` |
| **23** | Rate limited | Wait for 6pm reset |
| **24** | Not a git repo | `cd` to a repo |
| **25** | Claude not found | `winget install Anthropic.ClaudeCode` |

## OpenCode Integration

After install into a workspace, use:

- **Slash command**: `/claude-audit`
- **Tool**: `task(category="quick", prompt="Run claude audit on current diff")`
- **Direct**: `powershell -File scripts\run_claude_audit.ps1`

## Auth Strategy

| Method | Status | How |
|--------|--------|-----|
| Local Claude Pro login | ✅ Current default | `claude auth status` → loggedIn |
| `CLAUDE_CODE_OAUTH_TOKEN` | ⚠️ Optional | Set user env var |
| `claude setup-token` | 🚫 Deferred | Blocked in current env; do NOT call |
| `ANTHROPIC_API_KEY` | ❌ Not recommended | Switches to API billing |

## Limitations

- Requires Claude Code (winget) installed and logged in
- Requires git repository
- Daily session limit applies to Claude Pro (resets 6pm CST)
- `--json-schema` has a BOM encoding issue on PS 5.1 (fallback prompt-only parser works)
- `setup-token` OAuth flow is blocked by Cloudflare in the current environment

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) or run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\doctor.ps1
```
