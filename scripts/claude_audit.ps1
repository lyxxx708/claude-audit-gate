param(
    [string]$DiffFile       = ".audit\input.diff",
    [string]$OutputFile     = ".audit\claude-review.raw.json",
    [string]$RateLimitFile  = ".audit\CLAUDE_RATE_LIMIT.json",
    [string]$AuditDir       = ".audit",
    [switch]$SkipPreflight,
    [switch]$SelfTest,
    [switch]$SkipClaude,
    [string]$UseFixture     = "",
    [int]$TimeoutSec        = 300
)

$ErrorActionPreference = "Continue"

# ══════════════════════════════════════════════════════════
# EXIT CODES
#   0 = PASS (NONE severity)
#  10 = LOW/MEDIUM non-blocking findings
#  11 = NO_DIFF / NO_CHANGES (empty diff, nothing to audit)
#  20 = HIGH/CRITICAL blocking findings
#  21 = auth / headless failure
#  22 = invalid JSON or unparseable output
#  23 = rate / session limit
#  24 = not a git repo / wrong cwd
#  25 = claude executable missing
# ══════════════════════════════════════════════════════════

# ── SelfTest mode: create temp git repo + dummy diff ─────
if ($SelfTest) {
    Write-Host "[claude_audit] SelfTest mode — creating temp git repo..."
    $testDir = Join-Path $env:TEMP "claude_audit_selftest_$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $testDir | Out-Null
    Push-Location $testDir
    git init 2>&1 | Out-Null
    git config user.email "audit@test.local" 2>&1 | Out-Null
    git config user.name "Audit Test" 2>&1 | Out-Null
    "initial content" | Out-File -LiteralPath "test.txt" -Encoding utf8
    git add test.txt 2>&1 | Out-Null
    git commit -m "initial" 2>&1 | Out-Null
    "modified content with BUG: eval(userInput)" | Out-File -LiteralPath "test.txt" -Encoding utf8
    Write-Host "[claude_audit] SelfTest repo ready at $testDir"
    Write-Host "[claude_audit] NOTE: run 'Pop-Location; Remove-Item -Recurse -Force $testDir' to cleanup"
}

# ── Check claude executable ──────────────────────────────
$claudePath = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claudePath) {
    Write-Host "[claude_audit] claude executable not found in PATH"
    exit 25
}
Write-Host "[claude_audit] claude: $claudePath"

# ── Proxy ────────────────────────────────────────────────
$env:HTTP_PROXY  = "http://127.0.0.1:7897"
$env:HTTPS_PROXY = "http://127.0.0.1:7897"
$env:NO_PROXY    = "localhost,127.0.0.1"

# ── Auth env vars (from user-level, fallback to process) ─
foreach ($varName in @("CLAUDE_CODE_OAUTH_TOKEN", "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN")) {
    $userVal = [Environment]::GetEnvironmentVariable($varName, "User")
    $procVal = [Environment]::GetEnvironmentVariable($varName, "Process")
    if ($userVal -and -not $procVal) {
        [Environment]::SetEnvironmentVariable($varName, $userVal, "Process")
    }
}

if ($env:ANTHROPIC_API_KEY) {
    Write-Warning "[claude_audit] ANTHROPIC_API_KEY is set — may take precedence over Claude Pro login state."
}

# ── Ensure audit directory ───────────────────────────────
if (-not (Test-Path -LiteralPath $AuditDir)) {
    New-Item -ItemType Directory -Force -Path $AuditDir | Out-Null
}

# ── Helper: detect rate-limit from Claude output ─────────
function Test-RateLimited {
    param([string]$Text)
    try {
        $obj = $Text | ConvertFrom-Json -ErrorAction Stop
        if ($obj.api_error_status -eq 429) { return $true }
        if ($obj.is_error -and $obj.result -match "rate limit|session limit|usage limit|quota exceeded") {
            return $true
        }
    } catch { }
    if ($Text -match "(rate limit|session limit|usage limit|quota exceeded|resets \d)") {
        return $true
    }
    return $false
}

# ── Helper: extract reset hint ───────────────────────────
function Get-ResetHint {
    param([string]$Text)
    if ($Text -match "resets?\s+([^`"'\r\n\.]+)") {
        return $matches[1].Trim()
    }
    return $null
}

