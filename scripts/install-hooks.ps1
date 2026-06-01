#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs the pre-push git hook by symlinking scripts/pre-push into .git/hooks/.

.DESCRIPTION
    Creates .git/hooks/pre-push as a symbolic link pointing to ../../scripts/pre-push
    (the cross-platform bash shim).  When git runs the hook, the shim detects
    Windows and delegates to scripts/pre-push.ps1.

    Symlink creation on Windows requires one of:
      • Windows Developer Mode  (Settings → System → Developer Mode)
      • Running this script as Administrator

    If neither is available the script falls back to copying the file and warns you.

.EXAMPLE
    pwsh scripts/install-hooks.ps1
#>

$ErrorActionPreference = "Stop"

$ROOT     = & git rev-parse --show-toplevel
$hooksDir = "$ROOT/.git/hooks"
$hookDst  = "$hooksDir/pre-push"
# Relative target so the symlink works even if the repo moves
$hookSrc  = "../../scripts/pre-push"

# Make the shim executable in git's eyes (chmod +x equivalent via git update-index)
$fullSrc = "$ROOT/scripts/pre-push"
& git update-index --chmod=+x "scripts/pre-push" 2>$null

# Remove any existing hook
if (Test-Path $hookDst) { Remove-Item $hookDst -Force }

$linked = $false
try {
    New-Item -ItemType SymbolicLink -Path $hookDst -Target $hookSrc -Force | Out-Null
    $linked = $true
} catch {
    # Symlink failed (no Developer Mode / not admin)
}

if ($linked) {
    Write-Host "Symlink created:" -ForegroundColor Green
    Write-Host "  $hookDst -> $hookSrc"
} else {
    # Fall back: copy the file so the hook still works
    Copy-Item $fullSrc $hookDst -Force
    Write-Host "WARNING: Could not create symlink (requires Developer Mode or admin)." -ForegroundColor Yellow
    Write-Host "         Copied hook file instead.  Re-run after enabling Developer Mode" -ForegroundColor Yellow
    Write-Host "         to get a proper symlink that stays in sync automatically." -ForegroundColor Yellow
    Write-Host "Copied:  $hookDst" -ForegroundColor Green
}

Write-Host "`nPre-push hook installed successfully." -ForegroundColor Cyan
Write-Host "It will run on every 'git push'. Set SKIP_SCREENSHOTS=1 to skip screenshot generation."
