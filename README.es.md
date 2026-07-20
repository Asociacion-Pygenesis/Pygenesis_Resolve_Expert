# Pygenesis ResolveExpert

Local AI assistant for **DaVinci Resolve** (Edit, Color, Fusion, Fairlight, Deliver).

| Edition | How you use it |
|---------|----------------|
| **Resolve Studio** | In-app plugin: `Workspace → Workflow Integrations → Pygenesis Resolve Tutor` |
| **Resolve Free** | [Pygenesis Companion](companion/README.md) (floating chat app) |

**Español:** see the Spanish sections below and [`installer/README.md`](installer/README.md).

---

## Quick start

**Requirements:** Windows 10/11, [Python 3.10+](https://www.python.org/downloads/) on PATH, internet (first model download).

1. Download **Pygenesis Companion** from [GitHub Releases](https://github.com/Asociacion-Pygenesis/Pygenesis_Resolve_Expert/releases) (or run from this repo).
2. Click **Install what's missing**.
3. **Start bridge** → **Continue to chat**.

GGUF weights: [`SuNavar/Pygenesis_ResolveExpert`](https://huggingface.co/SuNavar/Pygenesis_ResolveExpert)

### GPU acceleration

| Hardware | Installer behavior |
|----------|-------------------|
| **NVIDIA** | CUDA wheels (no local compile in most cases). |
| **AMD Radeon** | GPU/Vulkan **only** with full [LunarG Vulkan SDK](https://vulkan.lunarg.com/sdk/home) (*SDK Installer*, **not** VulkanRT alone) + VS Build Tools (C++). Without SDK → **automatic CPU** (slower, but works). |
| No discrete GPU | CPU. |

---

## Español — inicio rapido

1. Abre Companion (`.exe` o `npm start`).
2. **Instalar lo que falta** → **Arrancar puente** → chat.
3. **AMD sin Vulkan SDK:** la instalacion continua en **CPU** (no es un error). Para GPU AMD: SDK LunarG + Build Tools.

Modelo: [`SuNavar/Pygenesis_ResolveExpert`](https://huggingface.co/SuNavar/Pygenesis_ResolveExpert)

Licencia [Apache-2.0](LICENSE) (si esta presente en el repo).
