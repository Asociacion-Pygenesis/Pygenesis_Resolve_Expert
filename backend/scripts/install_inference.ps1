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
    switch ($TargetBackend) {
        "cuda" {
            & $VenvPython -m pip install llama-cpp-python --upgrade --force-reinstall --no-cache-dir `
                --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cu124
            return $LASTEXITCODE
        }
        "vulkan" {
            $vulkanSdk = Resolve-VulkanSdkPath
            if (-not $vulkanSdk) {
                Write-Host "Vulkan SDK completo no disponible." -ForegroundColor Yellow
                return 1
            }

            Write-Host "Vulkan SDK: $vulkanSdk" -ForegroundColor DarkGray
            # pip + vendor/llama.cpp crea rutas enorme (svelte UI); en Windows falla sin TEMP corto.
            $shortTemp = "C:\pgbuild"
            New-Item -ItemType Directory -Force -Path $shortTemp | Out-Null
            $prevTemp = $env:TEMP
            $prevTmp = $env:TMP
            $env:TEMP = $shortTemp
            $env:TMP = $shortTemp
            Write-Host "TEMP corto para build: $shortTemp (evita MAX_PATH en Windows)" -ForegroundColor DarkGray

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
                    Write-Host "Fallo al compilar llama-cpp-python con Vulkan." -ForegroundColor Yellow
                    Write-Host "Causas frecuentes en Windows:" -ForegroundColor DarkGray
                    Write-Host "  - Rutas demasiado largas (MAX_PATH) al descomprimir vendor/llama.cpp" -ForegroundColor DarkGray
                    Write-Host "  - Falta VS Build Tools (C++)" -ForegroundColor DarkGray
                    Write-Host "Opcional: activa rutas largas (admin) y reintenta:" -ForegroundColor DarkGray
                    Write-Host "  New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -Value 1 -PropertyType DWORD -Force" -ForegroundColor DarkGray
                }
            }
            $ErrorActionPreference = $prevEap

            if ($prevTemp) { $env:TEMP = $prevTemp } else { Remove-Item Env:TEMP -ErrorAction SilentlyContinue }
            if ($prevTmp) { $env:TMP = $prevTmp } else { Remove-Item Env:TMP -ErrorAction SilentlyContinue }
            Remove-Item Env:CMAKE_ARGS -ErrorAction SilentlyContinue
            Remove-Item Env:CMAKE_PREFIX_PATH -ErrorAction SilentlyContinue
            Remove-Item Env:FORCE_CMAKE -ErrorAction SilentlyContinue
            return $code
        }
        default {
            & $VenvPython -m pip install llama-cpp-python --upgrade --force-reinstall --no-cache-dir
            return $LASTEXITCODE
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
