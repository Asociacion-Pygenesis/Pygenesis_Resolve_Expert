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

function Install-LlamaCpp {
    param([string]$TargetBackend)

    function Use-ShortTemp {
        $shortTemp = "C:\pgbuild"
        New-Item -ItemType Directory -Force -Path $shortTemp | Out-Null
        $script:PrevTemp = $env:TEMP
        $script:PrevTmp = $env:TMP
        $env:TEMP = $shortTemp
        $env:TMP = $shortTemp
        Write-Host "TEMP corto: $shortTemp" -ForegroundColor DarkGray
    }
    function Restore-Temp {
        if ($null -ne $script:PrevTemp) { $env:TEMP = $script:PrevTemp }
        if ($null -ne $script:PrevTmp) { $env:TMP = $script:PrevTmp }
    }

    switch ($TargetBackend) {
        "cuda" {
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            & $VenvPython -m pip install llama-cpp-python --upgrade --force-reinstall --no-cache-dir `
                --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cu124 `
                --only-binary=:all:
            $code = $LASTEXITCODE
            if ($code -ne 0) {
                Write-Host "Sin wheel CUDA para este Python; intentando install estandar..." -ForegroundColor Yellow
                Use-ShortTemp
                & $VenvPython -m pip install llama-cpp-python --upgrade --force-reinstall --no-cache-dir `
                    --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cu124
                $code = $LASTEXITCODE
                Restore-Temp
            }
            $ErrorActionPreference = $prevEap
            return $code
        }
        "vulkan" {
            $vulkanSdk = Resolve-VulkanSdkPath
            if (-not $vulkanSdk) {
                Write-Host "Vulkan SDK completo no disponible." -ForegroundColor Yellow
                return 1
            }

            Write-Host "Vulkan SDK: $vulkanSdk" -ForegroundColor DarkGray
            Use-ShortTemp

            $vulkanSdkCmake = ($vulkanSdk -replace '\\', '/')
            $env:VULKAN_SDK = $vulkanSdk
            $env:Path = "$vulkanSdk\Bin;$env:Path"
            $env:CMAKE_ARGS = "-DGGML_VULKAN=on"
            $env:CMAKE_PREFIX_PATH = $vulkanSdkCmake
            $env:FORCE_CMAKE = "1"

            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            & $VenvPython -m pip install llama-cpp-python --upgrade --force-reinstall --no-cache-dir
            $code = $LASTEXITCODE

            if ($code -ne 0) {
                & $VenvPython -c "import llama_cpp" 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "pip devolvio error pero llama_cpp importa OK; continuando." -ForegroundColor Yellow
                    $code = 0
                } else {
                    Write-Host ""
                    Write-Host "Fallo al compilar llama-cpp-python con Vulkan (MAX_PATH / Build Tools)." -ForegroundColor Yellow
                    Write-Host "En la practica, para AMD suele ser mas fiable usar CPU con Python 3.12." -ForegroundColor DarkGray
                }
            }
            $ErrorActionPreference = $prevEap

            Restore-Temp
            Remove-Item Env:CMAKE_ARGS -ErrorAction SilentlyContinue
            Remove-Item Env:CMAKE_PREFIX_PATH -ErrorAction SilentlyContinue
            Remove-Item Env:FORCE_CMAKE -ErrorAction SilentlyContinue
            return $code
        }
        default {
            # CPU: exigir wheel binario para no descomprimir vendor/svelte (MAX_PATH)
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            Write-Host "Instalando llama-cpp-python (wheel binario CPU)..." -ForegroundColor Cyan
            & $VenvPython -m pip install llama-cpp-python --upgrade --force-reinstall --only-binary=:all:
            $code = $LASTEXITCODE
            if ($code -ne 0) {
                $ver = & $VenvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
                Write-Host ""
                Write-Host "No hay wheel CPU para Python $ver." -ForegroundColor Yellow
                Write-Host "Usa Python 3.11 o 3.12, borra el runtime y reinstala:" -ForegroundColor DarkGray
                Write-Host "  Remove-Item -Recurse -Force `"$env:LOCALAPPDATA\Pygenesis\runtime`"" -ForegroundColor DarkGray
                Write-Host "  Luego Install.bat / Companion (creara venv con 3.12 si esta instalado)." -ForegroundColor DarkGray
            }
            $ErrorActionPreference = $prevEap
            return $code
        }
    }
}

