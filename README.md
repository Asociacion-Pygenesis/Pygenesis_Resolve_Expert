# Pygenesis ResolveExpert

Local AI assistant for **DaVinci Resolve** (Edit, Color, Fusion, Fairlight, Deliver).

| Edition | How you use it |
|---------|----------------|
| **Resolve Studio** | In-app plugin: `Workspace → Workflow Integrations → Pygenesis Resolve Tutor` |
| **Resolve Free** | [Pygenesis Companion](companion/README.md) (floating chat app) |

Same model in both cases. Studio can pass page/project/timeline context automatically; Free uses manual context in Companion.

**Español:** [README.es.md](README.es.md)

---

## Quick start (end users)

**Requirements:** Windows 10/11, [Python 3.10+](https://www.python.org/downloads/) on PATH, internet (first model download).

1. Download **Pygenesis Companion** from [GitHub Releases](https://github.com/Asociacion-Pygenesis/Pygenesis_Resolve_Expert/releases).
2. Run the portable `.exe`.
3. Click **Install what’s missing** (runtime, GGUF from Hugging Face, Studio plugin).
4. **Start bridge** → **Continue to chat**.

The GGUF weights are **not** in this repo. They download from Hugging Face:

[`SuNavar/Pygenesis_ResolveExpert`](https://huggingface.co/SuNavar/Pygenesis_ResolveExpert)

Alternative (no GUI): clone this repo and run [`Install.bat`](Install.bat).

### GPU acceleration

| Hardware | Installer behavior |
|----------|-------------------|
| **NVIDIA** | CUDA wheels (usually no local compile). |
| **AMD Radeon** | GPU/Vulkan **only** with full [LunarG Vulkan SDK](https://vulkan.lunarg.com/sdk/home) (*SDK Installer*, **not** VulkanRT alone) + VS Build Tools (C++). Without SDK → **automatic CPU** (slower, but works). |
| No discrete GPU | CPU. |

Guide: [`installer/README.md`](installer/README.md) · Companion: [`companion/README.md`](companion/README.md).

---

## Repository layout

| Path | Role |
|------|------|
| [`installer/`](installer/) | Closed installer (`Install.bat`), HF model source, release scripts |
| [`backend/`](backend/) | Local FastAPI bridge + `llama-cpp-python` (GGUF) |
| [`plugin/`](plugin/) | Workflow Integration plugin (Resolve Studio) |
| [`companion/`](companion/) | Electron Companion + setup wizard |
| [`training/`](training/) | Dataset / fine-tuning (developers only) |
| [`conversion/`](conversion/) | LoRA → GGUF (developers only) |

---

## Developers

```powershell
# Optional: training venv
Set-Location training
.\scripts\setup_env_windows.ps1

# Install runtime + model + plugin from sources
.\Install.bat

# Companion in dev mode
Set-Location companion\pygenesis-companion
npm install
npm start

# Build portable .exe
npm run build
```

Release packaging: [`installer/build_release.ps1`](installer/build_release.ps1) · publish helpers: [`installer/publish_release.ps1`](installer/publish_release.ps1)

---

## Privacy & license

Inference runs **on your machine**. No cloud chat API is required beyond downloading the model once.

Licensed under [Apache-2.0](LICENSE).

---

## Links

- Model: [Hugging Face — SuNavar/Pygenesis_ResolveExpert](https://huggingface.co/SuNavar/Pygenesis_ResolveExpert)
- Releases: [GitHub Releases](https://github.com/Asociacion-Pygenesis/Pygenesis_Resolve_Expert/releases)
- Association: [Asociacion-Pygenesis](https://github.com/Asociacion-Pygenesis)
