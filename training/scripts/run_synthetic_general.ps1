<#
.SYNOPSIS
    Fase 1a: genera sintético general (todos los conceptos) y ejecuta process_dataset.

.PARAMETER Passes
    Pasadas barajadas sobre la lista de conceptos (default 1).

.PARAMETER Sleep
    Segundos de pausa entre llamadas a Ollama (default 0.5).

.PARAMETER Append
    Si se indica, añade a synthetic_qa.json existente.

.EXAMPLE
    cd training
    .\scripts\run_synthetic_general.ps1 -Passes 3
#>
param(
    [int] $Passes = 1,
    [double] $Sleep = 0.5,
    [switch] $Append
)

$ErrorActionPreference = "Stop"
$TrainingRoot = Split-Path -Parent $PSScriptRoot
Set-Location $TrainingRoot

$venvPy = Join-Path $TrainingRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPy)) {
    Write-Error "No existe .venv. Ejecuta primero scripts\setup_env_windows.ps1"
}

# Construir argumentos en un solo array (evita que PowerShell pase un "+" literal a Python).
$genArgs = @(
    (Join-Path $TrainingRoot "scripts\generate_synthetic.py"),
    "--max-concepts", "0",
    "--passes", "$Passes",
    "--sleep", "$Sleep"
)
if ($Append) {
    $genArgs += "--append"
}

Write-Host "=== Fase 1a: sintético general (modelo en config/ollama.json) ===" -ForegroundColor Cyan
& $venvPy @genArgs

Write-Host "=== process_dataset ===" -ForegroundColor Cyan
& $venvPy (Join-Path $TrainingRoot "scripts\process_dataset.py")

Write-Host "Listo. Revisa data\train\resolve_train.json y data\eval\resolve_eval.json" -ForegroundColor Green