# ── Helper: write rate-limit record ──────────────────────
function Write-RateLimitRecord {
    param([string]$RawOutput, [string]$Source = "unknown")
    $resetHint = Get-ResetHint -Text $RawOutput
    $record = [ordered]@{
        timestamp  = (Get-Date -Format "o")
        source     = $Source
        message    = "Claude rate/usage limit reached"
        reset_hint = if ($resetHint) { $resetHint } else { $null }
        rawPreview = if ($RawOutput) { $RawOutput.Substring(0, [Math]::Min(500, $RawOutput.Length)) } else { "" }
    }
    $record | ConvertTo-Json -Depth 2 | Out-File -LiteralPath $RateLimitFile -Encoding utf8 -Force
    Write-Host "[claude_audit] rate-limit record written to $RateLimitFile"
    if ($resetHint) {
        Write-Host "[claude_audit] reset hint: $resetHint"
    }
}

# ══════════════════════════════════════════════════════════
# PREFLIGHT
# ══════════════════════════════════════════════════════════
if (-not $SkipPreflight) {
    Write-Host "[claude_audit] === PREFLIGHT ==="

    # 1. Auth status check
    Write-Host "[claude_audit] checking claude auth status..."
    $authRaw = ""
    try {
        $authRaw = & claude auth status 2>&1
        $authCode = $LASTEXITCODE
    } catch {
        $authRaw = $_.Exception.Message
        $authCode = 1
    }
    $authText = [string]$authRaw
    Write-Host "[claude_audit] auth status: loggedIn=$($authText -match '"loggedIn":\s*true')"

    if ($authCode -ne 0 -or $authText -match "not logged in|no credentials|unauthorized") {
        Write-Host "[claude_audit] AUTH FAILURE: not authenticated"
        Write-Host "[claude_audit] Run 'claude' interactively to login (NOT 'claude setup-token')."
        exit 21
    }

    # Identify auth source
    $oauthSet = [Environment]::GetEnvironmentVariable("CLAUDE_CODE_OAUTH_TOKEN", "User") -or [Environment]::GetEnvironmentVariable("CLAUDE_CODE_OAUTH_TOKEN", "Process")
    if ($oauthSet) {
        Write-Host "[claude_audit] auth source: CLAUDE_CODE_OAUTH_TOKEN"
    } else {
        Write-Host "[claude_audit] auth source: local Claude Pro login state (no OAuth token set)"
    }

    # 2. Headless ping
    Write-Host "[claude_audit] headless ping (claude -p 'reply only: ok')..."
    $pingRaw = ""
    try {
        $pingRaw = & claude -p "reply only: ok" --output-format json 2>&1
        $pingCode = $LASTEXITCODE
    } catch {
        $pingRaw = $_.Exception.Message
        $pingCode = 1
    }
    $pingText = [string]$pingRaw

    # Rate-limit during ping → exit 23
    if (Test-RateLimited -Text $pingText) {
        Write-Host "[claude_audit] RATE LIMIT detected during headless ping"
        Write-RateLimitRecord -RawOutput $pingText -Source "preflight-ping"
        exit 23
    }

    # Auth or network failure during ping
    if ($pingCode -ne 0) {
        if ($pingText -match "auth|403|unauthorized") {
            Write-Host "[claude_audit] AUTH FAILURE during headless ping"
            exit 21
        }
        Write-Host "[claude_audit] headless ping failed (exit=$pingCode): $pingText"
        exit 21
    }

    Write-Host "[claude_audit] headless ping OK"
} else {
    Write-Host "[claude_audit] preflight SKIPPED (--SkipPreflight)"
}

# ══════════════════════════════════════════════════════════
# MODE DISPATCH
#   fixture   → skip diff + Claude, load fixture, gate only
#   skip-claud→ diff only, exit 0 after diff
#   normal    → diff → Claude → gate
# ══════════════════════════════════════════════════════════

