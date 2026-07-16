# Pygenesis ResolveExpert AI

Asistente **DaVinci Resolve** para postproducción: dataset para fine-tuning, guías de entorno y pipeline de entrenamiento (mismo flujo que [Pygenesis AI](https://gitlab.com/SunoNavarro/pygenesis-ai), dominio distinto).

Proyecto **hermano** de Pygenesis AI (Unity): no comparte datos ni pesos del modelo Unity.

---

## Estructura

| Carpeta | Contenido |
|---------|-----------|
| [`training/`](training/) | Ingesta, sintético, Gemini, `process_dataset`, requirements |
| [`Fases/`](Fases/) | Guías por fases (entorno, dataset, fine-tuning) |
| [`Agentes/`](Agentes/) | Roles (editor, colorista, Fusion, Fairlight, Deliver) |
| [`conversion/`](conversion/) | Fusión LoRA + base Qwen |
| [`backend/`](backend/) | Puente de inferencia FastAPI (plugin → GGUF local con llama-cpp-python) |
| [`plugin/`](plugin/) | Workflow Integration Plugin para Resolve Studio |

---

## Inicio rápido

```powershell
Set-Location "C:\Users\navar\PycharmProjects\Pygenesis_ResolveExpert\training"
.\scripts\setup_env_windows.ps1
Copy-Item config\ollama.example.json config\ollama.json
.\scripts\run_synthetic_general.ps1 -Passes 1
```

Salida: `training/data/train/resolve_train.json` y `resolve_eval.json`.

Fine-tuning Colab/Ollama: [`guia_finetuning_resolve.md`](guia_finetuning_resolve.md).

---

## Documentación

| Recurso | Descripción |
|---------|-------------|
| [`PLANTILLA_PROYECTO_DAVINCI_RESOLVE.md`](PLANTILLA_PROYECTO_DAVINCI_RESOLVE.md) | Decisiones de arquitectura y reutilización |
| [`training/docs/ROADMAP_DATASET.md`](training/docs/ROADMAP_DATASET.md) | Fases del dataset |
| [`training/docs/ENTORNO_WINDOWS.md`](training/docs/ENTORNO_WINDOWS.md) | venv, Ollama, dependencias |

---

## Modelo Ollama

Tras entrenar y cuantizar:

```powershell
cd "C:\Users\navar\PycharmProjects\Pygenesis_ResolveExpert"
ollama create pygenesis-resolve -f Modelfile
```

Prueba: `python test_resolve.py`

---

## Plugin en Resolve Studio

```powershell
Set-Location "C:\Users\navar\PycharmProjects\Pygenesis_ResolveExpert\plugin\scripts"
.\install_plugin.ps1
```

Luego en Resolve: **Workspace → Workflow Integrations → Pygenesis Resolve Tutor**.

Guía: [`plugin/README.md`](plugin/README.md) · Roadmap: [`RoadmapCreacionPlugin.md`](RoadmapCreacionPlugin.md)
