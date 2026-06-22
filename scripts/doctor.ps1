# scripts/doctor.ps1 -- Diagnostic check for claude-audit-gate

param(
    [string]$Workspace = ".",
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"
$issues = 0

Write-Host "claude-audit-gate -- Doctor Diagnostics"
Write-Host ""

# 1. claude executable
Write-Host "-- Step 1: Claude executable ------------------"
$claudePath = (Get-Command claude -ErrorAction SilentlyContinue).Source
if ($claudePath) {
    Write-Host "  PASS: claude found at: $claudePath"
    $version = & claude --version 2>&1
    Write-Host "  Version: $version"
} else {
    Write-Host "  FAIL: claude not found in PATH"
    $issues++
}
Write-Host ""

# 2. claude auth status (local login metadata)
Write-Host "-- Step 2: Claude auth status (metadata) ------"
Write-Host "  Note: only proves local login metadata."
Write-Host "  The headless ping (Step 3) is the authoritative runtime check."
try {
    $authRaw = & claude auth status 2>&1
    $authText = [string]$authRaw
    if ($authText -match '"loggedIn": true') {
        Write-Host "  PASS: loggedIn = true"
        if ($authText -match '"authMethod": "([^"]+)"') {
            Write-Host "  Auth method: $($matches[1])"
        }
        if ($authText -match '"subscriptionType": "([^"]+)"') {
            Write-Host "  Subscription: $($matches[1])"
        }
    } else {
        Write-Host "  FAIL: Not logged in. Run claude interactively."
        $issues++
    }
} catch {
    Write-Host "  FAIL: $($_.Exception.Message)"
    $issues++
}
Write-Host ""

# 3. claude headless ping
Write-Host "-- Step 3: Headless ping ----------------------"
$env:HTTP_PROXY  = "http://127.0.0.1:7897"
$env:HTTPS_PROXY = "http://127.0.0.1:7897"
$env:NO_PROXY    = "localhost,127.0.0.1,platform.claude.com,claude.com"
try {
    $pingRaw = & claude -p "reply only: ok" --output-format json 2>&1
    $pingText = [string]$pingRaw
    if ($pingText -match '"is_error":\s*false') {
        Write-Host "  PASS: Headless ping OK"
    } elseif ($pingText -match 'api_error_status.*403') {
        Write-Host "  FAIL: Stale local session (403). Run 'claude' interactively to re-authenticate."
        $issues++
    } elseif ($pingText -match 'api_error_status.*429') {
        Write-Host "  WARN: Rate limited (429). Resets 6pm CST."
    } else {
        Write-Host "  WARN: Unexpected response (may still work)"
    }
} catch {
    Write-Host "  WARN: Ping failed: $($_.Exception.Message)"
}
Write-Host ""

# 4. Git repo
Write-Host "-- Step 4: Git repository ---------------------"
try {
    $gitDir = git rev-parse --git-dir 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  PASS: Git repo detected"
        $diffLines = (git diff --no-ext-diff --unified=80 | Measure-Object -Line).Lines
        Write-Host "  Uncommitted diff lines: $diffLines"
    } else {
        Write-Host "  WARN: Not a git repo. Audit will exit 24."
    }
} catch {
    Write-Host "  WARN: Git check failed"
}
Write-Host ""

# 5. Proxy
Write-Host "-- Step 5: Proxy variables --------------------"
$proxyVars = @("HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY")
foreach ($v in $proxyVars) {
    $val = [Environment]::GetEnvironmentVariable($v, "Process")
    if ($val) {
        Write-Host "  PASS: $v = $val"
    } else {
        Write-Host "  INFO: $v not set (set by script automatically)"
    }
}
Write-Host ""

# 6. Auth env vars (masked)
Write-Host "-- Step 6: Auth environment variables ---------"
$oauthSet = $false
foreach ($varName in @("CLAUDE_CODE_OAUTH_TOKEN", "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN")) {
    $userVal = [Environment]::GetEnvironmentVariable($varName, "User")
    $procVal = [Environment]::GetEnvironmentVariable($varName, "Process")
    $isSet = ($userVal -ne $null -and $userVal -ne "") -or ($procVal -ne $null -and $procVal -ne "")
    if ($isSet) {
        Write-Host "  $($varName): SET"
        if ($varName -eq "CLAUDE_CODE_OAUTH_TOKEN") { $oauthSet = $true }
    } else {
        Write-Host "  $($varName): EMPTY"
    }
}
if (-not $oauthSet) {
    Write-Host "  No OAuth token. Using local Claude Pro login state."
}
Write-Host ""

# 7. Audit scripts
Write-Host "-- Step 7: Audit scripts ----------------------"
$auditScript = Join-Path $PSScriptRoot "claude_audit.ps1"
$wrapperScript = Join-Path $PSScriptRoot "run_claude_audit.ps1"
if (Test-Path $auditScript) {
    Write-Host "  PASS: $auditScript"
} else {
    Write-Host "  FAIL: $auditScript not found"
    $issues++
}
if (Test-Path $wrapperScript) {
    Write-Host "  PASS: $wrapperScript"
} else {
    Write-Host "  FAIL: $wrapperScript not found"
    $issues++
}
Write-Host ""

# Summary
Write-Host "Summary: $issues issue(s) found"
Write-Host "Auth: local Claude Pro login state (CI token: $(if ($oauthSet) {'SET'} else {'EMPTY'}))"
Write-Host "Entry: scripts\run_claude_audit.ps1"

exit $(if ($issues -gt 0) { 1 } else { 0 })
