#Requires -Version 5.1
<#
.SYNOPSIS
  Instala llama-cpp-python con el backend adecuado (CUDA, Vulkan o CPU).

.PARAMETER Backend
  cuda | vulkan | cpu | auto (detecta con detect_gpu.ps1)

.PARAMETER AllowCpuFallback
  Si Vulkan/CUDA falla, instala wheel CPU precompilado (más lento pero sin compilar).

.EXAMPLE
  .\install_inference.ps1
  .\install_inference.ps1 -Backend cuda
  .\install_inference.ps1 -Backend vulkan
  .\install_inference.ps1 -AllowCpuFallback
#>
param(
    [ValidateSet("auto", "cuda", "vulkan", "cpu")]
    [string]$Backend = "auto",
    [switch]$AllowCpuFallback,
    [string]$PythonExe = ""
)

function Invoke-Pip {
    param([string[]]$PipArgs)

    $argList = @("-m", "pip") + $PipArgs
    Write-Host ("  > " + ($PipArgs -join " ")) -ForegroundColor DarkGray

    $outLog = Join-Path $env:TEMP "pygenesis-pip-out.log"
    $errLog = Join-Path $env:TEMP "pygenesis-pip-err.log"
    Remove-Item $outLog, $errLog -Force -ErrorAction SilentlyContinue

    $p = Start-Process -FilePath $VenvPython -ArgumentList $argList `
        -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $outLog `
        -RedirectStandardError $errLog

    foreach ($f in @($outLog, $errLog)) {
        if (Test-Path $f) {
            Get-Content -Path $f -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
        }
    }

    if ($null -eq $p -or $null -eq $p.ExitCode) { return 1 }
    return [int]$p.ExitCode
}

function Test-LlamaCppImport {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $VenvPython -c "import llama_cpp; print('llama_cpp OK', getattr(llama_cpp, '__version__', '?'))"
    $ok = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = $prevEap
    return $ok
}

