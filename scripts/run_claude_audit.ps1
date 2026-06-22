# run_claude_audit.ps1
# Single entry-point wrapper for OpenCode / watchdog.
# All Claude audit calls MUST go through this script.
# Do NOT scatter claude invocation logic across multiple locations.

param(
    [switch]$SelfTest,
    [switch]$SkipClaude,
    [switch]$SkipPreflight,
    [string]$UseFixture = ""
)

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$AuditScript = Join-Path $ScriptDir "claude_audit.ps1"

if (-not (Test-Path $AuditScript)) {
    Write-Error "claude_audit.ps1 not found at $AuditScript"
    exit 25
}

# Build argument list for claude_audit.ps1
$args = @()

if ($SelfTest)      { $args += "-SelfTest" }
if ($SkipClaude)    { $args += "-SkipClaude" }
if ($SkipPreflight) { $args += "-SkipPreflight" }
if ($UseFixture)    { $args += "-UseFixture"; $args += $UseFixture }

# Ensure proxy env vars are set
$env:HTTP_PROXY  = "http://127.0.0.1:7897"
$env:HTTPS_PROXY = "http://127.0.0.1:7897"
$env:NO_PROXY    = "localhost,127.0.0.1"

# Run the actual audit script
& powershell -NoProfile -ExecutionPolicy Bypass -File $AuditScript @args
exit $LASTEXITCODE
