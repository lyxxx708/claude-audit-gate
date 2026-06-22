# scripts/uninstall_from_workspace.ps1
# Remove claude-audit-gate files from a target workspace.

param(
    [string]$Workspace = (Get-Location).Path,
    [switch]$Force
)

$ErrorActionPreference = "Continue"

$Workspace = Resolve-Path $Workspace 2>$null
if (-not $Workspace) {
    Write-Host "Workspace not found: $Workspace"
    exit 1
}

$files = @(
    "scripts\run_claude_audit.ps1",
    ".opencode\tools\claude_audit.ts",
    ".opencode\commands\claude-audit.md",
    ".opencode\CLAUDE_AUDIT.md"
)

Write-Host "Removing claude-audit-gate files from: $Workspace"
foreach ($f in $files) {
    $path = "$Workspace\$f"
    if (Test-Path $path) {
        Remove-Item $path -Force
        Write-Host "  🗑️  Removed: $f"
    } else {
        Write-Host "  ⚠️  Not found: $f"
    }
}

Write-Host "Done. .gitignore .audit/ entry left intact."
