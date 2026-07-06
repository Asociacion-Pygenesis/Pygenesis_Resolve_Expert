# Ejecuta generacion Gemini en lotes.
# Uso desde training/:
#   .\mejorarTrainning\run_gemini_batch.ps1 -Tier free
#   .\mejorarTrainning\run_gemini_batch.ps1 -Tier plus -OnlyMissing
#   $env:GEMINI_TIER = "plus"

param(
    [ValidateSet("base", "multiturn", "mejorar", "process", "all")]
    [string]$Phase = "base",
    [ValidateSet("free", "plus")]
    [string]$Tier = "free",
    [int]$BatchSize = 0,
    [int]$MaxBatches = 0,
    [int]$Offset = 0,
    [double]$PauseMinutes = -1,
    [double]$Rpm = 0,
    [double]$SleepSec = -1,
    [switch]$OnlyMissing,
    [switch]$SkipExistingMultiturn,
    [int]$MejorarMax = 20,
    [int]$MejorarOffset = 0,
    [switch]$SkipProcess
)

$ErrorActionPreference = "Stop"
$TrainingRoot = Split-Path $PSScriptRoot -Parent
Set-Location $TrainingRoot

if (-not $env:GEMINI_API_KEY) {
    Write-Error "Falta GEMINI_API_KEY. Ejemplo: `$env:GEMINI_API_KEY = 'tu_clave'"
}

$env:GEMINI_TIER = $Tier

if ($Tier -eq "plus") {
    if ($BatchSize -le 0) { $BatchSize = 10 }
    if ($Rpm -le 0) { $Rpm = 30 }
    if ($SleepSec -lt 0) { $SleepSec = 1 }
    if ($PauseMinutes -lt 0) { $PauseMinutes = 0.2 }
    Write-Host "Perfil Plus: mas RPM, lotes mas grandes. Comprueba limites en https://aistudio.google.com" -ForegroundColor Green
} else {
    if ($BatchSize -le 0) { $BatchSize = 4 }
    if ($Rpm -le 0) { $Rpm = 4 }
    if ($SleepSec -lt 0) { $SleepSec = 15 }
    if ($PauseMinutes -lt 0) { $PauseMinutes = 1.5 }
}

# Preferir venv: training/.venv, luego raíz del repo (../.venv)
$Python = "python"
$VenvTraining = Join-Path $TrainingRoot ".venv\Scripts\python.exe"
$RepoRoot = Split-Path $TrainingRoot -Parent
$VenvRepo = Join-Path $RepoRoot ".venv\Scripts\python.exe"
if (Test-Path $VenvTraining) {
    $Python = $VenvTraining
} elseif (Test-Path $VenvRepo) {
    $Python = $VenvRepo
}

Write-Host "Python: $Python" -ForegroundColor DarkGray
& $Python -c "import google.genai" 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Falta el paquete google-genai en este intérprete." -ForegroundColor Red
    Write-Host "Instálalo con:" -ForegroundColor Yellow
    Write-Host "  & '$Python' -m pip install google-genai" -ForegroundColor White
    Write-Host ""
    Write-Error "ModuleNotFoundError: ejecuta pip install arriba y vuelve a lanzar el script."
}

$GeminiDir = Join-Path $TrainingRoot "data\raw\gemini"
New-Item -ItemType Directory -Force -Path $GeminiDir | Out-Null

function Get-JsonCount([string]$Path) {
    if (-not (Test-Path $Path)) { return 0 }
    try {
        $data = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
        return @($data).Count
    } catch {
        return 0
    }
}

function Invoke-GeminiBaseBatch([int]$StartOffset, [int]$Size) {
    $useOffset = $StartOffset
    if ($OnlyMissing -and $useOffset -gt 0) {
        Write-Host "OnlyMissing activo: se ignora -Offset $useOffset (solo hay pendientes en el JSON)." -ForegroundColor Yellow
        $useOffset = 0
    }
    $pyArgs = @(
        "mejorarTrainning\generate_dataset_gemini.py",
        "--append",
        "--tier", $Tier,
        "--offset", $useOffset,
        "--limit", $Size,
        "--rpm", $Rpm,
        "--sleep", $SleepSec,
        "--variations-per-topic", "0"
    )
    if ($OnlyMissing) { $pyArgs += "--only-missing" }
    Write-Host "`n=== Lote base: offset=$StartOffset limit=$Size ===" -ForegroundColor Cyan
    & $Python @pyArgs
    if ($LASTEXITCODE -ne 0) { throw "generate_dataset_gemini fallo (exit $LASTEXITCODE)" }
}

