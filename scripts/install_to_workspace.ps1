# scripts/install_to_workspace.ps1
# Install claude-audit-gate into a target workspace.

param(
    [string]$Workspace = (Get-Location).Path,
    [ValidateSet("copy", "link")]
    [string]$Mode = "link",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path "$PSScriptRoot\.."

$entries = @(
    @{ Src = "scripts\claude_audit.ps1";                DstRel = "scripts\claude_audit.ps1" }
    @{ Src = "scripts\run_claude_audit.ps1";            DstRel = "scripts\run_claude_audit.ps1" }
    @{ Src = "opencode\tools\claude_audit.ts";         DstRel = ".opencode\tools\claude_audit.ts" }
    @{ Src = "opencode\commands\claude-audit.md";       DstRel = ".opencode\commands\claude-audit.md" }
    @{ Src = "opencode\CLAUDE_AUDIT.md";                DstRel = ".opencode\CLAUDE_AUDIT.md" }
)

Write-Host "claude-audit-gate -- Install to Workspace"
Write-Host "Workspace: $Workspace"
Write-Host "Repo root: $RepoRoot"
Write-Host "Mode: $Mode"
Write-Host ""

foreach ($e in $entries) {
    $src = Join-Path $RepoRoot $e.Src
    $dst = Join-Path $Workspace $e.DstRel

    if (-not (Test-Path $src)) {
        Write-Host ("SKIP  source not found: " + $e.Src)
        continue
    }

    $dstDir = Split-Path $dst -Parent
    if (-not (Test-Path $dstDir)) {
        New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
    }

    if ((Test-Path $dst) -and -not $Force) {
        Write-Host ("SKIP  exists (use -Force): " + $e.DstRel)
        continue
    }

    if ($Mode -eq "link") {
        if (Test-Path $dst) { Remove-Item $dst -Force }
        try {
            New-Item -ItemType SymbolicLink -Path $dst -Target $src -Force -ErrorAction Stop | Out-Null
            Write-Host ("LINK  " + $e.DstRel)
        } catch {
            # Fallback to copy if symlink requires elevation
            Write-Host ("FALLBACK copy (symlink requires admin): " + $e.DstRel)
            Copy-Item $src $dst -Force
        }
    } else {
        Copy-Item $src $dst -Force
        Write-Host ("COPY  " + $e.DstRel)
    }
}

# .gitignore
$gitignoreFile = Join-Path $Workspace ".gitignore"
$auditEntry = ".audit/"
if (-not (Test-Path $gitignoreFile)) {
    $auditEntry | Out-File -LiteralPath $gitignoreFile -Encoding utf8
    Write-Host "ADD   .gitignore with .audit/ entry"
} else {
    $content = Get-Content $gitignoreFile -Raw
    if ($content -match [regex]::Escape($auditEntry)) {
        Write-Host "OK    .audit/ already in .gitignore"
    } else {
        Add-Content -LiteralPath $gitignoreFile -Value "`n# claude-audit-gate`n.audit/" -Encoding utf8
        Write-Host "ADD   .audit/ entry to .gitignore"
    }
}

Write-Host ""
Write-Host "Install complete."
Write-Host "Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_claude_audit.ps1"
