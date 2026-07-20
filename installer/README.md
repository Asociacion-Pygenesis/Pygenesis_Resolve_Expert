# Instalación (usuario final)

Instalador cerrado de **Pygenesis ResolveExpert** para Windows. El modelo GGUF se descarga desde Hugging Face en el momento de la instalación; no viaja en el ZIP de GitHub.

## Requisitos

- Windows 10/11
- [Python 3.10+](https://www.python.org/downloads/) en PATH (marca *Add python.exe to PATH*)
- Conexión a Internet (descarga del modelo `pygenesis-resolve-q4km.gguf`)
- DaVinci Resolve Studio (plugin) y/o Free (Companion)

### GPU (opcional)

| Hardware | Que hace el instalador |
|----------|------------------------|
| **NVIDIA** | CUDA (wheels). Suele ir bien sin compilar. |
| **AMD** | Vulkan/GPU **solo** con [Vulkan SDK](https://vulkan.lunarg.com/sdk/home) completo (SDK Installer, **no** solo VulkanRT) + Visual Studio Build Tools (C++). Sin eso → **CPU automatico** (mas lento, pero usable). |
| Sin GPU | CPU. |

No hace falta instalar el Vulkan SDK para usar Pygenesis: en portatiles AMD sin SDK la instalacion continua en CPU.

## Instalacion en 1 clic (Companion .exe)

La forma recomendada es abrir **Pygenesis Companion**: la propia app muestra que componentes tienes y cuales faltan, e instala lo pendiente (runtime, modelo HF, plugin).

1. Ejecuta el `.exe` portable (o `companion\scripts\start_companion.ps1` en desarrollo).
2. Pulsa **Instalar lo que falta**.
3. **Arrancar puente** → **Continuar al chat**.

## Instalacion clasica (Install.bat)

1. Descarga el ZIP desde **GitHub Releases** (o clona el repo de distribución).
2. Descomprime la carpeta.
3. Doble clic en **`Install.bat`** (raíz del paquete o `installer\Install.bat`).
4. Espera a que termine (GPU + modelo + plugin + Companion). La descarga del modelo puede tardar varios minutos.

Al finalizar encontrarás atajos en el menú Inicio → **Pygenesis**:

| Atajo | Uso |
|-------|-----|
| **Pygenesis Backend** | Arranca el puente local (`http://127.0.0.1:8000`) |
| **Pygenesis Companion** | App para Resolve Free |

## Uso

1. Arranca **Pygenesis Backend** y déjalo abierto.
2. **Resolve Studio:** `Workspace → Workflow Integrations → Pygenesis Resolve Tutor`
3. **Resolve Free:** abre **Pygenesis Companion**

## Qué se instala y dónde

| Componente | Ubicación |
|------------|-----------|
| Runtime Python | `%LOCALAPPDATA%\Pygenesis\runtime\` |
| Backend (copia) | `%LOCALAPPDATA%\Pygenesis\app\backend\` |
| Modelo GGUF | `%LOCALAPPDATA%\Pygenesis\models\` |
| Companion | `%LOCALAPPDATA%\Pygenesis\companion\` |
| Config | `%LOCALAPPDATA%\Pygenesis\bridge.env` |
| Plugin Studio | `%ProgramData%\Blackmagic Design\DaVinci Resolve\Support\Workflow Integration Plugins\` |

Fuente del modelo: [`SuNavar/Pygenesis_ResolveExpert`](https://huggingface.co/SuNavar/Pygenesis_ResolveExpert) (ver `installer/model.source.json`).

## Opciones avanzadas

Desde PowerShell, en la carpeta `installer`:

```powershell
.\install_pygenesis.ps1
.\install_pygenesis.ps1 -Backend cuda
.\install_pygenesis.ps1 -SkipModelDownload   # si el GGUF ya está en models\
.\install_pygenesis.ps1 -SkipCompanion
.\install_pygenesis.ps1 -SkipPlugin
```

## Generar el ZIP de release (desarrolladores)

En una máquina de build con Node.js y Python:

```powershell
Set-Location installer
.\build_release.ps1
```

Salida:

- `dist/PygenesisResolveExpert/` — carpeta lista para distribuir
- `dist/PygenesisResolveExpert-<version>-windows.zip` — artefacto para GitHub Releases

El GGUF **no** se incluye en el ZIP.
