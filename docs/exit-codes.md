# Exit Codes — claude-audit-gate

Every audit run produces exactly one exit code. Codes are stable and should not be reassigned.

| Code | Meaning | Severity | Action |
|------|---------|----------|--------|
| **0** | PASS | NONE | No issues found. Proceed. |
| **10** | Non-blocking findings | LOW / MEDIUM | Review recommended but not required. |
| **11** | No changes | — | Empty diff, nothing to audit. |
| **20** | Blocking findings | HIGH / CRITICAL | MUST fix before proceeding. |
| **21** | Auth failure | — | Not logged in or ping failed. Run `claude` interactively. |
| **22** | Invalid JSON | — | Claude output unparseable. Check raw output in `.audit/`. |
| **23** | Rate limited | — | 429 session limit. Wait for reset (6pm CST). |
| **24** | Not a git repo | — | Run from a git repository or init one. |
| **25** | Claude not found | — | Install Claude Code via winget. |

## Exit code flowchart

```
                ┌──────────┐
                │  START   │
                └────┬─────┘
                     │
              ┌──────▼──────┐
              │ claude in   │── NO ──→ exit 25
              │ PATH?       │
              └──────┬──────┘
                     │ YES
              ┌──────▼──────┐
              │ logged in?  │── NO ──→ exit 21
              └──────┬──────┘
                     │ YES
              ┌──────▼──────┐
              │ rate limit? │── YES ─→ exit 23
              └──────┬──────┘
                     │ NO
              ┌──────▼──────┐
              │ git repo?   │── NO ──→ exit 24
              └──────┬──────┘
                     │ YES
              ┌──────▼──────┐
              │ any diff?   │── NO ──→ exit 11
              └──────┬──────┘
                     │ YES
              ┌──────▼──────┐
              │  Claude     │
              │  audit      │
              └──────┬──────┘
                     │
              ┌──────▼──────┐
              │ rate limit? │── YES ─→ exit 23
              └──────┬──────┘
                     │ NO
              ┌──────▼──────┐
              │ valid JSON? │── NO ──→ exit 22
              └──────┬──────┘
                     │ YES
              ┌──────▼──────┐
              │ severity?   │── HIGH/CRIT → exit 20
              │             │── LOW/MED → exit 10
              │             │── NONE → exit 0
              └─────────────┘
```