if ($UseFixture -ne "") {
    # ── FIXTURE MODE ─────────────────────────────────────
    Write-Host "[claude_audit] FIXTURE MODE — skipping git diff and Claude call"
    if (-not (Test-Path $UseFixture)) {
        Write-Host "[claude_audit] fixture file not found: $UseFixture"
        exit 22
    }
    $auditText = Get-Content -LiteralPath $UseFixture -Raw -Encoding utf8
    $auditText | Out-File -LiteralPath $OutputFile -Encoding utf8 -Force
    # Fall through to gate logic below
} else {
    # ── Git diff ─────────────────────────────────────────
    $diffText = ""
    try {
        $diffText = git diff --no-ext-diff --unified=80 2>"$AuditDir\git_diff.err"
        $diffExit = $LASTEXITCODE
    } catch {
        $diffExit = 1
        $diffText = ""
    }

    if ($diffExit -ne 0) {
        $gitErr = if (Test-Path "$AuditDir\git_diff.err") { Get-Content "$AuditDir\git_diff.err" -Raw } else { "" }
        if ($gitErr -match "not a git repository|fatal:.*not a git") {
            Write-Host "[claude_audit] NOT A GIT REPOSITORY — audit requires git repo"
            exit 24
        }
        Write-Host "[claude_audit] git diff failed: $gitErr"
        exit 24
    }

    $diffText | Out-File -LiteralPath $DiffFile -Encoding utf8 -Force

    $diffSize = (Get-Item -LiteralPath $DiffFile).Length
    if ($diffSize -eq 0) {
        Write-Host "[claude_audit] NO CHANGES to audit (empty diff)"
        exit 11
    }

    Write-Host "[claude_audit] diff generated ($diffSize bytes)"

    # ── SkipClaude mode ──────────────────────────────────
    if ($SkipClaude) {
        Write-Host "[claude_audit] --SkipClaude: diff check PASS, skipping Claude audit"
        Write-Host "[claude_audit] To test gate logic, use -UseFixture <path>"
        exit 0
    }

    # ══════════════════════════════════════════════════════
    # ── Claude audit (normal mode only) ──────────────────

    $auditPrompt = @'
You are an independent code auditor.

Read .audit/input.diff.
Do not modify files.
Do not run destructive commands.
Audit only the actual diff and relevant repository context.

Return strict JSON:
{
  "status": "PASS or FAIL",
  "severity": "NONE, LOW, MEDIUM, HIGH, or CRITICAL",
  "findings": [
    {
      "title": "short issue title",
      "severity": "LOW, MEDIUM, HIGH, or CRITICAL",
      "file": "path if known",
      "evidence": "concrete evidence",
      "fix": "specific required fix"
    }
  ],
  "required_fixes": [
    "specific fix"
  ],
  "summary": "short audit summary"
}
'@

    Write-Host "[claude_audit] invoking Claude Code (max-turns=3, no-session-persistence)..."

    # Build base arguments
    $claudeArgs = @("-p", $auditPrompt, "--output-format", "json", "--max-turns", "3", "--no-session-persistence")

    # Try --json-schema if supported (Claude Code >= v2.1+)
    $jsonSchemaSupported = $false
    try {
        $schemaTest = & claude --help 2>&1 | Out-String
        if ($schemaTest -match "--json-schema") {
            $jsonSchemaSupported = $true
        }
    } catch { }

    $auditRaw = $null
    $auditExitCode = 0

    if ($jsonSchemaSupported) {
        Write-Host "[claude_audit] --json-schema supported, using structured output"
        # Write schema to temp file (--json-schema needs a file path, not inline JSON on Windows CLI)
        $schemaFile = "$AuditDir\audit_schema.tmp.json"
        @'
{"type":"object","properties":{"status":{"type":"string","enum":["PASS","FAIL"]},"severity":{"type":"string","enum":["NONE","LOW","MEDIUM","HIGH","CRITICAL"]},"findings":{"type":"array","items":{"type":"object","properties":{"title":{"type":"string"},"severity":{"type":"string"},"file":{"type":"string"},"evidence":{"type":"string"},"fix":{"type":"string"}},"required":["title","severity","evidence","fix"]}},"required_fixes":{"type":"array","items":{"type":"string"}},"summary":{"type":"string"}},"required":["status","severity","findings","summary"]}
'@ | Out-File -LiteralPath $schemaFile -Encoding utf8 -Force
        try {
            $auditRaw = & claude -p $auditPrompt --output-format json --max-turns 3 --no-session-persistence --json-schema $schemaFile 2>&1
            $auditExitCode = $LASTEXITCODE
        } catch {
            $auditRaw = $_.Exception.Message
            $auditExitCode = 1
        }

        # If --json-schema failed, fallback to prompt-only
        if ($auditExitCode -ne 0) {
            $fallbackMsg = [string]$auditRaw
            Write-Host "[claude_audit] --json-schema failed, falling back to prompt-only JSON. Reason: $($fallbackMsg.Substring(0, [Math]::Min(200, $fallbackMsg.Length)))"
            try {
                $auditRaw = & claude @claudeArgs 2>&1
                $auditExitCode = $LASTEXITCODE
            } catch {
                $auditRaw = $_.Exception.Message
                $auditExitCode = 1
            }
        }
    } else {
        Write-Host "[claude_audit] --json-schema not supported in this Claude version, using prompt-only JSON"
        try {
            $auditRaw = & claude @claudeArgs 2>&1
            $auditExitCode = $LASTEXITCODE
        } catch {
            $auditRaw = $_.Exception.Message
            $auditExitCode = 1
        }
    }

    $auditText = [string]$auditRaw
    $auditText | Out-File -LiteralPath $OutputFile -Encoding utf8 -Force
}

