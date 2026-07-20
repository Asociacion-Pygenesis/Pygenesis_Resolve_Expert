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
        }
        "vulkan" {
            $vulkanSdk = Resolve-VulkanSdkPath
            if (-not $vulkanSdk) {
                Write-Host ""
                Write-Host "No se encontró el Vulkan SDK completo (solo runtime no sirve para compilar)." -ForegroundColor Red
                Write-Host "Instala el SDK Installer (~309 MB), no solo VulkanRT:" -ForegroundColor Yellow
                Write-Host "  vulkansdk-windows-X64-1.4.350.0.exe" -ForegroundColor Yellow
                Write-Host "Marca la opción de añadir variables de entorno al PATH." -ForegroundColor Yellow
                Write-Host "Luego abre una PowerShell NUEVA y repite este script." -ForegroundColor Yellow
                return 1
            }

            Write-Host "Vulkan SDK: $vulkanSdk" -ForegroundColor DarkGray
            $vulkanSdkCmake = ($vulkanSdk -replace '\\', '/')
            $env:VULKAN_SDK = $vulkanSdk
            $env:Path = "$vulkanSdk\Bin;$env:Path"
            $env:CMAKE_ARGS = "-DGGML_VULKAN=on"
            $env:CMAKE_PREFIX_PATH = $vulkanSdkCmake
            $env:FORCE_CMAKE = "1"

            & $VenvPython -m pip install llama-cpp-python --upgrade --force-reinstall --no-cache-dir
            $code = $LASTEXITCODE

            if ($code -ne 0) {
                & $VenvPython -c "import llama_cpp" 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "pip devolvió error pero llama_cpp importa OK; continuando." -ForegroundColor Yellow
                    $code = 0
                }
            }

            Remove-Item Env:CMAKE_ARGS -ErrorAction SilentlyContinue
            Remove-Item Env:CMAKE_PREFIX_PATH -ErrorAction SilentlyContinue
            Remove-Item Env:FORCE_CMAKE -ErrorAction SilentlyContinue
            return $code
        }
        default {
            & $VenvPython -m pip install llama-cpp-python --upgrade --force-reinstall --no-cache-dir
        }
    }
    return $LASTEXITCODE
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
    Write-Host "No se encontró Python de Pygenesis." -ForegroundColor Yellow
    Write-Host "Ejecuta installer\Install.bat o crea training\.venv con setup_env_windows.ps1" -ForegroundColor Yellow
    exit 1
}
Write-Host "Python: $VenvPython" -ForegroundColor DarkGray

if ($Backend -eq "auto") {
    $detected = & (Join-Path $ScriptsDir "detect_gpu.ps1")
    $Backend = $detected.Backend
    Write-Host "GPU detectada: $($detected.GpuName) → backend $Backend" -ForegroundColor Cyan
}

Write-Host "Instalando dependencias base del puente..." -ForegroundColor Cyan
& $VenvPython -m pip install -r (Join-Path $BackendRoot "requirements.txt")
if ($LASTEXITCODE -ne 0) { exit 1 }

$requestedBackend = $Backend
Write-Host "Instalando llama-cpp-python ($Backend)..." -ForegroundColor Cyan
$exitCode = Install-LlamaCpp -TargetBackend $Backend

if ($exitCode -ne 0 -and $Backend -eq "vulkan") {
    Write-Host ""
    Write-Host "Vulkan no se pudo compilar." -ForegroundColor Yellow
    if (-not (Resolve-VulkanSdkPath)) {
        Write-Host "Causa probable: falta el SDK completo (headers + glslc + vulkan-1.lib)." -ForegroundColor Yellow
        Write-Host "VulkanRT solo sirve para ejecutar; no para compilar llama-cpp-python." -ForegroundColor Yellow
    } else {
        Write-Host "Revisa que VS Build Tools tenga 'Desarrollo de escritorio con C++'." -ForegroundColor Yellow
    }
    if ($AllowCpuFallback) {
        Write-Host ""
        Write-Host "Fallback a CPU (wheel precompilado)..." -ForegroundColor Cyan
        $Backend = "cpu"
        $exitCode = Install-LlamaCpp -TargetBackend "cpu"
    } else {
        Write-Host ""
        Write-Host "Opciones:" -ForegroundColor Cyan
        Write-Host "  .\install_inference.ps1 -AllowCpuFallback   # CPU ahora (lento)" -ForegroundColor DarkGray
        Write-Host "  Instala VS Build Tools y repite con -Backend vulkan" -ForegroundColor DarkGray
    }
}

if ($exitCode -ne 0) { exit 1 }

if ($requestedBackend -eq "vulkan" -and $Backend -eq "cpu") {
    Write-Host "AVISO: se instaló CPU en lugar de Vulkan." -ForegroundColor Yellow
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
