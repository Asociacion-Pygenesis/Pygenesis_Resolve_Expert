# Pygenesis ResolveExpert AI

Asistente **DaVinci Resolve** para postproducción: plugin Studio, Companion (Free) y modelo GGUF local.

Modelo en Hugging Face: [`SuNavar/Pygenesis_ResolveExpert`](https://huggingface.co/SuNavar/Pygenesis_ResolveExpert).

---

## Instalación (usuario)

Requisitos: Windows 10/11, Python 3.10+ en PATH, Internet (descarga del GGUF).

1. Abre **Pygenesis Companion** (`.exe` del release o `npm start` en desarrollo).
2. La app indica que falta e **Instalar lo que falta** (modelo desde Hugging Face, runtime, plugin).
3. Arranca el puente desde la misma pantalla y entra al chat.
4. **Studio:** `Workspace → Workflow Integrations → Pygenesis Resolve Tutor`  
   **Free:** usa el chat de Companion (contexto manual).

Alternativa sin GUI: doble clic en [`Install.bat`](Install.bat).

Guía: [`installer/README.md`](installer/README.md) · Companion: [`companion/README.md`](companion/README.md).

---

## Estructura

| Carpeta | Contenido |
|---------|-----------|
| [`installer/`](installer/) | Instalador cerrado (`Install.bat`), fuente HF, `build_release.ps1` |
| [`backend/`](backend/) | Puente FastAPI + `llama-cpp-python` (GGUF) |
| [`plugin/`](plugin/) | Workflow Integration Plugin (Resolve Studio) |
| [`companion/`](companion/) | Pygenesis Companion (Resolve Free / Electron) |
| [`training/`](training/) | Dataset y pipeline de entrenamiento (solo desarrollo) |
| [`conversion/`](conversion/) | Fusión LoRA → GGUF (solo desarrollo) |
| [`Fases/`](Fases/) / [`Agentes/`](Agentes/) | Guías y roles de dominio |

---

## Desarrollo

```powershell
Set-Location training
.\scripts\setup_env_windows.ps1
```

Fine-tuning: [`guia_finetuning_resolve.md`](guia_finetuning_resolve.md).

Instalación en modo desarrollo (sin ZIP):

```powershell
.\installer\install_pygenesis.ps1
# o
.\Install.bat
```

Generar paquete para GitHub Releases:

```powershell
.\installer\build_release.ps1
```

---

## Documentación

| Recurso | Descripción |
|---------|-------------|
| [`installer/README.md`](installer/README.md) | Instalación end-user y build de release |
| [`plugin/README.md`](plugin/README.md) | Plugin Studio |
| [`companion/README.md`](companion/README.md) | Companion Free |
| [`RoadmapCreacionPlugin.md`](RoadmapCreacionPlugin.md) | Roadmap del plugin |
| [`HUGGINGFACE_MODEL_DESCRIPTION.md`](HUGGINGFACE_MODEL_DESCRIPTION.md) | Model card (HF) |
