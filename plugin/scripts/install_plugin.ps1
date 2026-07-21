#Requires -Version 5.1
<#
.SYNOPSIS
  Instala el plugin Pygenesis Resolve Tutor en DaVinci Resolve Studio.

.DESCRIPTION
  Copia plugin/com.pygenesis.davinci.tutor a la carpeta de Workflow Integration Plugins
  y busca WorkflowIntegration.node en el SDK de Resolve (Help > Documentation > Developer).

.EXAMPLE
  .\install_plugin.ps1
  .\install_plugin.ps1 -Force
#>
param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$PluginId = "com.pygenesis.davinci.tutor"
$PluginRoot = Split-Path $PSScriptRoot -Parent
$SourceDir = Join-Path $PluginRoot $PluginId
$TargetRoot = Join-Path $env:PROGRAMDATA "Blackmagic Design\DaVinci Resolve\Support\Workflow Integration Plugins"
$TargetDir = Join-Path $TargetRoot $PluginId

if (-not (Test-Path $SourceDir)) {
    throw "No se encontró el plugin en: $SourceDir"
}

$SdkCandidates = @(
    (Join-Path $env:PROGRAMDATA "Blackmagic Design\DaVinci Resolve\Support\Developer\Workflow Integrations\Examples\SamplePlugin\WorkflowIntegration.node")
    (Join-Path $env:PROGRAMDATA "Blackmagic Design\DaVinci Resolve\Support\Developer\Workflow Integrations\Examples\CompatibleSamplePlugin\WorkflowIntegration.node")
    "C:\Program Files\Blackmagic Design\DaVinci Resolve\Developer\Workflow Integrations\Examples\SamplePlugin\WorkflowIntegration.node"
    "C:\Program Files\Blackmagic Design\DaVinci Resolve\Developer\Workflow Integrations\Examples\CompatibleSamplePlugin\WorkflowIntegration.node"
    (Join-Path ${env:ProgramFiles} "Blackmagic Design\DaVinci Resolve\Developer\Workflow Integrations\Examples\SamplePlugin\WorkflowIntegration.node")
    (Join-Path ${env:ProgramFiles} "Blackmagic Design\DaVinci Resolve\Developer\Workflow Integrations\Examples\CompatibleSamplePlugin\WorkflowIntegration.node")
)

New-Item -ItemType Directory -Force -Path $TargetRoot | Out-Null

function Sync-PluginFiles {
    param([string]$From, [string]$To)
    Get-ChildItem -Path $From -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($From.Length).TrimStart('\')
        $destPath = Join-Path $To $relative
        $destParent = Split-Path $destPath -Parent
        if (-not (Test-Path $destParent)) {
            New-Item -ItemType Directory -Force -Path $destParent | Out-Null
        }
        Copy-Item -Path $_.FullName -Destination $destPath -Force
    }
}

# Importante: NO hacer Copy-Item carpeta -> carpeta ya existente (anida PluginId\PluginId\).
# Copiar el directorio del plugin al padre, o sincronizar ficheros al destino final.
$copied = $false
if (Test-Path $TargetDir) {
    if (-not $Force) {
        Write-Host "El plugin ya está instalado en:" -ForegroundColor Yellow
        Write-Host "  $TargetDir"
        Write-Host "Usa -Force para actualizar la instalación."
        exit 1
    }
    try {
        Remove-Item $TargetDir -Recurse -Force -ErrorAction Stop
    } catch {
        Write-Host "Resolve tiene archivos bloqueados; actualizando sin borrar carpeta..." -ForegroundColor Yellow
        Sync-PluginFiles -From $SourceDir -To $TargetDir
        $copied = $true
    }
}

if (-not $copied) {
    Copy-Item -Path $SourceDir -Destination $TargetRoot -Recurse -Force
}

Write-Host "Plugin copiado a: $TargetDir" -ForegroundColor Green

$manifestPath = Join-Path $TargetDir "manifest.xml"
if (-not (Test-Path $manifestPath)) {
    # Recuperacion si una instalacion previa dejo el arbol anidado
    $nestedManifest = Join-Path $TargetDir "$PluginId\manifest.xml"
    if (Test-Path $nestedManifest) {
        Write-Host "Detectada copia anidada; aplanando instalacion..." -ForegroundColor Yellow
        $nestedDir = Join-Path $TargetDir $PluginId
        Sync-PluginFiles -From $nestedDir -To $TargetDir
        Remove-Item $nestedDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
if (-not (Test-Path $manifestPath)) {
    throw "Falta manifest.xml en la instalacion: $manifestPath"
}
$manifestText = Get-Content $manifestPath -Raw
if ($manifestText -notmatch "<Plugin>" -or $manifestText -notmatch "<FilePath>") {
    Write-Host "AVISO: manifest.xml no usa el formato Blackmagic (<Plugin> + <FilePath>)." -ForegroundColor Yellow
    Write-Host "Resolve 20 ignora plugins con formato antiguo (<Main> sin <Plugin>)."
}

$nodeSrc = $SdkCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($nodeSrc) {
    $nodeDest = Join-Path $TargetDir "WorkflowIntegration.node"
    try {
        Copy-Item -Path $nodeSrc -Destination $nodeDest -Force -ErrorAction Stop
        Write-Host "WorkflowIntegration.node copiado desde:" -ForegroundColor Green
        Write-Host "  $nodeSrc"
    } catch {
        if (Test-Path $nodeDest) {
            Write-Host "WorkflowIntegration.node en uso por Resolve; se mantiene el existente." -ForegroundColor Yellow
        } else {
            throw
        }
    }
} else {
    Write-Host ""
    Write-Host "AVISO: No se encontró WorkflowIntegration.node en las rutas del SDK." -ForegroundColor Yellow
    Write-Host "Copia manualmente el archivo desde Resolve:" -ForegroundColor Yellow
    Write-Host "  Help > Documentation > Developer > Workflow Integrations > Examples > SamplePlugin"
    Write-Host "  -> WorkflowIntegration.node"
    Write-Host "  Destino: $TargetDir"
}

Write-Host ""
Write-Host "Siguiente paso:" -ForegroundColor Cyan
Write-Host "  1. Cierra DaVinci Resolve Studio por completo"
Write-Host "  2. Abre Resolve Studio"
Write-Host "  3. Workspace > Workflow Integrations > Pygenesis Resolve Tutor"
