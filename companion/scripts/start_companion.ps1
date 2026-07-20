#Requires -Version 5.1
<#
.SYNOPSIS
  Arranca Pygenesis Companion (portable instalado o Electron en modo dev).
#>
param()

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$InstallDir = Join-Path $env:LOCALAPPDATA "Pygenesis\companion"
$CompanionRoot = Join-Path $RepoRoot "companion\pygenesis-companion"
$InstallScript = Join-Path $RepoRoot "companion\scripts\install_companion.ps1"

$installedExe = Get-ChildItem $InstallDir -Recurse -Filter "Pygenesis Companion.exe" -ErrorAction SilentlyContinue |
    Select-Object -First 1

if ($installedExe) {
    Write-Host "Abriendo Pygenesis Companion..." -ForegroundColor Cyan
    Write-Host "Asegúrate de que el puente esté activo (menú Inicio → Pygenesis Backend)." -ForegroundColor DarkGray
    Start-Process -FilePath $installedExe.FullName
    exit 0
}

if (-not (Test-Path (Join-Path $CompanionRoot "node_modules\electron"))) {
    Write-Host "Primera ejecución: instalando Companion..." -ForegroundColor Yellow
    & $InstallScript -Dev
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

Push-Location $CompanionRoot
try {
    Write-Host "Abriendo Pygenesis Companion (dev)..." -ForegroundColor Cyan
    Write-Host "Asegúrate de que el puente esté activo: backend\start_backend.ps1" -ForegroundColor DarkGray
    npm start
} finally {
    Pop-Location
}