function Resolve-VulkanSdkPath {
    $candidates = @()

    if ($env:VULKAN_SDK -and (Test-Path $env:VULKAN_SDK)) {
        $candidates += $env:VULKAN_SDK
    }

    $machineVulkan = [Environment]::GetEnvironmentVariable("VULKAN_SDK", "Machine")
    if ($machineVulkan -and (Test-Path $machineVulkan)) {
        $candidates += $machineVulkan
    }

    if (Test-Path "C:\VulkanSDK") {
        $candidates += Get-ChildItem "C:\VulkanSDK" -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            ForEach-Object { $_.FullName }
    }

    foreach ($root in ($candidates | Select-Object -Unique)) {
        $glslc = Join-Path $root "Bin\glslc.exe"
        $include = Join-Path $root "Include\vulkan\vulkan.h"
        $lib = Join-Path $root "Lib\vulkan-1.lib"
        if ((Test-Path $glslc) -and (Test-Path $include) -and (Test-Path $lib)) {
            return $root
        }
    }

    return $null
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

# AMD/Vulkan sin SDK: no intentar compilar; pasar a CPU si hay fallback
if ($Backend -eq "vulkan" -and -not (Resolve-VulkanSdkPath)) {
    Write-Host ""
    Write-Host "GPU AMD/Vulkan detectada, pero no hay Vulkan SDK completo." -ForegroundColor Yellow
    Write-Host "El runtime (VulkanRT) NO sirve para compilar llama-cpp-python." -ForegroundColor DarkGray
    Write-Host "Para aceleracion GPU en AMD necesitas:" -ForegroundColor DarkGray
    Write-Host "  1) LunarG Vulkan SDK (SDK Installer, no solo runtime): https://vulkan.lunarg.com/sdk/home" -ForegroundColor DarkGray
    Write-Host "  2) Visual Studio Build Tools con 'Desarrollo de escritorio con C++'" -ForegroundColor DarkGray
    Write-Host "  3) PowerShell nueva y: .\install_inference.ps1 -Backend vulkan" -ForegroundColor DarkGray
    if ($AllowCpuFallback) {
        Write-Host ""
        Write-Host "Instalando backend CPU (funciona sin SDK; mas lento)..." -ForegroundColor Cyan
        $Backend = "cpu"
    } else {
        Write-Host ""
        Write-Host "Sin -AllowCpuFallback no se puede continuar. Opciones:" -ForegroundColor Red
        Write-Host "  .\install_inference.ps1 -AllowCpuFallback" -ForegroundColor DarkGray
        Write-Host "  Instala Vulkan SDK + Build Tools y repite -Backend vulkan" -ForegroundColor DarkGray
        exit 1
    }
}

Write-Host "Instalando dependencias base del puente..." -ForegroundColor Cyan
& $VenvPython -m pip install -r (Join-Path $BackendRoot "requirements.txt")
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "Instalando llama-cpp-python ($Backend)..." -ForegroundColor Cyan
$exitCode = Install-LlamaCpp -TargetBackend $Backend

if ($exitCode -ne 0 -and $Backend -eq "vulkan") {
    Write-Host ""
    Write-Host "Vulkan no se pudo compilar (SDK presente pero fallo el build)." -ForegroundColor Yellow
    Write-Host "Revisa VS Build Tools (C++) y TEMP corto C:\pgbuild. En AMD es habitual caer a CPU." -ForegroundColor DarkGray
    if ($AllowCpuFallback) {
        Write-Host ""
        Write-Host "Fallback a CPU (wheel precompilado)..." -ForegroundColor Cyan
        $Backend = "cpu"
        $exitCode = Install-LlamaCpp -TargetBackend "cpu"
    } else {
        Write-Host ""
        Write-Host "Opciones:" -ForegroundColor Cyan
        Write-Host "  .\install_inference.ps1 -AllowCpuFallback   # CPU ahora (lento)" -ForegroundColor DarkGray
        Write-Host "  Activa LongPathsEnabled + Build Tools y repite -Backend vulkan" -ForegroundColor DarkGray
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
