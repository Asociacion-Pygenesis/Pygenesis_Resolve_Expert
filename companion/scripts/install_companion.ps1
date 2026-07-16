#Requires -Version 5.1
<#
.SYNOPSIS
  Sincroniza assets compartidos del plugin e instala Electron para Companion.

.PARAMETER Force
  Reinstala dependencias npm aunque node_modules exista.

.PARAMETER SkipNpm
  Solo copia archivos; no ejecuta npm install.
#>
param(
    [switch]$Force,
    [switch]$SkipNpm
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$CompanionRoot = Join-Path $RepoRoot "companion\pygenesis-companion"
$PluginRoot = Join-Path $RepoRoot "plugin\com.pygenesis.davinci.tutor"

if (-not (Test-Path $CompanionRoot)) {
    throw "No existe $CompanionRoot"
}

Write-Host "=== Pygenesis Companion - instalacion ===" -ForegroundColor Cyan

$shared = @(
    @{ Src = "js\chat-api.js"; Dst = "js\chat-api.js" },
    @{ Src = "js\chat-ui.js"; Dst = "js\chat-ui.js" },
    @{ Src = "js\vendor\marked.min.js"; Dst = "js\vendor\marked.min.js" }
)

foreach ($item in $shared) {
    $srcPath = Join-Path $PluginRoot $item.Src
    $dstPath = Join-Path $CompanionRoot $item.Dst
    if (-not (Test-Path $srcPath)) {
        throw "Falta archivo compartido: $srcPath"
    }
    Copy-Item $srcPath $dstPath -Force
    Write-Host "  Copiado: $($item.Dst)" -ForegroundColor DarkGray
}

if (-not $SkipNpm) {
    Push-Location $CompanionRoot
    if ($Force -and (Test-Path "node_modules")) {
        Remove-Item "node_modules" -Recurse -Force
    }
    if (-not (Test-Path "node_modules")) {
        Write-Host "Instalando Electron (npm install)..." -ForegroundColor Yellow
        npm install --no-fund --no-audit
        if ($LASTEXITCODE -ne 0) { throw "npm install fallo" }
    } else {
        Write-Host "node_modules ya presente (usa -Force para reinstalar)" -ForegroundColor DarkGray
    }
    Pop-Location
}

$startScript = Join-Path $RepoRoot "companion\scripts\start_companion.ps1"
Write-Host ""
Write-Host "Companion listo en: $CompanionRoot" -ForegroundColor Green
Write-Host "Arranque: $startScript" -ForegroundColor Green
