<#
.SYNOPSIS
    Descarga Q&A de Stack Exchange (Video Production + Stack Overflow) para el dataset Resolve.

.EXAMPLE
    Set-Location "...\training"
    Copy-Item config\stackexchange.example.json config\stackexchange.json
    .\scripts\run_stackoverflow_scrape.ps1 -DryRun
    .\scripts\run_stackoverflow_scrape.ps1
    .\scripts\run_stackoverflow_scrape.ps1 -ProcessDataset
#>
param(
    [switch] $DryRun,
    [int] $MaxPages = 0,
    [switch] $Append,
    [switch] $ProcessDataset
)

$ErrorActionPreference = 'Stop'
$TrainingRoot = Split-Path -Parent $PSScriptRoot
Set-Location $TrainingRoot

$py = Join-Path $TrainingRoot '.venv\Scripts\python.exe'
if (-not (Test-Path $py)) {
    Write-Error "No existe .venv. Ejecuta: .\scripts\setup_env_windows.ps1"
}

$cfg = Join-Path $TrainingRoot 'config\stackexchange.json'
if (-not (Test-Path $cfg)) {
    Copy-Item (Join-Path $TrainingRoot 'config\stackexchange.example.json') $cfg
    Write-Host "Creado config\stackexchange.json — opcional: añade api_key desde https://stackapps.com"
}

$args_py = @('scripts\scrape_stackoverflow.py')
if ($DryRun) { $args_py += '--dry-run' }
if ($MaxPages -gt 0) { $args_py += @('--max-pages', $MaxPages) }
if ($Append) { $args_py += '--append' }

& $py @args_py

if ($ProcessDataset -and -not $DryRun) {
    Write-Host ""
    Write-Host "=== Unificando train/eval (PDF + Stack Overflow) ===" -ForegroundColor Cyan
    & $py scripts\process_dataset.py
}
