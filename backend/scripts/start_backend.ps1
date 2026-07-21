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
$LogDir = Join-Path $env:LOCALAPPDATA "Pygenesis\logs"
$RunLog = Join-Path $LogDir "backend.log"

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Write-BridgeLog {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    try {
        [System.IO.File]::AppendAllText($RunLog, $line + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
    } catch {
        try { Add-Content -LiteralPath $RunLog -Value $line -Encoding UTF8 } catch { }
    }
    Write-Host $Message
}

try {
    [System.IO.File]::AppendAllText($RunLog, ("[{0}] === start_backend.ps1 begin ===" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss")) + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
} catch { }

Write-BridgeLog "Script=$PSCommandPath"
Write-BridgeLog "BackendRoot=$BackendRoot"
Write-BridgeLog "Port=$Port Force=$Force"

if (Test-Path $BridgeEnv) {
    Write-BridgeLog "Cargando bridge.env"
    Get-Content $BridgeEnv | ForEach-Object {
        if ($_ -match '^\s*([^#=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Item -Path "Env:$name" -Value $value
            if ($name -eq "PYGENESIS_PYTHON" -or $name -eq "PYGENESIS_MODEL_PATH" -or $name -eq "PYGENESIS_GPU_BACKEND") {
                Write-BridgeLog ("  {0}={1}" -f $name, $value)
            }
        }
    }
} else {
    Write-BridgeLog "AVISO: no existe bridge.env"
}

function Resolve-PygenesisPython {
    if ($env:PYGENESIS_PYTHON) {
        $candidate = $env:PYGENESIS_PYTHON.Trim()
        if ($candidate -match '(?i)((?:[A-Za-z]:\\|\\\\)[^\r\n]*python\.exe)\s*$') {
            $candidate = $Matches[1].Trim()
        }
        if (($candidate -match '(?i)\.exe$') -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
        Write-BridgeLog "PYGENESIS_PYTHON invalido; usando runtime por defecto."
    }
    $runtime = Join-Path $env:LOCALAPPDATA "Pygenesis\runtime\Scripts\python.exe"
    if (Test-Path $runtime) { return $runtime }
    $dev = Join-Path $RepoRoot "training\.venv\Scripts\python.exe"
    if (Test-Path $dev) { return $dev }
    return $null
}

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

    Write-BridgeLog "Deteniendo procesos del puente (PIDs: $($targets -join ', '))"
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
        Write-BridgeLog "ERROR: no se pudo liberar el puerto $ListenPort. PIDs: $($still -join ', ')"
        return $false
    }
    return $true
}

function Test-BridgeHealth([int]$ListenPort) {
    try {
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:$ListenPort/health" -TimeoutSec 2
        return ($null -ne $resp.status)
    } catch {
        return $false
    }
}

try {
    $VenvPython = Resolve-PygenesisPython
    if (-not $VenvPython) {
        Write-BridgeLog "ERROR: No se encontro el runtime de Pygenesis."
        Write-BridgeLog "Ejecuta Install.bat / Companion (Instalar lo que falta)."
        exit 1
    }
    Write-BridgeLog "Python=$VenvPython"
    $pyVer = & $VenvPython -c "import sys; print(sys.version)" 2>&1
    Write-BridgeLog "Version=$pyVer"

    $listenerPids = Get-ListenerPids -ListenPort $Port
    if ($listenerPids.Count -gt 0) {
        if ((Test-BridgeHealth -ListenPort $Port) -and -not $Force) {
            Write-BridgeLog "El puente ya esta activo en http://127.0.0.1:$Port"
            exit 0
        }
        if (-not (Stop-BridgeProcesses -ListenPort $Port)) {
            exit 1
        }
    }

    $mainPy = Join-Path $BackendRoot "main.py"
    if (-not (Test-Path -LiteralPath $mainPy)) {
        Write-BridgeLog "ERROR: no existe main.py en $BackendRoot"
        exit 1
    }

    Write-BridgeLog "Comprobando uvicorn..."
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $UvicornCheck = & $VenvPython -m uvicorn --version 2>&1
    $uvCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    Write-BridgeLog "uvicorn check exit=$uvCode :: $UvicornCheck"
    if ($uvCode -ne 0) {
        Write-BridgeLog "Instalando dependencias del puente..."
        & $VenvPython -m pip install -r (Join-Path $BackendRoot "requirements.txt") 2>&1 |
            ForEach-Object { Write-BridgeLog "$_" }
        if ($LASTEXITCODE -ne 0) {
            Write-BridgeLog "ERROR: falló pip install requirements.txt"
            exit 1
        }
    }

    Set-Location -LiteralPath $BackendRoot
    Write-BridgeLog "Puente ResolveExpert en http://127.0.0.1:$Port"
    Write-BridgeLog "Lanzando: $VenvPython -m uvicorn main:app --host 127.0.0.1 --port $Port"

    # Critico: con ErrorAction Stop, cualquier linea en stderr de uvicorn
    # (Traceback, logs) se convierte en excepcion y mata el script.
    $env:PYTHONUNBUFFERED = "1"
    $ErrorActionPreference = "Continue"
    & $VenvPython -m uvicorn main:app --host 127.0.0.1 --port $Port
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 1 }
    Write-BridgeLog "uvicorn termino con codigo $code"
    exit $code
} catch {
    Write-BridgeLog ("ERROR FATAL: " + $_.Exception.Message)
    if ($_.Exception.InnerException) {
        Write-BridgeLog ("Inner: " + $_.Exception.InnerException.Message)
    }
    Write-BridgeLog ("Tipo: " + $_.Exception.GetType().FullName)
    Write-BridgeLog ($_.ScriptStackTrace)
    exit 1
}
