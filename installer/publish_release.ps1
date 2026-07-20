#Requires -Version 5.1
<#
.SYNOPSIS
  Crea el GitLab Release v0.2.0 y sube el .exe portable de Companion.

.DESCRIPTION
  Requiere: glab autenticado (`glab auth login`) con permiso Developer+ en el proyecto.

.EXAMPLE
  glab auth login
  .\installer\publish_release.ps1
#>
param(
    [string]$Tag = "v0.2.5",
    [string]$ExePath = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
if (-not $ExePath) {
    $ExePath = Join-Path $RepoRoot "companion\dist\Pygenesis-Companion-0.2.5-portable.exe"
}

if (-not (Test-Path $ExePath)) {
    throw "No se encontro el exe: $ExePath`nEjecuta antes: cd companion\pygenesis-companion; npm run build"
}

Push-Location $RepoRoot
try {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $authOut = glab auth status 2>&1 | Out-String
    $ErrorActionPreference = $prevEap
    if ($authOut -match "401 Unauthorized|No token found|Unauthenticated|could not authenticate") {
        Write-Host "glab no tiene token de API." -ForegroundColor Yellow
        Write-Host "Ejecuta: glab auth login" -ForegroundColor Cyan
        Write-Host "  (elige gitlab.com, HTTPS, y un Personal Access Token con scope 'api')" -ForegroundColor DarkGray
        exit 1
    }
    if ($authOut -notmatch "Logged in") {
        Write-Host "No se pudo verificar login de glab. Salida:" -ForegroundColor Yellow
        Write-Host $authOut
        Write-Host "Si ya autenticaste, prueba: glab auth status" -ForegroundColor Cyan
        exit 1
    }

    $notes = @"
## Pygenesis ResolveExpert $Tag

Companion con **asistente de instalacion** (comprueba e instala lo que falta) + instalador cerrado.

### Descarga
- **Pygenesis Companion** (Windows portable): adjunto en este release
- Modelo GGUF: [SuNavar/Pygenesis_ResolveExpert](https://huggingface.co/SuNavar/Pygenesis_ResolveExpert) (se descarga al instalar)

### Requisitos
- Windows 10/11
- Python 3.10+ en PATH
- Internet (primera instalacion del modelo)

### Uso
1. Ejecuta el ``.exe`` portable
2. Pulsa **Instalar lo que falta**
3. **Arrancar puente** → **Continuar al chat**
4. Studio: Workspace → Workflow Integrations → Pygenesis Resolve Tutor

### Codigo
Las fuentes estan en el repo; el ``.exe`` solo en Releases (no en git).
"@

    $asset = "$ExePath#Pygenesis Companion (Windows portable)#other"
    Write-Host "Creando release $Tag y subiendo exe (~71 MB)..." -ForegroundColor Cyan
    glab release create $Tag $asset `
        --name "Pygenesis ResolveExpert $Tag" `
        --notes $notes `
        --ref master `
        --use-package-registry

    Write-Host ""
    Write-Host "Listo. Release:" -ForegroundColor Green
    Write-Host "  https://gitlab.com/SunoNavarro/pygenesis_resolveexpert/-/releases/$Tag"
} finally {
    Pop-Location
}
