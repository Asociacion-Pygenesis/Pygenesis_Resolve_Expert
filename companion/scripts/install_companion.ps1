#Requires -Version 5.1
<#
.SYNOPSIS
  Instala Pygenesis Companion (artefacto portable o modo desarrollo).

.DESCRIPTION
  Preferencia:
  1. Si existe companion/dist (build electron-builder), copia a %LOCALAPPDATA%\Pygenesis\companion\
  2. Si no, modo desarrollo: sync assets + npm install

.PARAMETER Force
  Reinstala dependencias npm / sobrescribe destino portable.

.PARAMETER SkipNpm
  Solo copia archivos en modo dev; no ejecuta npm install.

.PARAMETER Dev
  Fuerza modo desarrollo (npm) aunque exista un build en companion/dist.
#>
param(
    [switch]$Force,
    [switch]$SkipNpm,
    [switch]$Dev
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$CompanionRoot = Join-Path $RepoRoot "companion\pygenesis-companion"
$DistRoot = Join-Path $RepoRoot "companion\dist"
$PluginRoot = Join-Path $RepoRoot "plugin\com.pygenesis.davinci.tutor"
$InstallDir = Join-Path $env:LOCALAPPDATA "Pygenesis\companion"

function Sync-SharedAssets {
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
        $parent = Split-Path $dstPath -Parent
        if (-not (Test-Path $parent)) {
            New-Item -ItemType Directory -Force -Path $parent | Out-Null
        }
        Copy-Item $srcPath $dstPath -Force
        Write-Host "  Copiado: $($item.Dst)" -ForegroundColor DarkGray
    }
}

function Find-PortableArtifact {
    if (-not (Test-Path $DistRoot)) { return $null }

    # Prefer unpacked win-unpacked (dir target) — more reliable than single-file portable for shortcuts
    $unpacked = Join-Path $DistRoot "win-unpacked"
    $unpackedExe = Join-Path $unpacked "Pygenesis Companion.exe"
    if (Test-Path $unpackedExe) {
        return @{ Kind = "dir"; Path = $unpacked; Exe = $unpackedExe }
    }

    $portableExe = Get-ChildItem $DistRoot -Filter "Pygenesis-Companion-*-portable.exe" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($portableExe) {
        return @{ Kind = "portable"; Path = $portableExe.FullName; Exe = $portableExe.FullName }
    }

    return $null
}

function Install-FromDist {
    param($Artifact)
    Write-Host "Instalando Companion desde build de release..." -ForegroundColor Cyan
    if (Test-Path $InstallDir) {
        if ($Force) {
            Remove-Item $InstallDir -Recurse -Force
        } else {
            Write-Host "Companion ya instalado en: $InstallDir (usa -Force para sobrescribir)" -ForegroundColor Yellow
            return (Get-ChildItem $InstallDir -Recurse -Filter "*.exe" | Select-Object -First 1).FullName
        }
    }
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

    if ($Artifact.Kind -eq "dir") {
        Copy-Item -Path (Join-Path $Artifact.Path "*") -Destination $InstallDir -Recurse -Force
        $exe = Join-Path $InstallDir "Pygenesis Companion.exe"
    } else {
        $destExe = Join-Path $InstallDir "Pygenesis Companion.exe"
        Copy-Item -Path $Artifact.Path -Destination $destExe -Force
        $exe = $destExe
    }

    if (-not (Test-Path $exe)) {
        throw "No se encontró el ejecutable de Companion tras la copia."
    }
    Write-Host "Companion instalado: $exe" -ForegroundColor Green
    return $exe
}

function Install-DevMode {
    if (-not (Test-Path $CompanionRoot)) {
        throw "No existe $CompanionRoot"
    }

    Write-Host "=== Pygenesis Companion - modo desarrollo ===" -ForegroundColor Cyan
    Sync-SharedAssets

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

    # Also expose a start helper under LocalAppData for consistency
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    $devLauncher = Join-Path $InstallDir "Start-Companion-Dev.ps1"
    $startScript = Join-Path $RepoRoot "companion\scripts\start_companion.ps1"
    @"
#Requires -Version 5.1
& '$startScript' @args
"@ | Set-Content -Path $devLauncher -Encoding UTF8

    Write-Host "Companion listo (dev) en: $CompanionRoot" -ForegroundColor Green
    Write-Host "Arranque: $startScript" -ForegroundColor Green
    return $null
}

Write-Host "=== Pygenesis Companion - instalacion ===" -ForegroundColor Cyan

$artifact = $null
if (-not $Dev) {
    $artifact = Find-PortableArtifact
}

if ($artifact) {
    Install-FromDist -Artifact $artifact | Out-Null
} else {
    if (-not $Dev) {
        Write-Host "No hay build en companion\dist; usando modo desarrollo (npm)." -ForegroundColor Yellow
        Write-Host "Para release: npm run build en companion\pygenesis-companion" -ForegroundColor DarkGray
    }
    Install-DevMode | Out-Null
}
