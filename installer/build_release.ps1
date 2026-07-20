#Requires -Version 5.1
<#
.SYNOPSIS
  Ensambla el paquete de distribución para GitHub Releases.

.DESCRIPTION
  1. Sincroniza assets compartidos plugin → companion
  2. Construye Companion con electron-builder
  3. Copia backend, plugin, companion/dist, installer a dist/PygenesisResolveExpert/
  4. Genera ZIP (sin training/, conversion/, venvs, node_modules, GGUF)

.PARAMETER SkipCompanionBuild
  Reutiliza companion/dist existente

.PARAMETER SkipZip
  Solo ensambla la carpeta, no genera el ZIP

.EXAMPLE
  .\build_release.ps1
#>
param(
    [switch]$SkipCompanionBuild,
    [switch]$SkipZip,
    [string]$Version = "0.3.2"
)

$ErrorActionPreference = "Stop"
$InstallerRoot = $PSScriptRoot
$RepoRoot = Split-Path $InstallerRoot -Parent
$OutRoot = Join-Path $RepoRoot "dist\PygenesisResolveExpert"
$ZipPath = Join-Path $RepoRoot "dist\PygenesisResolveExpert-$Version-windows.zip"
$CompanionApp = Join-Path $RepoRoot "companion\pygenesis-companion"
$CompanionDist = Join-Path $RepoRoot "companion\dist"

function Copy-TreeFiltered {
    param(
        [string]$Source,
        [string]$Destination,
        [string[]]$ExcludeDirNames = @()
    )
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Get-ChildItem -Path $Source -Force | ForEach-Object {
        if ($_.PSIsContainer -and ($ExcludeDirNames -contains $_.Name)) {
            return
        }
        $dest = Join-Path $Destination $_.Name
        if ($_.PSIsContainer) {
            Copy-TreeFiltered -Source $_.FullName -Destination $dest -ExcludeDirNames $ExcludeDirNames
        } else {
            # Skip bulky / local artifacts
            if ($_.Extension -in @(".gguf", ".pt", ".bin", ".safetensors")) { return }
            if ($_.Name -match '^\.env') { return }
            Copy-Item $_.FullName $dest -Force
        }
    }
}

Write-Host "=== Build release Pygenesis ResolveExpert v$Version ===" -ForegroundColor Cyan

# Sync shared UI assets before build
Write-Host "[1/4] Sincronizando assets compartidos..." -ForegroundColor Cyan
& (Join-Path $RepoRoot "companion\scripts\install_companion.ps1") -Dev -SkipNpm
if ($LASTEXITCODE -ne 0) { exit 1 }

if (-not $SkipCompanionBuild) {
    Write-Host "[2/4] Construyendo Companion (electron-builder)..." -ForegroundColor Cyan
    Push-Location $CompanionApp
    try {
        if (-not (Test-Path "node_modules\electron-builder")) {
            Write-Host "  npm install (incluye electron-builder)..." -ForegroundColor Yellow
            npm install --no-fund --no-audit
            if ($LASTEXITCODE -ne 0) { throw "npm install fallo" }
        }
        npm run build
        if ($LASTEXITCODE -ne 0) { throw "electron-builder fallo" }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "[2/4] Companion build omitido (-SkipCompanionBuild)" -ForegroundColor Yellow
    if (-not (Test-Path $CompanionDist)) {
        throw "No existe companion\dist. Ejecuta sin -SkipCompanionBuild."
    }
}

Write-Host "[3/4] Ensamblando $OutRoot ..." -ForegroundColor Cyan
if (Test-Path $OutRoot) {
    Remove-Item $OutRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $OutRoot | Out-Null

Copy-TreeFiltered -Source (Join-Path $RepoRoot "backend") -Destination (Join-Path $OutRoot "backend") `
    -ExcludeDirNames @("__pycache__", ".pytest_cache", "vectorstore")
Copy-TreeFiltered -Source (Join-Path $RepoRoot "plugin") -Destination (Join-Path $OutRoot "plugin") `
    -ExcludeDirNames @("node_modules")
Copy-TreeFiltered -Source (Join-Path $RepoRoot "installer") -Destination (Join-Path $OutRoot "installer") `
    -ExcludeDirNames @()

# Companion: dist artifacts + scripts (no full node_modules source needed for end users)
$outCompanion = Join-Path $OutRoot "companion"
New-Item -ItemType Directory -Force -Path $outCompanion | Out-Null
Copy-TreeFiltered -Source $CompanionDist -Destination (Join-Path $outCompanion "dist") `
    -ExcludeDirNames @()
New-Item -ItemType Directory -Force -Path (Join-Path $outCompanion "scripts") | Out-Null
Copy-Item (Join-Path $RepoRoot "companion\scripts\install_companion.ps1") (Join-Path $outCompanion "scripts\") -Force
Copy-Item (Join-Path $RepoRoot "companion\scripts\start_companion.ps1") (Join-Path $outCompanion "scripts\") -Force
Copy-Item (Join-Path $RepoRoot "companion\README.md") (Join-Path $outCompanion "README.md") -Force -ErrorAction SilentlyContinue

# Root entry points (forwarder → installer\Install.bat)
Copy-Item (Join-Path $RepoRoot "Install.bat") (Join-Path $OutRoot "Install.bat") -Force
$readmeSrc = Join-Path $InstallerRoot "README.md"
if (Test-Path $readmeSrc) {
    Copy-Item $readmeSrc (Join-Path $OutRoot "README.md") -Force
}

# Marker so install scripts resolve paths correctly (repo-like layout)
@"
Pygenesis ResolveExpert — paquete de distribución Windows
Version: $Version
Modelo: SuNavar/Pygenesis_ResolveExpert (descarga en instalacion)
"@ | Set-Content (Join-Path $OutRoot "VERSION.txt") -Encoding UTF8

Write-Host "  Carpeta lista: $OutRoot" -ForegroundColor Green

if (-not $SkipZip) {
    Write-Host "[4/4] Generando ZIP..." -ForegroundColor Cyan
    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
    Compress-Archive -Path $OutRoot -DestinationPath $ZipPath -CompressionLevel Optimal
    $sizeMb = [math]::Round((Get-Item $ZipPath).Length / 1MB, 1)
    Write-Host "  ZIP: $ZipPath ($sizeMb MB)" -ForegroundColor Green
} else {
    Write-Host "[4/4] ZIP omitido (-SkipZip)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Sube el ZIP a GitHub Releases. El GGUF permanece en Hugging Face." -ForegroundColor Cyan
Write-Host "Usuario final: descomprimir → doble clic en Install.bat" -ForegroundColor Cyan
