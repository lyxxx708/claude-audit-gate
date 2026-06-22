# Changelog — claude-audit-gate

All notable changes to this project are documented here.

## [1.0.0] — 2026-06-22

### Added
- Core audit engine (`scripts/claude_audit.ps1`)
- CLI wrapper (`scripts/run_claude_audit.ps1`)
- Exit code system: 0/10/11/20/21/22/23/24/25
- Preflight checks: `claude auth status` + headless ping
- `--json-schema` support with file-path fallback
- Markdown code block JSON extraction from Claude wrapped output
- Severity derivation from `findings[].severity` when top-level missing
- Rate-limit detection (429 → exit 23) before JSON parse
- Fixture gate testing (`tests/test-fixtures.ps1`, 6 fixtures)
- Doctor diagnostics (`scripts/doctor.ps1`)
- Install/uninstall scripts (`scripts/install_to_workspace.ps1`, `scripts/uninstall_from_workspace.ps1`)
- OpenCode tool, command, and config integration
- Documentation: design, exit-codes, auth, troubleshooting

### Auth
- Local Claude Pro login state is the default auth path
- `CLAUDE_CODE_OAUTH_TOKEN` supported but optional
- `claude setup-token` deferred — blocked in current environment
- No `ANTHROPIC_API_KEY` by default
