# test-fixtures.ps1
# Run fixture-based gate tests without calling Claude.

param(
    [string]$ScriptDir = "$PSScriptRoot\..\scripts",
    [string]$FixturesDir = "$PSScriptRoot\..\fixtures"
)

$ErrorActionPreference = "Continue"
$passed = 0
$failed = 0

Write-Host "claude-audit-gate -- Gate Fixture Tests"
Write-Host ""

$tests = @(
    @{ File = "pass.json";     ExitCode = 0;  Label = "PASS" }
    @{ File = "low.json";      ExitCode = 10; Label = "LOW" }
    @{ File = "medium.json";   ExitCode = 10; Label = "MEDIUM" }
    @{ File = "high.json";     ExitCode = 20; Label = "HIGH" }
    @{ File = "critical.json"; ExitCode = 20; Label = "CRITICAL" }
    @{ File = "invalid.txt";   ExitCode = 22; Label = "INVALID" }
)

foreach ($t in $tests) {
    $fixturePath = Join-Path $FixturesDir $t.File
    $auditScript = Join-Path $ScriptDir "claude_audit.ps1"

    if (-not (Test-Path $fixturePath)) {
        Write-Host "FAIL $($t.Label): fixture not found at $fixturePath"
        $failed++
        continue
    }

    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $auditScript -UseFixture $fixturePath -SkipPreflight 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq $t.ExitCode) {
        Write-Host "PASS $($t.Label) -- exit $exitCode (expected $($t.ExitCode))"
        $passed++
    } else {
        Write-Host "FAIL $($t.Label) -- exit $exitCode (expected $($t.ExitCode))"
        $failed++
    }
}

Write-Host ""
Write-Host "Results: Passed=$passed Failed=$failed"
exit $(if ($failed -gt 0) { 1 } else { 0 })
