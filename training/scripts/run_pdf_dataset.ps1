<#
.SYNOPSIS
    Pipeline Fase 1b — manuales PDF (fuentesTrainning/) → Q&A ShareGPT → train/eval.

.PARAMETER MaxChunks
    0 = todos los fragmentos (~1600+ pares; varias horas con Ollama local).
    Usa 5–20 para pruebas rápidas.

.PARAMETER SkipIngest
    Omite la extracción PDF→txt si ya está en data/processed/resolve-pdf-txt/.

.EXAMPLE
    Set-Location "...\training"
    .\scripts\run_pdf_dataset.ps1 -MaxChunks 10
    .\scripts\run_pdf_dataset.ps1
#>
param(
    [int] $MaxChunks = 0,
    [switch] $SkipIngest,
    [float] $Sleep = 0.5
)

$ErrorActionPreference = 'Stop'
$TrainingRoot = Split-Path -Parent $PSScriptRoot
Set-Location $TrainingRoot

$py = Join-Path $TrainingRoot '.venv\Scripts\python.exe'
if (-not (Test-Path $py)) {
    Write-Error "No existe .venv. Ejecuta primero: .\scripts\setup_env_windows.ps1"
}

if (-not (Test-Path (Join-Path $TrainingRoot 'config\ollama.json'))) {
    Copy-Item (Join-Path $TrainingRoot 'config\ollama.example.json') (Join-Path $TrainingRoot 'config\ollama.json')
    Write-Host "Creado config\ollama.json desde example — revisa el modelo."
}

if (-not $SkipIngest) {
    Write-Host "=== 1/3 PDF -> texto ===" -ForegroundColor Cyan
    & $py scripts\ingest_pdf_manual.py
}

$chunkArg = @()
if ($MaxChunks -gt 0) { $chunkArg = @('--max-chunks', $MaxChunks) }

Write-Host "=== 2/3 Fragmentos -> Q&A (Ollama) ===" -ForegroundColor Cyan
& $py scripts\generate_qa_from_manual.py --corpus resolve_pdf --sleep $Sleep @chunkArg

Write-Host "=== 3/3 Unificar train/eval ===" -ForegroundColor Cyan
& $py scripts\process_dataset.py

Write-Host ""
Write-Host "Listo. Revisa:" -ForegroundColor Green
Write-Host "  data\raw\synthetic\pdf_manual_qa_sharegpt.json"
Write-Host "  data\train\resolve_train.json"
Write-Host "  data\eval\resolve_eval.json"
