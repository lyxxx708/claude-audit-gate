# Security — claude-audit-gate

## Token handling

- `CLAUDE_CODE_OAUTH_TOKEN` / `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN` are read from environment variables only
- Scripts never log, write, or echo full token values; only "SET"/"EMPTY" is reported
- No token values are committed to the repository
- `setup-token` is explicitly blocked and MUST NOT be run by watchdog/OpenCode

## Audit constraints

- The audit script never modifies files (read-only)
- No destructive commands are run
- No `Taskkill` or forced process termination
- No remote connections beyond the configured proxy

## Reporting

If you find a security issue, please open a GitHub issue rather than posting in public forums.