# ══════════════════════════════════════════════════════════
# GATE LOGIC (applies to fixture and real audit)
# ══════════════════════════════════════════════════════════

# ── Rate-limit check ─────────────────────────────────────
if (Test-RateLimited -Text $auditText) {
    Write-Host "[claude_audit] RATE LIMIT in audit response"
    Write-RateLimitRecord -RawOutput $auditText -Source "audit"
    exit 23
}

# ── Auth / network failure (only when we actually called Claude) ─
if ($UseFixture -eq "" -and $auditExitCode -ne 0) {
    if ($auditText -match "auth|unauthorized|403\b|network error|connection timeout") {
        Write-Host "[claude_audit] Claude call failed (exit=$auditExitCode): $($auditText.Substring(0, [Math]::Min(200, $auditText.Length)))"
        exit 21
    }
}

# ── Parse JSON ───────────────────────────────────────────
$auditObj = $null

# Helper: try to find the inner audit JSON in various Claude output formats
function Find-AuditJson {
    param([string]$Text)
    # Try direct parse first
    try { $obj = $Text | ConvertFrom-Json -ErrorAction Stop; if ($obj.status) { return $obj } } catch { }
    # Claude wraps audit in result field with markdown code block
    try {
        $outer = $Text | ConvertFrom-Json -ErrorAction Stop
        if ($outer.result) {
            # Strip markdown code fences from result field
            $inner = $outer.result -replace '^```(?:json)?\s*\n?', '' -replace '\n?```\s*$', ''
            try { $obj = $inner | ConvertFrom-Json -ErrorAction Stop; if ($obj.status) { return $obj } } catch { }
        }
    } catch { }
    # Regex fallback: find first JSON object with "status" field
    if ($Text -match '(\{[\s\S]*?"status"[\s\S]*?\})') {
        try { $obj = $matches[1] | ConvertFrom-Json -ErrorAction Stop; if ($obj.status) { return $obj } } catch { }
    }
    return $null
}

$auditObj = Find-AuditJson -Text $auditText

if (-not $auditObj -or -not $auditObj.status) {
    Write-Host "[claude_audit] JSON missing required 'status' field"
    exit 22
}

# ── Gate on severity ─────────────────────────────────────
# Derive severity: explicit top-level field first, else max from findings
$severity = "NONE"
if ($auditObj.severity) {
    $severity = $auditObj.severity.ToUpper()
} elseif ($auditObj.findings -and $auditObj.findings.Count -gt 0) {
    $sevMap = @{ CRITICAL=4; HIGH=3; MEDIUM=2; LOW=1; NONE=0 }
    $maxSev = 0
    $maxLabel = "NONE"
    foreach ($f in $auditObj.findings) {
        $fs = if ($f.severity) { $f.severity.ToUpper() } else { "NONE" }
        $sv = $sevMap[$fs]
        if ($sv -gt $maxSev) { $maxSev = $sv; $maxLabel = $fs }
    }
    $severity = $maxLabel
}

Write-Host "[claude_audit] status=$($auditObj.status) severity=$severity"
Write-Host "[claude_audit] findings: $($auditObj.findings.Count)"

if ($auditObj.findings.Count -gt 0) {
    foreach ($f in $auditObj.findings) {
        Write-Host "  - [$($f.severity)] $($f.title) ($($f.file))"
    }
}

switch ($severity) {
    "NONE"          { Write-Host "[claude_audit] PASS (NONE)"; exit 0 }
    "LOW"           { Write-Host "[claude_audit] PASS (LOW issues, non-blocking)"; exit 10 }
    "MEDIUM"        { Write-Host "[claude_audit] PASS (MEDIUM issues, non-blocking)"; exit 10 }
    "HIGH"          { Write-Host "[claude_audit] FAIL (HIGH severity — blocking)"; exit 20 }
    "CRITICAL"      { Write-Host "[claude_audit] FAIL (CRITICAL severity — blocking)"; exit 20 }
    default         { Write-Host "[claude_audit] unknown severity '$severity', treating as PASS"; exit 0 }
}