function Invoke-Multiturn {
    Write-Host "`n=== Multi-turn (una pasada) ===" -ForegroundColor Cyan
    # Multi-turn: muchas llamadas seguidas; en free conviene ir mas lento que el lote base.
    $mtRpm = $Rpm
    $mtSleep = $SleepSec
    if ($Tier -eq "free") {
        if ($Rpm -le 0 -or $Rpm -ge 4) { $mtRpm = 3 }
        if ($SleepSec -lt 0 -or $SleepSec -lt 18) { $mtSleep = 20 }
        Write-Host "Multi-turn free: rpm=$mtRpm sleep=${mtSleep}s (mas conservador que base)" -ForegroundColor DarkGray
    }
    $mtArgs = @(
        "mejorarTrainning\generar_conversaciones.py",
        "--append", "--tier", $Tier,
        "--rpm", $mtRpm, "--sleep", $mtSleep,
        "--repetitions", "1"
    )
    # Por defecto no duplicar escenarios ya guardados (metadata.contexto).
    if (-not $PSBoundParameters.ContainsKey('SkipExistingMultiturn') -or $SkipExistingMultiturn) {
        $mtArgs += "--skip-existing"
    }
    & $Python @mtArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Multi-turn: algun escenario no termino (suele ser 429/cuota). Reintenta en 10-15 min o un escenario:" -ForegroundColor Yellow
        Write-Host '  python mejorarTrainning\generar_conversaciones.py --append --tier free --contexto "optimizando"' -ForegroundColor White
        throw "generar_conversaciones fallo (exit $LASTEXITCODE)"
    }
}

function Invoke-MejorarBatch([int]$StartOffset, [int]$Size) {
    Write-Host "`n=== Mejorar dataset: offset=$StartOffset max=$Size ===" -ForegroundColor Cyan
    & $Python "mejorarTrainning\mejorar_dataset_existente.py" --append --tier $Tier --offset $StartOffset --max-examples $Size --rpm $Rpm --sleep $SleepSec
    if ($LASTEXITCODE -ne 0) { throw "mejorar_dataset_existente fallo" }
}

function Invoke-ProcessDataset {
    Write-Host "`n=== Mezclar train/eval ===" -ForegroundColor Cyan
    & $Python "scripts\process_dataset.py"
    if ($LASTEXITCODE -ne 0) { throw "process_dataset fallo" }
}

# Preguntas base en TEMAS (sin variaciones)
$EstimatedBaseJobs = 63
$currentOffset = $Offset
$batchNum = 0

if ($Phase -eq "base" -or $Phase -eq "all") {
    while ($true) {
        if ($MaxBatches -gt 0 -and $batchNum -ge $MaxBatches) { break }
        if ($currentOffset -ge $EstimatedBaseJobs) {
            Write-Host "Offset $currentOffset >= ~$EstimatedBaseJobs preguntas base. Fin." -ForegroundColor Green
            break
        }
        Invoke-GeminiBaseBatch -StartOffset $currentOffset -Size $BatchSize
        $out = Join-Path $GeminiDir "resolve_gemini_base.json"
        $n = Get-JsonCount $out
        Write-Host "resolve_gemini_base.json: $n ejemplos" -ForegroundColor Green
        $currentOffset += $BatchSize
        $batchNum++
        if ($currentOffset -ge $EstimatedBaseJobs) { break }
        if ($MaxBatches -gt 0 -and $batchNum -ge $MaxBatches) { break }
        Write-Host "Pausa $PauseMinutes min..." -ForegroundColor Yellow
        Start-Sleep -Seconds ([int]($PauseMinutes * 60))
    }
}

if ($Phase -eq "multiturn" -or $Phase -eq "all") {
    if ($Phase -eq "all" -and $batchNum -gt 0) {
        Write-Host "Pausa antes de multi-turn..." -ForegroundColor Yellow
        Start-Sleep -Seconds ([int]($PauseMinutes * 60))
    }
    Invoke-Multiturn
    $n = Get-JsonCount (Join-Path $GeminiDir "multiturn.json")
    Write-Host "multiturn.json: $n conversaciones" -ForegroundColor Green
}

if ($Phase -eq "mejorar" -or $Phase -eq "all") {
    if ($Phase -eq "all") {
        Write-Host "Pausa antes de mejorar..." -ForegroundColor Yellow
        Start-Sleep -Seconds ([int]($PauseMinutes * 60))
    }
    $mejorarBatch = [Math]::Max(1, [Math]::Min($BatchSize, $MejorarMax))
    $mejorarDone = 0
    $mejorarOff = $MejorarOffset
    while ($mejorarDone -lt $MejorarMax) {
        $take = [Math]::Min($mejorarBatch, $MejorarMax - $mejorarDone)
        Invoke-MejorarBatch -StartOffset $mejorarOff -Size $take
        $mejorarOff += $take
        $mejorarDone += $take
        if ($mejorarDone -ge $MejorarMax) { break }
        Write-Host "Pausa $PauseMinutes min..." -ForegroundColor Yellow
        Start-Sleep -Seconds ([int]($PauseMinutes * 60))
    }
    $n = Get-JsonCount (Join-Path $GeminiDir "mejorado.json")
    Write-Host "mejorado.json: $n ejemplos" -ForegroundColor Green
}

if (-not $SkipProcess -and ($Phase -eq "process" -or $Phase -eq "all")) {
    Invoke-ProcessDataset
}

Write-Host "`nListo. Siguiente lote base: .\mejorarTrainning\run_gemini_batch.ps1 -Offset $currentOffset" -ForegroundColor Cyan
