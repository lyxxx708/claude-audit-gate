# OpenCode Integration — claude-audit-gate

## Overview

claude-audit-gate provides three OpenCode integration layers:

1. **Tool** (`.opencode/tools/claude_audit.ts`) — for agent `task()` calls
2. **Command** (`.opencode/commands/claude-audit.md`) — for `/claude-audit` slash command
3. **Config** (`.opencode/CLAUDE_AUDIT.md`) — for agent boot-time loading

## Tool usage

After installation, OpenCode agents can call:

```typescript
// Full audit with preflight
task(
  load_skills=["claude-audit"],
  run_in_background=false,
  prompt="Run claude audit on current diff"
)
```

The tool definition at `.opencode/tools/claude_audit.ts` delegates to:
```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_claude_audit.ps1
```

## Slash command

After installation, the `/claude-audit` slash command becomes available:

- `/claude-audit` — run full audit with preflight
- `/claude-audit --skip-preflight` — skip auth checks
- `/claude-audit --skip-claude` — diff check only (no Claude call)
- `/claude-audit --self-test` — temp repo smoke test

## Configuration

Add to `opencode.json`:

```json
{
  "skills": {
    "claude-audit": {
      "prompt": "See .opencode/CLAUDE_AUDIT.md"
    }
  }
}
```

## Calling from watchdog

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_claude_audit.ps1
```

## Calling from PowerShell (any workspace)

```powershell
# Inside workspace root (after install)
.\scripts\run_claude_audit.ps1

# With skip preflight
.\scripts\run_claude_audit.ps1 -SkipPreflight

# Self-test mode
.\scripts\run_claude_audit.ps1 -SelfTest
```
