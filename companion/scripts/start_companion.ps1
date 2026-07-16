#Requires -Version 5.1
<#
.SYNOPSIS
  Arranca Pygenesis Companion (ventana Electron).

.EXAMPLE
  .\start_companion.ps1
#>
param()

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$CompanionRoot = Join-Path $RepoRoot "companion\pygenesis-companion"
$InstallScript = Join-Path $RepoRoot "companion\scripts\install_companion.ps1"

if (-not (Test-Path (Join-Path $CompanionRoot "node_modules\electron"))) {
    Write-Host "Primera ejecución: instalando Companion..." -ForegroundColor Yellow
    & $InstallScript
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

Push-Location $CompanionRoot
try {
    Write-Host "Abriendo Pygenesis Companion..." -ForegroundColor Cyan
    Write-Host "Asegúrate de que el puente esté activo: backend\start_backend.ps1" -ForegroundColor DarkGray
    npm start
} finally {
    Pop-Location
}
