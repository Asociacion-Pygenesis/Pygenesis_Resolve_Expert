#Requires -Version 5.1
<#
.SYNOPSIS
  Arranca el puente de inferencia FastAPI para el plugin Resolve.

.PARAMETER Force
  Si el puerto está ocupado, detiene todos los procesos uvicorn/python del puente y reinicia.

.EXAMPLE
  .\start_backend.ps1
  .\start_backend.ps1 -Force
#>
param(
    [int]$Port = 8000,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$BackendRoot = Split-Path $PSScriptRoot -Parent
$RepoRoot = Split-Path $BackendRoot -Parent
$BridgeEnv = Join-Path $env:LOCALAPPDATA "Pygenesis\bridge.env"

if (Test-Path $BridgeEnv) {
    Get-Content $BridgeEnv | ForEach-Object {
        if ($_ -match '^\s*([^#=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Item -Path "Env:$name" -Value $value
        }
    }
}

function Resolve-PygenesisPython {
    if ($env:PYGENESIS_PYTHON) {
        $candidate = $env:PYGENESIS_PYTHON.Trim()
        # bridge.env corrupto a veces mezcla salida de pip + ruta
        if ($candidate -match '(?i)((?:[A-Za-z]:\\|\\\\)[^\r\n]*python\.exe)\s*$') {
            $candidate = $Matches[1].Trim()
        }
        if (($candidate -match '(?i)\.exe$') -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
        Write-Host "PYGENESIS_PYTHON invalido; usando runtime por defecto." -ForegroundColor Yellow
    }
    $runtime = Join-Path $env:LOCALAPPDATA "Pygenesis\runtime\Scripts\python.exe"
    if (Test-Path $runtime) { return $runtime }
    $dev = Join-Path $RepoRoot "training\.venv\Scripts\python.exe"
    if (Test-Path $dev) { return $dev }
    return $null
}

$VenvPython = Resolve-PygenesisPython

if (-not $env:VULKAN_SDK) {
    $machineVulkan = [Environment]::GetEnvironmentVariable("VULKAN_SDK", "Machine")
    if ($machineVulkan -and (Test-Path $machineVulkan)) {
        $env:VULKAN_SDK = $machineVulkan
        $env:Path = "$machineVulkan\Bin;$env:Path"
    } elseif (Test-Path "C:\VulkanSDK") {
        $latest = Get-ChildItem "C:\VulkanSDK" -Directory | Sort-Object Name -Descending | Select-Object -First 1
        if ($latest) {
            $env:VULKAN_SDK = $latest.FullName
            $env:Path = "$($latest.FullName)\Bin;$env:Path"
        }
    }
}

function Get-ListenerPids([int]$ListenPort) {
    $pids = New-Object System.Collections.Generic.List[int]
    $pattern = ":$ListenPort\s+.*LISTENING"
    netstat -ano | Select-String $pattern | ForEach-Object {
        $parts = ($_.ToString().Trim() -split '\s+')
        $pidStr = $parts[-1]
        if ($pidStr -match '^\d+$') {
            [void]$pids.Add([int]$pidStr)
        }
    }
    return $pids | Sort-Object -Unique
}

function Get-UvicornPids([int]$ListenPort) {
    $pids = New-Object System.Collections.Generic.List[int]
    Get-CimInstance Win32_Process -Filter "Name='python.exe'" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $cmd = $_.CommandLine
            if (-not $cmd) { return }
            $isUvicorn = ($cmd -match 'uvicorn') -and ($cmd -match 'main:app')
            $isWorker = $cmd -match 'multiprocessing\.spawn' -and $cmd -match 'spawn_main'
            $matchesPort = $cmd -match "port\s+$ListenPort"
            if ($isUvicorn -or $isWorker) {
                [void]$pids.Add($_.ProcessId)
            }
        }
    return $pids | Sort-Object -Unique
}

function Stop-BridgeProcesses([int]$ListenPort) {
    $targets = @()
    $targets += Get-ListenerPids -ListenPort $ListenPort
    $targets += Get-UvicornPids -ListenPort $ListenPort
    $targets = $targets | Sort-Object -Unique

    if ($targets.Count -eq 0) {
        return $true
    }

    Write-Host "Deteniendo procesos del puente (PIDs: $($targets -join ', '))..." -ForegroundColor Yellow
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    foreach ($procId in $targets) {
        & taskkill.exe /F /T /PID $procId *> $null
    }
    $ErrorActionPreference = $prevEap

    for ($attempt = 1; $attempt -le 15; $attempt++) {
        Start-Sleep -Milliseconds 400
        $remaining = Get-ListenerPids -ListenPort $ListenPort
        if ($remaining.Count -eq 0) {
            return $true
        }
        $ErrorActionPreference = "Continue"
        foreach ($procId in $remaining) {
            & taskkill.exe /F /T /PID $procId *> $null
        }
        $ErrorActionPreference = $prevEap
    }

    $still = Get-ListenerPids -ListenPort $ListenPort
    if ($still.Count -gt 0) {
        Write-Host "No se pudo liberar el puerto $ListenPort. PIDs restantes: $($still -join ', ')" -ForegroundColor Red
        Write-Host "Cierra manualmente esos procesos o reinicia Resolve/terminales con uvicorn." -ForegroundColor Yellow
        return $false
    }
    return $true
}

function Test-BridgeHealth([int]$ListenPort) {
    try {
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:$ListenPort/health" -TimeoutSec 2
        return ($resp.status -eq "ok")
    } catch {
        return $false
    }
}

if (-not $VenvPython) {
    Write-Host "No se encontró el runtime de Pygenesis." -ForegroundColor Yellow
    Write-Host "Ejecuta installer\Install.bat (usuario) o training\scripts\setup_env_windows.ps1 (dev)." -ForegroundColor Yellow
    exit 1
}

$listenerPids = Get-ListenerPids -ListenPort $Port
if ($listenerPids.Count -gt 0) {
    if ((Test-BridgeHealth -ListenPort $Port) -and -not $Force) {
        Write-Host "El puente ya está activo en http://127.0.0.1:$Port" -ForegroundColor Green
        Write-Host "Health: http://127.0.0.1:$Port/health" -ForegroundColor DarkGray
        Write-Host "PIDs en puerto ${Port}: $($listenerPids -join ', ')" -ForegroundColor DarkGray
        Write-Host "Para reiniciar: .\start_backend.ps1 -Force" -ForegroundColor Yellow
        exit 0
    }

    if (-not (Stop-BridgeProcesses -ListenPort $Port)) {
        exit 1
    }
}

$UvicornCheck = & $VenvPython -m uvicorn --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Instalando dependencias del puente (primera vez)..." -ForegroundColor Yellow
    & $VenvPython -m pip install -r (Join-Path $BackendRoot "requirements.txt")
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

Set-Location $BackendRoot
Write-Host "Puente ResolveExpert en http://127.0.0.1:$Port" -ForegroundColor Cyan
Write-Host "Health: http://127.0.0.1:$Port/health" -ForegroundColor DarkGray
Write-Host "Ctrl+C para detener." -ForegroundColor DarkGray

& $VenvPython -m uvicorn main:app --host 127.0.0.1 --port $Port
