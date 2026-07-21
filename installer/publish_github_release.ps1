#Requires -Version 5.1
<#
.SYNOPSIS
  Crea un GitHub Release y sube el .exe portable de Companion.

.EXAMPLE
  .\installer\publish_github_release.ps1
  .\installer\publish_github_release.ps1 -Tag v0.2.8
#>
param(
    [string]$Tag = "v0.2.8",
    [string]$ExePath = "",
    [string]$Repo = "Asociacion-Pygenesis/Pygenesis_Resolve_Expert"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
if (-not $ExePath) {
    $ExePath = Join-Path $RepoRoot "companion\dist\Pygenesis-Companion-0.2.8-portable.exe"
}

if (-not (Test-Path $ExePath)) {
    throw "No se encontro el exe: $ExePath`nEjecuta: cd companion\pygenesis-companion; npm run build"
}

$notesFile = Join-Path $env:TEMP "pygenesis-gh-release-notes.md"
@"
## Pygenesis ResolveExpert $Tag

Local DaVinci Resolve assistant with a **setup wizard** inside Companion (checks what you have and installs what is missing).

### Download
- **Pygenesis Companion** (Windows portable): attached to this release
- GGUF model: [SuNavar/Pygenesis_ResolveExpert](https://huggingface.co/SuNavar/Pygenesis_ResolveExpert) (downloaded on install)

### Requirements
- Windows 10/11
- Python **3.10–3.12** on PATH (prefer **3.12**; avoid 3.13/3.14 — no binary wheels)
- Internet (first model download)

### GPU
- **NVIDIA:** CUDA wheels (abetlen index)
- **AMD:** Vulkan **prebuilt wheel** (no compile / no Build Tools). If the wheel fails, CPU wheel is used automatically.

### Usage
1. Run the portable ``.exe``
2. Click **Install what's missing**
3. **Start bridge** → **Continue to chat**
4. Studio: Workspace → Workflow Integrations → Pygenesis Resolve Tutor

### Source
Code lives in the repository; the ``.exe`` is only published via Releases (not in git).

---

## Espanol

Asistente local para DaVinci Resolve. Descarga el ``.exe``, pulsa **Instalar lo que falta**, arranca el puente y continua al chat. En AMD se instala wheel Vulkan precompilado; si falla, CPU.
"@ | Set-Content -Path $notesFile -Encoding UTF8

Push-Location $RepoRoot
try {
    Write-Host "Creando GitHub Release $Tag en $Repo ..." -ForegroundColor Cyan
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    gh release view $Tag --repo $Repo 2>$null | Out-Null
    $exists = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = $prevEap

    if ($exists) {
        Write-Host "El release $Tag ya existe; subiendo/reemplazando asset..." -ForegroundColor Yellow
        gh release upload $Tag $ExePath --repo $Repo --clobber
    } else {
        gh release create $Tag $ExePath `
            --repo $Repo `
            --title "Pygenesis ResolveExpert $Tag" `
            --notes-file $notesFile `
            --latest
    }
    Write-Host ""
    Write-Host "Listo: https://github.com/$Repo/releases/tag/$Tag" -ForegroundColor Green
} finally {
    Pop-Location
}
