<#
.SYNOPSIS
    Convierte qwen-resolve-merged (HF) → GGUF f16 → cuantizado Q4_K_M para Ollama.

.DESCRIPTION
    Requiere:
      - Carpeta merged tras conversion/fusionar.py (por defecto: qwen-resolve-merged/)
      - llama.cpp con convert_hf_to_gguf.py (se clona en la raíz del repo si falta)
      - C:\llama-bin\llama-quantize.exe (binarios Vulkan de llama.cpp)

    Salida alineada con Modelfile: pygenesis-resolve-q4km.gguf

.PARAMETER MergedDir
    Carpeta del modelo HuggingFace fusionado.

.PARAMETER SkipF16
    Omite la conversión a f16 si el archivo ya existe.

.PARAMETER RemoveF16After
    Borra el GGUF f16 tras cuantizar (ahorra ~14 GB).

.PARAMETER OllamaCreate
    Ejecuta: ollama create pygenesis-resolve -f Modelfile

.EXAMPLE
    Set-Location "C:\Users\navar\PycharmProjects\Pygenesis_ResolveExpert"
    .\conversion\convertir_gguf.ps1

.EXAMPLE
    .\conversion\convertir_gguf.ps1 -RemoveF16After -OllamaCreate
#>
param(
    [string] $MergedDir = "qwen-resolve-merged",
    [string] $OutF16 = "pygenesis-resolve-f16.gguf",
    [string] $OutQ4 = "pygenesis-resolve-q4km.gguf",
    [string] $QuantType = "Q4_K_M",
    [string] $LlamaBin = "C:\llama-bin\llama-quantize.exe",
    [switch] $SkipF16,
    [switch] $RemoveF16After,
    [switch] $OllamaCreate
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Find-Python {
    $candidates = @(
        (Join-Path $RepoRoot 'training\.venv\Scripts\python.exe'),
        (Get-Command python -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
    ) | Where-Object { $_ -and (Test-Path $_) }
    if (-not $candidates) {
        throw "No se encontró Python. Instala Python 3.11+ o crea training\.venv"
    }
    return $candidates[0]
}

$mergedPath = Join-Path $RepoRoot $MergedDir
$f16Path = Join-Path $RepoRoot $OutF16
$q4Path = Join-Path $RepoRoot $OutQ4
$llamaCpp = Join-Path $RepoRoot 'llama.cpp'
$convertScript = Join-Path $llamaCpp 'convert_hf_to_gguf.py'
$logDir = Join-Path $RepoRoot 'conversion'
$logF16 = Join-Path $logDir 'gguf_f16.log'

if (-not (Test-Path (Join-Path $mergedPath 'config.json'))) {
    throw "No existe modelo merged en '$mergedPath'. Ejecuta antes: python conversion\fusionar.py"
}

if (-not (Test-Path $LlamaBin)) {
    throw "No se encontró llama-quantize.exe en '$LlamaBin'. Descarga binarios Vulkan desde: https://github.com/ggml-org/llama.cpp/releases"
}

if (-not (Test-Path $convertScript)) {
    Write-Host "Clonando llama.cpp (solo la primera vez)..." -ForegroundColor Cyan
    git clone --depth 1 https://github.com/ggml-org/llama.cpp.git $llamaCpp
}

$py = Find-Python
Write-Host "Python: $py" -ForegroundColor DarkGray

Write-Host "Instalando dependencias de conversión (gguf, sentencepiece)..." -ForegroundColor Cyan
& $py -m pip install -q gguf sentencepiece protobuf numpy transformers

if (-not $SkipF16 -or -not (Test-Path $f16Path)) {
    Write-Host "=== 1/2 HF merged -> GGUF f16 ===" -ForegroundColor Cyan
    Write-Host "Entrada:  $mergedPath"
    Write-Host "Salida:   $f16Path (~14 GB, varios minutos)"
    & $py $convertScript $mergedPath --outfile $f16Path --outtype f16 2>&1 | Tee-Object -FilePath $logF16
} else {
    Write-Host "=== 1/2 Omitido (ya existe $OutF16) ===" -ForegroundColor Yellow
}

if (-not (Test-Path $f16Path)) {
    throw "No se generó $OutF16"
}

$f16Gb = [math]::Round((Get-Item $f16Path).Length / 1GB, 2)
Write-Host "f16 listo: $OutF16 ($f16Gb GB)" -ForegroundColor Green

Write-Host "=== 2/2 f16 -> $QuantType ===" -ForegroundColor Cyan
Write-Host "Salida: $OutQ4 (~4,5 GB)"
& $LlamaBin $f16Path $q4Path $QuantType

if (-not (Test-Path $q4Path)) {
    throw "No se generó $OutQ4"
}

$q4Gb = [math]::Round((Get-Item $q4Path).Length / 1GB, 2)
Write-Host "q4 listo: $OutQ4 ($q4Gb GB)" -ForegroundColor Green

if ($RemoveF16After) {
    Remove-Item $f16Path -Force
    Write-Host "Eliminado $OutF16 (liberados ~$f16Gb GB)" -ForegroundColor Yellow
}

if ($OllamaCreate) {
    $modelfile = Join-Path $RepoRoot 'Modelfile'
    if (-not (Test-Path $modelfile)) {
        throw "No se encontró Modelfile en la raíz del repo"
    }
    Write-Host "=== Registrando en Ollama ===" -ForegroundColor Cyan
    ollama create pygenesis-resolve -f $modelfile
    Write-Host "Probar: ollama run pygenesis-resolve `"¿Cómo activo proxies en DaVinci Resolve?`"" -ForegroundColor Green
}

Write-Host ""
Write-Host "Listo." -ForegroundColor Green
Write-Host "  GGUF final: $q4Path"
Write-Host "  Modelfile:  FROM ./$OutQ4"
