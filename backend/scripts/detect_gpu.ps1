#Requires -Version 5.1
<#
.SYNOPSIS
  Detecta GPU y recomienda backend de inferencia (cuda | vulkan | cpu).

.OUTPUTS
  Objeto PSCustomObject con Backend, GpuName, Source

.EXAMPLE
  .\detect_gpu.ps1
  .\detect_gpu.ps1 | Select-Object -ExpandProperty Backend
#>
param(
    [ValidateSet("auto", "cuda", "vulkan", "cpu")]
    [string]$Prefer = "auto"
)

function Test-NvidiaGpu {
    $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if (-not $nvidiaSmi) { return $null }

    try {
        $name = & nvidia-smi --query-gpu=name --format=csv,noheader 2>$null | Select-Object -First 1
        if ($name) {
            return [PSCustomObject]@{
                Backend = "cuda"
                GpuName = $name.Trim()
                Source  = "nvidia-smi"
            }
        }
    } catch {
        return $null
    }
    return $null
}

function Test-AmdGpu {
    try {
        $controllers = Get-CimInstance Win32_VideoController -ErrorAction Stop |
            Where-Object {
                $_.Name -match "AMD|Radeon" -or $_.AdapterCompatibility -match "AMD|ATI"
            }
        if ($controllers) {
            $first = $controllers | Select-Object -First 1
            return [PSCustomObject]@{
                Backend = "vulkan"
                GpuName = $first.Name
                Source  = "Win32_VideoController"
            }
        }
    } catch {
        return $null
    }
    return $null
}

if ($Prefer -ne "auto") {
    [PSCustomObject]@{
        Backend = $Prefer
        GpuName = "forzado por parámetro"
        Source  = "manual"
    }
    return
}

$nvidia = Test-NvidiaGpu
if ($nvidia) {
    $nvidia
    return
}

$amd = Test-AmdGpu
if ($amd) {
    $amd
    return
}

[PSCustomObject]@{
    Backend = "cpu"
    GpuName = "Sin GPU dedicada detectada"
    Source  = "fallback"
}
