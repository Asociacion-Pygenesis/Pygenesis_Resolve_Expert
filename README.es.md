# Pygenesis ResolveExpert

Asistente de IA **local** para **DaVinci Resolve** (Edit, Color, Fusion, Fairlight, Deliver).

| Edición | Cómo se usa |
|---------|-------------|
| **Resolve Studio** | Plugin integrado: `Workspace → Workflow Integrations → Pygenesis Resolve Tutor` |
| **Resolve Free** | [Pygenesis Companion](companion/README.md) (ventana de chat flotante) |

El modelo es el mismo en ambos casos. En Studio el contexto (página/proyecto/timeline) puede enviarse automáticamente; en Free se indica a mano en Companion.

**English:** [README.md](README.md)

---

## Inicio rápido (usuarios)

**Requisitos:** Windows 10/11, [Python 3.10–3.12](https://www.python.org/downloads/) en PATH (recomendado **3.12**; evita 3.13/3.14), Internet (primera descarga del modelo).

1. Descarga **Pygenesis Companion** desde [GitHub Releases](https://github.com/Asociacion-Pygenesis/Pygenesis_Resolve_Expert/releases).
2. Ejecuta el `.exe` portable.
3. Pulsa **Instalar lo que falta** (runtime, GGUF desde Hugging Face, plugin Studio).
4. **Arrancar puente** → **Continuar al chat**.

Los pesos GGUF **no** están en este repositorio. Se descargan desde Hugging Face:

[`SuNavar/Pygenesis_ResolveExpert`](https://huggingface.co/SuNavar/Pygenesis_ResolveExpert)

Alternativa sin interfaz: clona el repo y ejecuta [`Install.bat`](Install.bat).

### GPU / aceleración

| Hardware | Comportamiento del instalador |
|----------|-------------------------------|
| **NVIDIA** | CUDA (wheels). |
| **AMD Radeon** | GPU/Vulkan **solo** con [Vulkan SDK](https://vulkan.lunarg.com/sdk/home) completo (SDK Installer, **no** solo VulkanRT) + VS Build Tools (C++). Sin SDK → **CPU automático**. Si el SDK está instalado pero falla el build (rutas largas / MAX_PATH), también cae a CPU. Usa TEMP corto `C:\pgbuild`. |
| Sin GPU dedicada | CPU. |

---

## Estructura del repositorio

| Ruta | Rol |
|------|-----|
| [`installer/`](installer/) | Instalador cerrado (`Install.bat`), fuente HF, scripts de release |
| [`backend/`](backend/) | Puente FastAPI local + `llama-cpp-python` (GGUF) |
| [`plugin/`](plugin/) | Plugin Workflow Integration (Resolve Studio) |
| [`companion/`](companion/) | Companion Electron + asistente de instalación |
| [`training/`](training/) | Dataset / fine-tuning (solo desarrollo) |
| [`conversion/`](conversion/) | LoRA → GGUF (solo desarrollo) |

---

## Desarrolladores

```powershell
Set-Location training
.\scripts\setup_env_windows.ps1

.\Install.bat

Set-Location companion\pygenesis-companion
npm install
npm start
npm run build
```

---

## Privacidad y licencia

La inferencia corre **en tu máquina**. Licencia [Apache-2.0](LICENSE).

---

## Enlaces

- Modelo: [Hugging Face — SuNavar/Pygenesis_ResolveExpert](https://huggingface.co/SuNavar/Pygenesis_ResolveExpert)
- Releases: [GitHub Releases](https://github.com/Asociacion-Pygenesis/Pygenesis_Resolve_Expert/releases)
- Asociación: [Asociacion-Pygenesis](https://github.com/Asociacion-Pygenesis)
