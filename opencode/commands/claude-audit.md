# /claude-audit — Slash Command

Run Claude Code as an independent auditor on the current workspace.

## Usage

```
/claude-audit [--skip-preflight] [--skip-claude] [--self-test] [--use-fixture <path>]
```

## Options

| Flag | Description |
|------|-------------|
| (none) | Full audit: preflight → diff → Claude → gate |
| `--skip-preflight` | Skip auth and headless checks |
| `--skip-claude` | Diff validation only (no Claude call) |
| `--self-test` | Create temp git repo and run smoke test |
| `--use-fixture <path>` | Use local fixture JSON for gate testing |

## Exit codes

| Exit | Meaning |
|------|---------|
| 0 | PASS (NONE severity) |
| 10 | LOW/MEDIUM non-blocking |
| 11 | No diff to audit |
| 20 | HIGH/CRITICAL blocking |
| 21 | Auth failure |
| 22 | Invalid JSON |
| 23 | Rate limited |
| 24 | Not a git repo |
| 25 | Claude not found |

## Mechanism

Delegates to `scripts\run_claude_audit.ps1`, which delegates to `scripts\claude_audit.ps1`.
