# Pygenesis Companion

App Electron para **DaVinci Resolve Free** (tambien usable en Studio). Al abrirla actua como **asistente de instalacion** (como en Unity): muestra que tienes y que falta, y puede instalarlo.

## Usuario final (recomendado)

1. Descarga el release / ejecuta el `.exe` portable de Companion (o `npm start` en desarrollo).
2. La app muestra el estado:
   - Python 3.10+
   - Runtime Pygenesis
   - Modelo GGUF (Hugging Face)
   - Aceleracion GPU (CUDA / Vulkan SDK / CPU)
   - Plugin Resolve Studio (opcional)
   - Puente localhost:8000
3. Pulsa **Instalar lo que falta** → **Arrancar puente** → **Continuar al chat**.
4. En Studio, el plugin sigue en `Workspace → Workflow Integrations → Pygenesis Resolve Tutor`.

**AMD:** sin Vulkan SDK completo el instalador usa **CPU** (no falla). El runtime VulkanRT no sirve; hace falta el SDK de LunarG + Build Tools (C++) para GPU.

El `.exe` empaqueta (via `extraResources`) `installer/`, `backend/` y `plugin/`, asi puede instalar sin clonar el repo.

## Desarrollo

```powershell
Set-Location companion\scripts
.\install_companion.ps1 -Dev
.\start_companion.ps1
```

O directamente:

```powershell
Set-Location companion\pygenesis-companion
npm install
npm start
```

## Build del .exe

```powershell
Set-Location companion\pygenesis-companion
npm install
npm run build
```

Si aparece un error de *symbolic link / winCodeSign*, ya esta mitigado en `package.json` (`signAndEditExecutable: false`). Alternativa del sistema: activar **Modo de desarrollador** en Windows.

Salida en `companion/dist/` (`Pygenesis-Companion-*-portable.exe` + `win-unpacked`).

Tambien: `installer\build_release.ps1` (incluye Companion en el ZIP de GitHub).

## Studio vs Free

| Edicion | Uso |
|---------|-----|
| **Resolve Studio** | Plugin integrado + esta app para setup/chat |
| **Resolve Free** | Solo Companion (contexto manual de pagina) |

## Estructura

```
companion/pygenesis-companion/
├── main.js / preload.js     # Electron + IPC setup
├── setup/                   # diagnostico + lanzador de install_pygenesis.ps1
├── js/setup-ui.js           # pantalla de instalacion
├── index.html               # setup + chat
└── ...
```
