# Entorno de entrenamiento en Windows (sin WSL)

La Fase 0 del repo (`Fases/fase0_preparar_entorno.md`) está orientada a Linux + ROCm. En **Windows** usamos PyTorch oficial (CPU o **CUDA NVIDIA**). La GPU integrada **AMD Radeon 680M no tiene soporte de entrenamiento PyTorch** equivalente al de ROCm en Linux; para fine-tuning pesado conviene **GPU NVIDIA local** o **CPU** (muy lento) / **nube con GPU**.

## 1. Requisitos

- **Windows 10/11** actualizado.
- **Python 3.11 o 3.12** desde [python.org](https://www.python.org/downloads/) (marca “Add python.exe to PATH”) o `winget install Python.Python.3.12`.
- **Git** (opcional, para Hugging Face / clones).

## 2. Entorno virtual del proyecto

En PowerShell:

```powershell
Set-Location "C:\Users\navar\PycharmProjects\Pygenesis AI\training"
.\scripts\setup_env_windows.ps1
```

- Por defecto instala **PyTorch CPU** (funciona en cualquier máquina).
- Si tienes **NVIDIA** y quieres CUDA 12.4:

```powershell
.\scripts\setup_env_windows.ps1 -TorchFlavor Cuda124
```

Activa el venv siempre que trabajes en dataset o scripts:

```powershell
Set-Location "C:\Users\navar\PycharmProjects\Pygenesis AI\training"
.\.venv\Scripts\Activate.ps1
```

Si PowerShell bloquea scripts: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

## 3. Verificación

```powershell
python scripts\verify_env_windows.py
```

Debes ver la versión de `torch` y si `cuda` está disponible (solo true con build CUDA + driver NVIDIA).

## 4. Ollama en Windows (inferencia y datos sintéticos)

1. Descarga e instala desde [ollama.com/download/windows](https://ollama.com/download/windows).
2. Modelo recomendado en Fase 1: `ollama pull qwen2.5-coder:7b-instruct-q4_K_M` (si usas otro, configúralo en `config/ollama.json`; plantilla: `config/ollama.example.json`).
3. Comprueba: `ollama run <nombre-modelo> "hola"`.

Los scripts de generación sintética llamarán a `http://127.0.0.1:11434` (equivalente a `localhost`).

### Qwen 3 y latencia (“Thinking…”)

Los modelos **Qwen 3** en Ollama pueden usar [modo thinking](https://ollama.com/blog/thinking): más tokens antes de la respuesta útil y sensación de “muchas vueltas”.

- **CLI:** `ollama run qwen3.5:4B --think=false "tu prompt"` o, en chat interactivo, `/set nothink`.
- **API** (`/api/generate`, `/api/chat`): envía `"think": false` en el JSON (es lo que usa `scripts/ollama_smoke_test.py` y `config/ollama.example.json`).

Para **`pygenesis-ai`**: si está basado en Qwen 3, conviene el mismo `think: false` en las llamadas HTTP del plugin; si el rollo largo viene del **SYSTEM** (instrucciones que obligan a razonar en voz alta), acorta ese SYSTEM o pide respuestas mínimas en los prompts de análisis.

**Backend Pygenesis (Unity):** si `PYGENESIS_LLM_BASE_URL` apunta a Ollama (`…:11434/v1`), el cliente OpenAI-compatible envía por defecto **`reasoning_effort: "none"`** en el cuerpo de `chat/completions` (menos latencia en Qwen 3). Ajuste opcional: variable `PYGENESIS_OLLAMA_REASONING_EFFORT` (documentada en `Tools/pygenesis_backend/README.md` y `.env.example` del plugin).

## 5. Hugging Face (opcional)

```powershell
pip install huggingface_hub
huggingface-cli login
```

## 6. Unsloth y Fase 2 en Windows

Unsloth optimiza entrenamiento en GPU **NVIDIA**; en **solo CPU** no aplica igual. Opciones:

- **NVIDIA + CUDA**: prueba `pip install unsloth` tras el entorno CUDA; si falla, usa **PEFT + Transformers** sin Unsloth (más lento pero estándar).
- **Solo CPU / solo AMD iGPU**: usa este venv para **dataset, evaluación ligera y export vía otras herramientas**; planifica entrenamiento LoRA en una máquina con NVIDIA o servicio cloud.

## 7. Rutas del plugin

Copia `config\paths.example.json` a `config\paths.json` y revisa `pygenesis_plugin_root`.

## 8. Variables de entorno (Linux → no aplican aquí)

No uses `HSA_OVERRIDE_GFX_VERSION` ni `ROCR_VISIBLE_DEVICES`; son solo para ROCm en Linux.
