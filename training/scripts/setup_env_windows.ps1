<#
.SYNOPSIS
    Crea el venv en training/.venv e instala PyTorch + dependencias para Pygenesis AI (Windows).

.PARAMETER TorchFlavor
    Cpu = PyTorch CPU (por defecto; válido en cualquier PC).
    Cuda124 = PyTorch con CUDA 12.4 (requiere NVIDIA + driver reciente).

.EXAMPLE
    Set-Location "...\Pygenesis AI\training"
    .\scripts\setup_env_windows.ps1
    .\scripts\setup_env_windows.ps1 -TorchFlavor Cuda124
#>
param(
    [ValidateSet('Cpu', 'Cuda124')]
    [string] $TorchFlavor = 'Cpu'
)

$ErrorActionPreference = 'Stop'
$TrainingRoot = Split-Path -Parent $PSScriptRoot
Set-Location $TrainingRoot

$VenvPython = Join-Path $TrainingRoot '.venv\Scripts\python.exe'
if (-not (Test-Path $VenvPython)) {
    Write-Host "Creando venv en $TrainingRoot\.venv ..."
    python -m venv .venv
    if (-not (Test-Path $VenvPython)) {
        py -3.12 -m venv .venv
    }
    if (-not (Test-Path $VenvPython)) {
        py -3.11 -m venv .venv
    }
}

$py = Join-Path $TrainingRoot '.venv\Scripts\python.exe'
& $py -m pip install --upgrade pip setuptools wheel
$pip = Join-Path $TrainingRoot '.venv\Scripts\pip.exe'

Write-Host "Instalando PyTorch ($TorchFlavor)..."
if ($TorchFlavor -eq 'Cuda124') {
    & $pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
    & $pip install bitsandbytes
}
else {
    & $pip install torch torchvision torchaudio
}

$req = Join-Path $TrainingRoot 'requirements-train-windows.txt'
Write-Host "Instalando dependencias desde requirements-train-windows.txt..."
& $pip install -r $req

Write-Host ""
Write-Host "Listo. Activa el entorno en PowerShell:"
Write-Host "  Set-Location `"$TrainingRoot`""
Write-Host "  .\.venv\Scripts\Activate.ps1"
Write-Host "  python scripts\verify_env_windows.py"