function Install-LlamaCpp {
    param([string]$TargetBackend)

    # PyPI publica sdist (compilar en Windows = MAX_PATH). Wheels oficiales en GitHub/abetlen.
    # NO usar --only-binary=:all: (rompe deps como typing-extensions en algunos pip).
    $ver = "0.3.34"
    $wheelCpu = "https://github.com/abetlen/llama-cpp-python/releases/download/v$ver/llama_cpp_python-$ver-py3-none-win_amd64.whl"
    $wheelVulkan = "https://github.com/abetlen/llama-cpp-python/releases/download/v$ver-vulkan/llama_cpp_python-$ver-py3-none-win_amd64.whl"
    $idxCpu = "https://abetlen.github.io/llama-cpp-python/whl/cpu"
    $idxVulkan = "https://abetlen.github.io/llama-cpp-python/whl/vulkan"
    $idxCuda = "https://abetlen.github.io/llama-cpp-python/whl/cu124"

    switch ($TargetBackend) {
        "cuda" {
            Write-Host "Instalando llama-cpp-python (wheel CUDA cu124)..." -ForegroundColor Cyan
            $code = Invoke-Pip @(
                "install", "llama-cpp-python", "--upgrade", "--force-reinstall", "--no-cache-dir",
                "--extra-index-url", $idxCuda,
                "--only-binary=llama-cpp-python",
                "--trusted-host", "abetlen.github.io",
                "--trusted-host", "github.com",
                "--trusted-host", "objects.githubusercontent.com"
            )
            if ($code -eq 0 -and (Test-LlamaCppImport)) { return 0 }
            return 1
        }
        "vulkan" {
            Write-Host "Instalando llama-cpp-python (wheel Vulkan precompilado)..." -ForegroundColor Cyan
            Write-Host "  URL: $wheelVulkan" -ForegroundColor DarkGray
            $code = Invoke-Pip @("install", "--upgrade", "--force-reinstall", "--no-cache-dir", $wheelVulkan)
            if ($code -eq 0 -and (Test-LlamaCppImport)) { return 0 }

            Write-Host "Reintento via indice abetlen (vulkan)..." -ForegroundColor Yellow
            $code = Invoke-Pip @(
                "install", "llama-cpp-python", "--upgrade", "--force-reinstall", "--no-cache-dir",
                "--extra-index-url", $idxVulkan,
                "--only-binary=llama-cpp-python",
                "--trusted-host", "abetlen.github.io",
                "--trusted-host", "github.com",
                "--trusted-host", "objects.githubusercontent.com"
            )
            if ($code -eq 0 -and (Test-LlamaCppImport)) { return 0 }

            Write-Host "No se pudo instalar el wheel Vulkan." -ForegroundColor Yellow
            return 1
        }
        default {
            Write-Host "Instalando llama-cpp-python (wheel CPU precompilado)..." -ForegroundColor Cyan
            Write-Host "  URL: $wheelCpu" -ForegroundColor DarkGray
            $code = Invoke-Pip @("install", "--upgrade", "--force-reinstall", "--no-cache-dir", $wheelCpu)
            if ($code -eq 0 -and (Test-LlamaCppImport)) { return 0 }

            Write-Host "Reintento via indice abetlen (cpu)..." -ForegroundColor Yellow
            $code = Invoke-Pip @(
                "install", "llama-cpp-python", "--upgrade", "--force-reinstall", "--no-cache-dir",
                "--extra-index-url", $idxCpu,
                "--only-binary=llama-cpp-python",
                "--trusted-host", "abetlen.github.io",
                "--trusted-host", "github.com",
                "--trusted-host", "objects.githubusercontent.com"
            )
            if ($code -eq 0 -and (Test-LlamaCppImport)) { return 0 }

            $pyVer = & $VenvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
            Write-Host ""
            Write-Host "Fallo al instalar wheel CPU (Python $pyVer). Revisa conexion a GitHub/PyPI." -ForegroundColor Yellow
            Write-Host "  Remove-Item -Recurse -Force `"$env:LOCALAPPDATA\Pygenesis\runtime`"" -ForegroundColor DarkGray
            return 1
        }
    }
}

$ErrorActionPreference = "Stop"
$ScriptsDir = $PSScriptRoot
$BackendRoot = Split-Path $ScriptsDir -Parent
$RepoRoot = Split-Path $BackendRoot -Parent

function Resolve-PygenesisPython {
    param([string]$Explicit)
    if ($Explicit -and (Test-Path $Explicit)) { return $Explicit }
    if ($env:PYGENESIS_PYTHON -and (Test-Path $env:PYGENESIS_PYTHON)) {
        return $env:PYGENESIS_PYTHON
    }
    $runtime = Join-Path $env:LOCALAPPDATA "Pygenesis\runtime\Scripts\python.exe"
    if (Test-Path $runtime) { return $runtime }
    $dev = Join-Path $RepoRoot "training\.venv\Scripts\python.exe"
    if (Test-Path $dev) { return $dev }
    return $null
}

$VenvPython = Resolve-PygenesisPython -Explicit $PythonExe
if (-not $VenvPython) {
    Write-Host "No se encontro Python de Pygenesis." -ForegroundColor Yellow
    Write-Host "Ejecuta installer\Install.bat o crea training\.venv con setup_env_windows.ps1" -ForegroundColor Yellow
    exit 1
}
Write-Host "Python: $VenvPython" -ForegroundColor DarkGray

$pyVerText = & $VenvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
if ($LASTEXITCODE -eq 0 -and $pyVerText) {
    $pyParts = $pyVerText.Trim().Split('.')
    $pyMinor = [int]$pyParts[1]
    if ($pyMinor -ge 13) {
        Write-Host ""
        Write-Host "Python $($pyVerText.Trim()) no tiene wheels de llama-cpp-python -> pip intenta compilar y falla por MAX_PATH." -ForegroundColor Yellow
        Write-Host "Borra el runtime y reinstala (el instalador preferira 3.12/3.11):" -ForegroundColor DarkGray
        Write-Host "  Remove-Item -Recurse -Force `"$env:LOCALAPPDATA\Pygenesis\runtime`"" -ForegroundColor DarkGray
        exit 1
    }
}

$detectedGpuName = ""
if ($Backend -eq "auto") {
    $detected = & (Join-Path $ScriptsDir "detect_gpu.ps1")
    $Backend = $detected.Backend
    $detectedGpuName = [string]$detected.GpuName
    Write-Host "GPU detectada: $detectedGpuName -> backend $Backend" -ForegroundColor Cyan
}

$requestedBackend = $Backend

Write-Host "Instalando dependencias base del puente..." -ForegroundColor Cyan
$reqCode = Invoke-Pip @("install", "-r", (Join-Path $BackendRoot "requirements.txt"))
if ($reqCode -ne 0) { exit 1 }

Write-Host "Instalando llama-cpp-python ($Backend)..." -ForegroundColor Cyan
$exitCode = Install-LlamaCpp -TargetBackend $Backend

if ($exitCode -ne 0 -and $Backend -eq "vulkan") {
    Write-Host ""
    Write-Host "Wheel Vulkan no disponible o fallo la descarga." -ForegroundColor Yellow
    if ($AllowCpuFallback) {
        Write-Host "Fallback a CPU (wheel precompilado)..." -ForegroundColor Cyan
        $Backend = "cpu"
        $exitCode = Install-LlamaCpp -TargetBackend "cpu"
    } else {
        Write-Host "Opciones:" -ForegroundColor Cyan
        Write-Host "  .\install_inference.ps1 -AllowCpuFallback" -ForegroundColor DarkGray
        Write-Host "  .\install_inference.ps1 -Backend vulkan   # reintentar wheel Vulkan" -ForegroundColor DarkGray
    }
}

if ($exitCode -ne 0 -and $Backend -eq "cuda" -and $AllowCpuFallback) {
    Write-Host ""
    Write-Host "CUDA no se pudo instalar; fallback a CPU..." -ForegroundColor Yellow
    $Backend = "cpu"
    $exitCode = Install-LlamaCpp -TargetBackend "cpu"
}

if ($exitCode -ne 0) { exit 1 }

if ($requestedBackend -ne $Backend) {
    Write-Host "AVISO: se solicito '$requestedBackend' y se instalo '$Backend'." -ForegroundColor Yellow
    if ($detectedGpuName) {
        Write-Host "  GPU: $detectedGpuName" -ForegroundColor DarkGray
    }
}

$dataDir = Join-Path $env:LOCALAPPDATA "Pygenesis"
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
$configPath = Join-Path $dataDir "bridge.env"

function Set-BridgeEnvValue {
    param([string]$Path, [string]$Name, [string]$Value)
    $lines = @()
    if (Test-Path $Path) {
        $lines = Get-Content $Path | Where-Object { $_ -notmatch "^\s*$([regex]::Escape($Name))\s*=" }
    }
    $lines += "$Name=$Value"
    $lines | Set-Content -Path $Path -Encoding UTF8
}

Set-BridgeEnvValue -Path $configPath -Name "PYGENESIS_GPU_BACKEND" -Value $Backend
Set-BridgeEnvValue -Path $configPath -Name "PYGENESIS_PYTHON" -Value $VenvPython

Write-Host ""
Write-Host "Inferencia instalada ($Backend)." -ForegroundColor Green
Write-Host "Config guardada en: $configPath" -ForegroundColor DarkGray
