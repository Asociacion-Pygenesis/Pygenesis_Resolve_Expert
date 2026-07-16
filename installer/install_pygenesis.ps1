#Requires -Version 5.1
<#
.SYNOPSIS
  Instalador unificado: GPU + inferencia + modelo HF + plugin Resolve.

.DESCRIPTION
  1. Detecta GPU (NVIDIA → CUDA, AMD → Vulkan, si no CPU)
  2. Instala llama-cpp-python y deps del puente
  3. Descarga GGUF desde Hugging Face (si no existe localmente)
  4. Instala el plugin en Resolve

.PARAMETER Backend
  Forzar backend: auto | cuda | vulkan | cpu

.PARAMETER SkipModelDownload
  No descarga el modelo (útil si ya está en %LOCALAPPDATA%\Pygenesis\models\)

.PARAMETER SkipPlugin
  Solo instala puente + modelo

.EXAMPLE
  .\install_pygenesis.ps1
  .\install_pygenesis.ps1 -Backend vulkan
#>
param(
    [ValidateSet("auto", "cuda", "vulkan", "cpu")]
    [string]$Backend = "auto",
    [switch]$SkipModelDownload,
    [switch]$SkipPlugin
)

$ErrorActionPreference = "Stop"
$InstallerRoot = $PSScriptRoot
$RepoRoot = Split-Path $InstallerRoot -Parent
$BackendScripts = Join-Path $RepoRoot "backend\scripts"
$PluginScripts = Join-Path $RepoRoot "plugin\scripts"
$VenvPython = Join-Path $RepoRoot "training\.venv\Scripts\python.exe"
$ModelSourcePath = Join-Path $InstallerRoot "model.source.json"

function Import-BridgeEnv {
    $envFile = Join-Path $env:LOCALAPPDATA "Pygenesis\bridge.env"
    if (-not (Test-Path $envFile)) { return }
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Item -Path "Env:$name" -Value $value
        }
    }
}

function Get-ModelSource {
    if (-not (Test-Path $ModelSourcePath)) {
        throw "Falta $ModelSourcePath"
    }
    return Get-Content $ModelSourcePath -Raw | ConvertFrom-Json
}

function Ensure-ModelDownloaded {
    $source = Get-ModelSource
    $modelDir = Join-Path $env:LOCALAPPDATA "Pygenesis\models"
    New-Item -ItemType Directory -Force -Path $modelDir | Out-Null
    $dest = Join-Path $modelDir $source.filename

    if (Test-Path $dest) {
        Write-Host "Modelo ya presente: $dest" -ForegroundColor Green
        return $dest
    }

    Write-Host "Descargando modelo desde Hugging Face ($($source.repo_id))..." -ForegroundColor Cyan
    $py = @"
import json
from pathlib import Path
from huggingface_hub import hf_hub_download

source = json.loads(Path(r'$ModelSourcePath').read_text(encoding='utf-8'))
dest_dir = Path(r'$modelDir')
dest_dir.mkdir(parents=True, exist_ok=True)
path = hf_hub_download(
    repo_id=source['repo_id'],
    filename=source['filename'],
    revision=source.get('revision') or 'main',
    local_dir=str(dest_dir),
    local_dir_use_symlinks=False,
)
print(path)
"@
    $downloaded = & $VenvPython -c $py
    if ($LASTEXITCODE -ne 0) {
        throw "Falló la descarga del modelo. Comprueba repo_id en installer/model.source.json"
    }
    Write-Host "Modelo descargado: $downloaded" -ForegroundColor Green
    return $dest
}

Write-Host "=== Pygenesis ResolveExpert — Instalador ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $VenvPython)) {
    Write-Host "Creando entorno Python..." -ForegroundColor Yellow
    Push-Location (Join-Path $RepoRoot "training")
    & .\scripts\setup_env_windows.ps1
    Pop-Location
    if (-not (Test-Path $VenvPython)) { throw "No se pudo crear training\.venv" }
}

Write-Host "[1/4] Detectando GPU e instalando motor de inferencia..." -ForegroundColor Cyan
& (Join-Path $BackendScripts "install_inference.ps1") -Backend $Backend
if ($LASTEXITCODE -ne 0) { exit 1 }

Import-BridgeEnv

if (-not $SkipModelDownload) {
    Write-Host ""
    Write-Host "[2/4] Modelo GGUF..." -ForegroundColor Cyan
    $modelPath = Ensure-ModelDownloaded
    $envFile = Join-Path $env:LOCALAPPDATA "Pygenesis\bridge.env"
    Add-Content -Path $envFile -Value "PYGENESIS_MODEL_PATH=$modelPath"
    Write-Host "PYGENESIS_MODEL_PATH=$modelPath" -ForegroundColor DarkGray
} else {
    Write-Host ""
    Write-Host "[2/4] Modelo omitido (-SkipModelDownload)" -ForegroundColor Yellow
}

if (-not $SkipPlugin) {
    Write-Host ""
    Write-Host "[3/4] Plugin Resolve..." -ForegroundColor Cyan
    & (Join-Path $PluginScripts "install_plugin.ps1") -Force
    if ($LASTEXITCODE -ne 0) { exit 1 }
} else {
    Write-Host ""
    Write-Host "[3/4] Plugin omitido (-SkipPlugin)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[4/4] Verificación..." -ForegroundColor Cyan
$detected = & (Join-Path $BackendScripts "detect_gpu.ps1")
Write-Host "  Backend GPU : $($detected.Backend) ($($detected.GpuName))" -ForegroundColor DarkGray
Write-Host "  Config      : $env:LOCALAPPDATA\Pygenesis\bridge.env" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Siguiente paso:" -ForegroundColor Green
Write-Host "  cd backend"
Write-Host "  .\start_backend.ps1"
Write-Host "  Abre Resolve → Workspace → Workflow Integrations → Pygenesis Resolve Tutor"
