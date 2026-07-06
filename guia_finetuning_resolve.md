# Guía completa de Fine-Tuning — Pygenesis ResolveExpert AI
### Qwen2.5-Coder-7B-Instruct + LoRA + GGUF + Ollama

---

## Índice

1. [Requisitos previos](#1-requisitos-previos)
2. [Preparar el dataset](#2-preparar-el-dataset)
3. [Opción A — Google Colab (recomendado)](#3-opción-a--google-colab-recomendado)
4. [Opción B — PC local en CPU (sin GPU)](#4-opción-b--pc-local-en-cpu-sin-gpu)
5. [Opción C — PC local con GPU externa NVIDIA](#5-opción-c--pc-local-con-gpu-externa-nvidia)
6. [Fusionar LoRA y convertir a GGUF (en tu PC)](#6-fusionar-lora-y-convertir-a-gguf-en-tu-pc)
7. [Registrar en Ollama](#7-registrar-en-ollama)
8. [Backend FastAPI con filtro de thinking](#8-backend-fastapi-con-filtro-de-thinking)
9. [Solución de errores frecuentes](#9-solución-de-errores-frecuentes)

---

## 1. Requisitos previos

### Hardware mínimo
| Opción | CPU | RAM | GPU |
|---|---|---|---|
| Google Colab gratuito | — | — | T4 15 GB (asignada por Colab) |
| PC local CPU | Ryzen 7 o similar | 32 GB | No necesaria |
| PC local GPU NVIDIA | Ryzen 7 o similar | 16 GB | RTX 3060 12 GB o superior |

### Software necesario en tu PC
- Python 3.11 (no usar 3.13)
- [Ollama](https://ollama.com/download) instalado
- [llama.cpp binarios Vulkan](https://github.com/ggerganov/llama.cpp/releases) descomprimidos en `C:\llama-bin\`
- Token de HuggingFace con permisos de lectura: [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens)

### Qué hace cada máquina (sin GPU local no pasa nada)

| Paso | Dónde | Necesita GPU |
|------|--------|--------------|
| Preparar dataset (`process_dataset.py`) | Tu PC | No |
| Fine-tune LoRA (celdas 0–8) | **Google Colab T4** | Sí |
| Fusionar LoRA + GGUF + Ollama | Tu PC (CPU/RAM) | No |
| Inferencia diaria | Tu PC (Ollama) | Opcional |

El entrenamiento **no** debe hacerse en tu portátil si no tienes VRAM suficiente. Colab asigna ~15 GB en T4; en PC solo subes los JSON y descargas el ZIP del adaptador (~100–150 MB).

### Estructura de archivos del dataset
```
training/
├── data/
│   ├── train/
│   │   └── resolve_train.json
│   └── eval/
│       └── resolve_eval.json
```

---

## 2. Preparar el dataset

### En tu PC (ya hecho si sigues el repo actual)

Desde la carpeta `training/`:

```powershell
python scripts/process_dataset.py
```

Eso genera o actualiza:

- `training/data/train/resolve_train.json` — **680** ejemplos (train)
- `training/data/eval/resolve_eval.json` — **121** ejemplos (eval)

Todos los `system` usan el mismo texto que el **Modelfile** de Ollama (`Pygenesis ResolveExpert AI`), no el prompt antiguo de “question/answer” del generador JSON. Eso evita que el modelo memorice frases del system al inferir.

Empaquetar para Colab (opcional):

```powershell
.\scripts\zip_colab_dataset.ps1
# → training/data/colab_dataset.zip
```

### Formato ShareGPT

```json
[
  {
    "conversations": [
      {
        "from": "system",
        "value": "Eres Pygenesis ResolveExpert AI, el asistente experto del plugin PyGenesis para Unity..."
      },
      {
        "from": "human",
        "value": "¿Cómo se usa proxies en DaVinci Resolve?"
      },
      {
        "from": "gpt",
        "value": "Rigidbody es un componente que permite física en Unity..."
      }
    ]
  }
]
```

Cada archivo JSON es un array con todas las conversaciones (~85% train / 15% eval).

---

## 3. Opción A — Google Colab (recomendado)

### Antes de empezar

1. Ve a [colab.research.google.com](https://colab.research.google.com) y crea un nuevo notebook
2. Cambia el runtime a GPU T4:
   ```
   Menú → Runtime → Change runtime type → T4 GPU → Save
   ```
3. Añade tu token de HuggingFace en Colab Secrets:
   ```
   Panel izquierdo → 🔑 Secrets → Add new secret
   Nombre: HF_TOKEN
   Valor: hf_xxxxxxxxxxxx
   Activar toggle "Notebook access"
   ```

---

### Celda 0 — Verificar GPU (ejecutar SIEMPRE primero)

```python
import torch

if torch.cuda.is_available():
    print(f"✅ GPU: {torch.cuda.get_device_name(0)}")
    print(f"   VRAM total: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")
else:
    print("❌ No hay GPU — cambia el runtime antes de continuar")
    raise SystemExit("Sin GPU no tiene sentido continuar")
```

**Si no hay GPU:** `Menú → Runtime → Disconnect and delete runtime` y volver a intentarlo.

---

### Celda 1 — Instalar dependencias con versiones fijas

```python
# Colab (Python 3.12) trae Triton nuevo que rompe bitsandbytes < 0.45.2 (error: No module named 'triton.ops').
# Usa estas versiones y, si la celda 2 falla, reinicia el runtime y repite desde la celda 0.

!pip install -q -U pip
!pip uninstall -y bitsandbytes 2>/dev/null || true

!pip install -q torch==2.4.1 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
!pip install -q transformers==4.47.0 peft==0.13.2 datasets trl==0.12.0 bitsandbytes==0.45.5 accelerate==1.2.1 sentencepiece

import bitsandbytes as bnb
import transformers
print(f"bitsandbytes {bnb.__version__} | transformers {transformers.__version__}")
```

> **Si ves `No module named 'triton.ops'` en la celda 2:**  
> `Runtime → Disconnect and delete runtime` → vuelve a ejecutar **celda 0 → celda 1 → celda 2** (sin saltar la 1).

---

### Celda 1b — Verificar bitsandbytes (opcional, antes de cargar el modelo)

```python
from transformers import BitsAndBytesConfig
import bitsandbytes as bnb
import torch

print("✅ bitsandbytes", bnb.__version__)
_ = BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_compute_dtype=torch.float16)
print("✅ BitsAndBytesConfig importado correctamente")
```

---

### Celda 2 — Cargar modelo Qwen2.5-Coder-7B

```python
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from google.colab import userdata

hf_token = userdata.get("HF_TOKEN")

model_name = "Qwen/Qwen2.5-Coder-7B-Instruct"

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.float16,
    bnb_4bit_use_double_quant=True,
)

tokenizer = AutoTokenizer.from_pretrained(
    model_name,
    trust_remote_code=True,
    token=hf_token
)

model = AutoModelForCausalLM.from_pretrained(
    model_name,
    quantization_config=bnb_config,
    device_map="auto",
    trust_remote_code=True,
    torch_dtype=torch.float16,
    token=hf_token
)

print(f"Modelo cargado en: {next(model.parameters()).device}")
```

> Para usar el modelo 3B (si la T4 no aguanta el 7B): cambiar a `Qwen/Qwen2.5-Coder-3B-Instruct`

---

### Celda 3 — Subir el dataset desde tu PC

Sube **desde tu repo** (tras `process_dataset.py`):

- `training/data/train/resolve_train.json`
- `training/data/eval/resolve_eval.json`

O el ZIP generado con `scripts/zip_colab_dataset.ps1` y descomprímelo en Colab:

```python
# Si subiste colab_dataset.zip:
!unzip -o colab_dataset.zip -d /content/dataset
# Ajusta rutas en la celda 4 si los JSON quedan en subcarpetas.
```

```python
from google.colab import files

print("Sube resolve_train.json y resolve_eval.json (o colab_dataset.zip antes de esta celda)")
uploaded = files.upload()
```

---

### Celda 4 — Cargar y formatear ambos datasets

```python
import json
from datasets import Dataset

# Token ChatML de Qwen (no copiar a mano; evita typos)
IM_END = "<|" + "im_end|>"

def load_and_format(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)

    def format_sharegpt(example):
        messages = example["conversations"]
        text = ""

        system = ""
        for msg in messages:
            if msg["from"] == "system":
                system = msg["value"]
                break

        if system:
            text += f"<|im_start|>system\n{system}{IM_END}\n"

        for msg in messages:
            if msg["from"] == "human":
                text += f"<|im_start|>user\n{msg['value']}{IM_END}\n"
            elif msg["from"] == "gpt":
                text += f"<|im_start|>assistant\n{msg['value']}{IM_END}\n"

        return {"text": text}

    return Dataset.from_list(data).map(format_sharegpt)

train_dataset = load_and_format("resolve_train.json")
eval_dataset  = load_and_format("resolve_eval.json")

print(f"Train: {len(train_dataset)} ejemplos")
print(f"Eval:  {len(eval_dataset)} ejemplos")
print("\nEjemplo formateado:")
print(train_dataset[0]["text"][:400])
```

---

### Celda 5 — Configurar LoRA

```python
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training

model = prepare_model_for_kbit_training(model, use_gradient_checkpointing=True)
model.config.use_cache = False  # obligatorio al entrenar; ahorra VRAM

lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                    "gate_proj", "up_proj", "down_proj"],
    lora_dropout=0.05,
    bias="none",
    task_type="CAUSAL_LM"
)

model = get_peft_model(model, lora_config)
model.print_trainable_parameters()
# Esperado: ~0.5% parámetros entrenables
```

---

### Celda 6 — Entrenar

```python
import gc
import os

import torch
from trl import SFTTrainer, SFTConfig

# Reduce fragmentación de VRAM en T4 (~15 GB)
os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

gc.collect()
torch.cuda.empty_cache()

# Con trl==0.12.x (celda 1) el parámetro es max_seq_length, NO max_length.
# max_seq_length=512 es el valor seguro para 7B en T4; 1024 suele dar CUDA OOM.
training_args = SFTConfig(
    output_dir="./qwen-coder-resolve",
    num_train_epochs=3,
    per_device_train_batch_size=1,
    per_device_eval_batch_size=1,
    gradient_accumulation_steps=8,
    learning_rate=2e-4,
    fp16=True,
    bf16=False,
    gradient_checkpointing=True,
    optim="adamw_bnb_8bit",
    dataloader_pin_memory=False,

    eval_strategy="steps",
    eval_steps=50,
    save_steps=50,
    load_best_model_at_end=True,
    metric_for_best_model="eval_loss",
    eval_accumulation_steps=4,

    logging_steps=10,
    warmup_steps=10,
    lr_scheduler_type="cosine",
    report_to="none",

    dataset_text_field="text",
    max_seq_length=512,
)

trainer = SFTTrainer(
    model=model,
    train_dataset=train_dataset,
    eval_dataset=eval_dataset,
    args=training_args,
    tokenizer=tokenizer,
)

trainer.train()
```

> **TRL ≥ 0.24:** si actualizas `trl` y falla `max_seq_length`, cámbialo por `max_length` y usa `processing_class=tokenizer` en lugar de `tokenizer=`.

> **Si sigue el OOM:** baja `max_seq_length` a `384`, o cambia en la celda 2 a `Qwen/Qwen2.5-Coder-3B-Instruct` y repite celdas 5–6.

**Tiempo estimado con T4 y ~800 ejemplos:**
| Modelo | Tiempo estimado |
|---|---|
| 3B | 60-90 minutos |
| 7B | 90-120 minutos |

Durante el entrenamiento verás el log así:
```
step 50  | train_loss: 1.42 | eval_loss: 1.38  ✅ mejorando
step 100 | train_loss: 1.18 | eval_loss: 1.21  ✅ mejorando
step 150 | train_loss: 0.95 | eval_loss: 1.19  ⚠️ posible sobreentrenamiento
```

---

### Celda 7 — Guardar adaptador LoRA

```python
model.save_pretrained("./qwen-coder-resolve-lora")
tokenizer.save_pretrained("./qwen-coder-resolve-lora")

print("Adaptador LoRA guardado en ./qwen-coder-resolve-lora")
```

---

### Celda 8 — Comprimir y descargar

```python
import shutil
from google.colab import files

shutil.make_archive("qwen-coder-resolve-lora", "zip", "./qwen-coder-resolve-lora")
files.download("qwen-coder-resolve-lora.zip")

print("Descarga iniciada — el archivo pesa ~100-150 MB")
```

---

## 4. Opción B — PC local en CPU (sin GPU)

Solo viable para modelos 3B o 4B. Muy lento (1-3 días para 680 ejemplos).

### Instalación

```powershell
# Python 3.11 recomendado
pip install llamafactory
pip uninstall -y torch torchvision torchaudio
pip install torch==2.2.2+cpu torchvision==0.17.2 torchaudio==2.2.2 --index-url https://download.pytorch.org/whl/cpu
```

### Lanzar interfaz web

```powershell
llamafactory-cli webui
```

### Configuración en la interfaz
- **Model**: `Qwen/Qwen2.5-Coder-3B-Instruct`
- **Method**: LoRA
- **Quantization**: 4-bit
- **Batch size**: 1
- **Gradient accumulation**: 16
- **Device**: CPU (automático)

---

## 5. Opción C — PC local con GPU externa NVIDIA

Esta es la opción más cómoda si tienes una GPU NVIDIA dedicada. Sin límites de tiempo de sesión, sin subir archivos, y el modelo queda directamente en tu PC. Se recomienda una RTX 3060 12 GB o superior para el modelo 7B.

### VRAM necesaria por modelo

| Modelo | VRAM mínima | VRAM recomendada |
|---|---|---|
| Qwen2.5-Coder-3B | 6 GB | 8 GB |
| Qwen2.5-Coder-7B | 10 GB | 12 GB |
| Qwen2.5-Coder-14B | 20 GB | 24 GB |

---

### Paso 1 — Instalar CUDA y dependencias

Asegúrate de tener instalado:
- [CUDA Toolkit 12.1 o superior](https://developer.nvidia.com/cuda-downloads)
- [cuDNN compatible con tu versión de CUDA](https://developer.nvidia.com/cudnn)

Verifica la instalación:
```powershell
nvidia-smi
nvcc --version
```

Instala las dependencias Python con soporte CUDA:
```powershell
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
pip install transformers peft datasets trl bitsandbytes accelerate
```

Verifica que PyTorch detecta la GPU:
```powershell
python -c "import torch; print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0))"
```

Debe mostrar `True` y el nombre de tu GPU.

---

### Paso 2 — Crear el script de entrenamiento

Guarda como `train_local.py` en la carpeta del proyecto:

```python
import torch
import json
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
from datasets import Dataset
from trl import SFTTrainer, SFTConfig

# ── Configuración ──────────────────────────────────────────
MODEL_NAME  = "Qwen/Qwen2.5-Coder-7B-Instruct"
TRAIN_FILE  = "training/data/train/resolve_train.json"
EVAL_FILE   = "training/data/eval/resolve_eval.json"
OUTPUT_DIR  = "./qwen-coder-resolve-lora"
HF_TOKEN    = "hf_xxxxxxxxxxxx"  # tu token de HuggingFace
# ───────────────────────────────────────────────────────────

# Verificar GPU
if not torch.cuda.is_available():
    raise SystemExit("❌ No se detecta GPU NVIDIA. Verifica la instalación de CUDA.")
print(f"✅ GPU: {torch.cuda.get_device_name(0)}")
print(f"   VRAM: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")

# Cargar modelo con cuantización 4-bit
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.float16,
    bnb_4bit_use_double_quant=True,
)

print("Cargando modelo...")
tokenizer = AutoTokenizer.from_pretrained(
    MODEL_NAME, trust_remote_code=True, token=HF_TOKEN
)
model = AutoModelForCausalLM.from_pretrained(
    MODEL_NAME,
    quantization_config=bnb_config,
    device_map="auto",
    trust_remote_code=True,
    torch_dtype=torch.float16,
    token=HF_TOKEN
)
print(f"Modelo cargado en: {next(model.parameters()).device}")

# Formatear dataset ShareGPT
def load_and_format(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)

    IM_END = "<|" + "im_end|>"

    def format_sharegpt(example):
        messages = example["conversations"]
        text = ""
        system = ""
        for msg in messages:
            if msg["from"] == "system":
                system = msg["value"]
                break
        if system:
            text += f"<|im_start|>system\n{system}{IM_END}\n"
        for msg in messages:
            if msg["from"] == "human":
                text += f"<|im_start|>user\n{msg['value']}{IM_END}\n"
            elif msg["from"] == "gpt":
                text += f"<|im_start|>assistant\n{msg['value']}{IM_END}\n"
        return {"text": text}

    return Dataset.from_list(data).map(format_sharegpt)

print("Cargando datasets...")
train_dataset = load_and_format(TRAIN_FILE)
eval_dataset  = load_and_format(EVAL_FILE)
print(f"Train: {len(train_dataset)} | Eval: {len(eval_dataset)}")

# Configurar LoRA
model = prepare_model_for_kbit_training(model)
lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                    "gate_proj", "up_proj", "down_proj"],
    lora_dropout=0.05,
    bias="none",
    task_type="CAUSAL_LM"
)
model = get_peft_model(model, lora_config)
model.print_trainable_parameters()

# Entrenar
training_args = SFTConfig(
    output_dir=OUTPUT_DIR,
    num_train_epochs=3,
    per_device_train_batch_size=2,
    gradient_accumulation_steps=4,
    learning_rate=2e-4,
    fp16=True,           # activar fp16 con GPU NVIDIA
    bf16=False,

    eval_strategy="steps",
    eval_steps=50,
    save_steps=50,
    load_best_model_at_end=True,
    metric_for_best_model="eval_loss",

    logging_steps=10,
    warmup_steps=10,
    lr_scheduler_type="cosine",
    report_to="none",

    dataset_text_field="text",
    max_seq_length=1024,
)

trainer = SFTTrainer(
    model=model,
    train_dataset=train_dataset,
    eval_dataset=eval_dataset,
    args=training_args,
    tokenizer=tokenizer,
)

print("Iniciando entrenamiento...")
trainer.train()

# Guardar adaptador
model.save_pretrained(OUTPUT_DIR)
tokenizer.save_pretrained(OUTPUT_DIR)
print(f"✅ Adaptador LoRA guardado en {OUTPUT_DIR}")
```

---

### Paso 3 — Ejecutar el entrenamiento

```powershell
python train_local.py
```

Verás el progreso en consola:
```
✅ GPU: NVIDIA GeForce RTX 3060
   VRAM: 12.0 GB
Train: 680 | Eval: 121
trainable params: 39,976,960 || all params: 7,661,011,968 || trainable%: 0.52
Iniciando entrenamiento...
step 10  | loss: 1.89
step 20  | loss: 1.65
...
```

**Tiempos estimados con GPU local:**

| GPU | Modelo 3B | Modelo 7B |
|---|---|---|
| RTX 3060 12 GB | ~20-30 min | ~45-60 min |
| RTX 3080 10 GB | ~15-20 min | ~35-45 min |
| RTX 3090 / 4090 24 GB | ~10-15 min | ~20-30 min |

---

### Paso 4 — El adaptador queda en local

A diferencia de Colab, no hay que descargar nada. El adaptador ya está en `./qwen-coder-resolve-lora` en tu PC. Continúa directamente con la sección de fusión (sección 6).

---

## 6. Fusionar LoRA y convertir a GGUF (en tu PC)

Estos pasos se ejecutan en tu PC **después de descargar el ZIP de Colab**. Usan **CPU y RAM** (~14 GB al fusionar el 7B), no la GPU integrada del portátil.

En este repo ya tienes `conversion/fusionar.py`; ajusta `lora_path` a donde descomprimiste el ZIP.

### Prerequisitos

```powershell
pip install transformers peft torch accelerate sentencepiece gguf protobuf
git clone https://github.com/ggerganov/llama.cpp.git
```

### Paso 1 — Descomprimir el adaptador

Descomprime `qwen-coder-resolve-lora.zip` en la carpeta del proyecto.

### Paso 2 — Script de fusión

Guarda como `fusionar.py`:

```python
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel

model_name = "Qwen/Qwen2.5-Coder-7B-Instruct"  # mismo modelo base usado en Colab
lora_path  = "./qwen-coder-resolve-lora"

print("Cargando modelo base en CPU (puede tardar varios minutos)...")
base_model = AutoModelForCausalLM.from_pretrained(
    model_name,
    torch_dtype=torch.float16,
    device_map="cpu",
    trust_remote_code=True
)

tokenizer = AutoTokenizer.from_pretrained(model_name, trust_remote_code=True)

print("Fusionando adaptador LoRA...")
merged = PeftModel.from_pretrained(base_model, lora_path)
merged = merged.merge_and_unload()
merged.save_pretrained("./qwen-coder-resolve-merged")
tokenizer.save_pretrained("./qwen-coder-resolve-merged")

print("✅ Listo en ./qwen-coder-resolve-merged")
```

```powershell
python fusionar.py
```

> Necesita ~14 GB de RAM. Con 32 GB va sobrado.

### Paso 3 — Convertir a GGUF f16

```powershell
python llama.cpp/convert_hf_to_gguf.py ./qwen-coder-resolve-merged --outfile ./qwen-coder-resolve-f16.gguf --outtype f16
```

### Paso 4 — Cuantizar a Q4_K_M

Requiere los binarios de llama.cpp con Vulkan descargados en `C:\llama-bin\`:
- Descargar: [llama-cpp releases](https://github.com/ggerganov/llama.cpp/releases) → `llama-*-bin-win-vulkan-x64.zip`

```powershell
C:\llama-bin\llama-quantize.exe ./qwen-coder-resolve-f16.gguf ./qwen-coder-resolve-q4km.gguf Q4_K_M
```

**Tamaños resultantes:**
| Formato | Tamaño aproximado |
|---|---|
| f16 (antes de cuantizar) | ~14 GB |
| q4_k_m (final) | ~4.5 GB |

---

## 7. Registrar en Ollama

Usa el **`Modelfile` de la raíz del repo** (ya alineado con el system del dataset y con `repeat_penalty` para reducir respuestas memorizadas). La línea `FROM` debe apuntar al GGUF cuantizado; **usa ruta relativa** (`./pygenesis-resolve-q4km.gguf`) si el proyecto está en una carpeta con espacios (p. ej. `Pygenesis ResolveExpert AI`), porque una ruta absoluta con espacios provoca `invalid model name`.

```powershell
cd "C:\Users\navar\PycharmProjects\Pygenesis ResolveExpert AI"
ollama create pygenesis-resolve -f Modelfile
ollama run pygenesis-resolve "¿Cómo configuro proxies en DaVinci Resolve?"
```

> El system del Modelfile debe ser el mismo que en `training/scripts/_resolve_system.py` y en los JSON de entrenamiento.

---

## 8. Backend FastAPI con filtros de respuesta

En el repo: carpeta **`backend/`** con `main.py` y `response_filters.py`.

Filtros aplicados tras cada respuesta de Ollama:
1. **Thinking** (por si cambias a un modelo con bloques de razonamiento).
2. **Citas `[Fuente: ...]` / `[Fuente manual: ...]`** — el dataset de manuales enseñó ese prefijo y el modelo a veces lo repite.

### Estructura del proyecto backend

```
backend/
├── main.py
├── response_filters.py   # limpiar_respuesta_modelo()
├── test_response_filters.py
├── indexar.py            # (opcional) copiar desde esta guía
├── conocimiento/
│   ├── resolve_train.json
│   └── resolve_eval.json
└── vectorstore/          # generado por indexar.py
```

### Instalar dependencias del backend

```powershell
pip install fastapi uvicorn httpx sentence-transformers faiss-cpu numpy
```

### indexar.py — Construir base de conocimiento RAG

```python
import json
import numpy as np
import faiss
import pickle
import os
from sentence_transformers import SentenceTransformer

print("Cargando modelo de embeddings...")
embedder = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")

fragmentos = []

for archivo in ["conocimiento/resolve_train.json", "conocimiento/resolve_eval.json"]:
    with open(archivo, "r", encoding="utf-8") as f:
        data = json.load(f)

    for ejemplo in data:
        mensajes = ejemplo["conversations"]
        pregunta = ""
        respuesta = ""

        for msg in mensajes:
            if msg["from"] == "human":
                pregunta = msg["value"]
            elif msg["from"] == "gpt":
                respuesta = msg["value"]

        if pregunta and respuesta:
            fragmentos.append({
                "pregunta": pregunta,
                "respuesta": respuesta,
            })

print(f"Total fragmentos: {len(fragmentos)}")

textos = [f["pregunta"] for f in fragmentos]
embeddings = embedder.encode(textos, show_progress_bar=True)
embeddings = np.array(embeddings).astype("float32")

indice = faiss.IndexFlatL2(embeddings.shape[1])
indice.add(embeddings)

os.makedirs("vectorstore", exist_ok=True)
faiss.write_index(indice, "vectorstore/indice.faiss")
with open("vectorstore/fragmentos.pkl", "wb") as f:
    pickle.dump(fragmentos, f)

print(f"✅ Base de conocimiento creada con {len(fragmentos)} fragmentos")
```

```powershell
python indexar.py
```

### main.py — Backend FastAPI completo

```python
import httpx
import numpy as np
import faiss
import pickle
import re
from fastapi import FastAPI
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer

app = FastAPI(title="Pygenesis ResolveExpert AI Backend")

OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL_NAME = "pygenesis-resolve"

print("Cargando base de conocimiento...")
embedder = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
indice   = faiss.read_index("vectorstore/indice.faiss")
with open("vectorstore/fragmentos.pkl", "rb") as f:
    fragmentos = pickle.load(f)
print(f"Base cargada: {len(fragmentos)} fragmentos")


class Consulta(BaseModel):
    prompt: str
    contexto_escena: str = ""
    modo_json: bool = False


def buscar_contexto(pregunta: str, top_k: int = 3) -> list:
    embedding = embedder.encode([pregunta]).astype("float32")
    distancias, indices = indice.search(embedding, top_k)
    resultados = []
    for i, idx in enumerate(indices[0]):
        if idx != -1 and distancias[0][i] < 2.0:
            resultados.append(fragmentos[idx])
    return resultados


from response_filters import limpiar_respuesta_modelo


def construir_prompt(consulta: Consulta, contexto_rag: list) -> str:
    system = """Eres Pygenesis ResolveExpert AI, asistente experto del DaVinci Resolve \(edición, Color, Fusion, Fairlight, Deliver\).

Responde en español salvo que pidan otro idioma. Usa JSON solo si lo piden explícitamente.
Da pasos y código C# cuando ayude. Si no sabes algo, dilo sin inventar.

No cites fuentes ni añadas prefijos tipo [Fuente: ...] o [Fuente manual: ...].
No añadas cierres tipo "En resumen" ni repitas tu rol."""

    prompt = f"<|im_start|>system\n{system}<|im_end|>\n"

    if consulta.contexto_escena:
        prompt += f"<|im_start|>system\nContexto del proyecto en Resolve:\n{consulta.contexto_escena}<|im_end|>\n"

    if contexto_rag:
        ejemplos = ""
        for i, frag in enumerate(contexto_rag):
            ejemplos += f"\nEjemplo {i+1}:\nPregunta: {frag['pregunta']}\nRespuesta: {frag['respuesta']}\n"
        prompt += f"<|im_start|>system\nEjemplos de referencia:\n{ejemplos}<|im_end|>\n"

    prompt += f"<|im_start|>user\n{consulta.prompt}<|im_end|>\n"
    prompt += "<|im_start|>assistant\n"

    return prompt


@app.post("/consultar")
async def consultar(consulta: Consulta):
    contexto_rag    = buscar_contexto(consulta.prompt, top_k=3)
    prompt_completo = construir_prompt(consulta, contexto_rag)

    async with httpx.AsyncClient(timeout=120) as client:
        response = await client.post(OLLAMA_URL, json={
            "model":  MODEL_NAME,
            "prompt": prompt_completo,
            "stream": False,
            "raw":    True,
            "options": {
                "temperature":      0.1 if consulta.modo_json else 0.2,
                "top_p":            0.95,
                "top_k":            20,
                "presence_penalty": 1.5,
                "stop": ["<|im_end|>", "<|im_start|>"]
            }
        })

        data         = response.json()
        texto        = data.get("response", "")
        texto_limpio = limpiar_respuesta_modelo(texto)

        return {
            "respuesta":         texto_limpio,
            "fragmentos_usados": len(contexto_rag)
        }


@app.get("/health")
async def health():
    return {
        "status":     "ok",
        "modelo":     MODEL_NAME,
        "fragmentos": len(fragmentos)
    }
```

### response_filters.py (resumen)

```python
from response_filters import limpiar_respuesta_modelo

# Quita [Fuente: ...], [Fuente manual: ...txt] al inicio y bloques thinking
respuesta_final = limpiar_respuesta_modelo(respuesta_de_ollama)
```

### Arrancar el backend

```powershell
cd backend
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Probar desde PowerShell

```powershell
# Consulta simple
$body = '{"prompt":"¿Cómo se usa proxies en DaVinci Resolve?"}'
Invoke-RestMethod -Uri "http://localhost:8000/consultar" -Method Post -Body $body -ContentType "application/json"

# Health check
Invoke-RestMethod -Uri "http://localhost:8000/health"

# Con contexto de escena
$body = '{"prompt":"¿Cómo optimizo este objeto?","contexto_escena":"{\"nombre\":\"Player\",\"componentes\":[\"Rigidbody\",\"BoxCollider\"]}"}'
Invoke-RestMethod -Uri "http://localhost:8000/consultar" -Method Post -Body $body -ContentType "application/json"
```

---

## 9. Solución de errores frecuentes

### ❌ `no accelerator is found` — entrenando en CPU
**Causa:** Colab no asignó GPU.
```
Menú → Runtime → Change runtime type → T4 GPU
Menú → Runtime → Disconnect and delete runtime
```
Verificar siempre con la celda 0 antes de continuar.

### ❌ Kernel se reinicia al cargar el modelo
**Causa:** Sin GPU o VRAM insuficiente para el modelo elegido.
- Con T4 (15 GB): usar 7B
- Sin GPU asignada: usar 3B o esperar a tener T4

### ❌ `CUDA out of memory` durante `trainer.train()` (celda 6)
**Causa:** T4 (~15 GB) se queda sin VRAM con Qwen 7B si `max_seq_length` es alto (p. ej. 1024) o el optimizador no está en 8-bit.

**Solución (en orden):**
1. Usa la **celda 6 actualizada** (`max_seq_length=512`, `optim="adamw_bnb_8bit"`, `per_device_eval_batch_size=1`).
2. En la **celda 5**, confirma `use_gradient_checkpointing=True` y `model.config.use_cache = False`.
3. **Reinicia runtime** y ejecuta solo: celda 0 → 1 → 2 → 4 → 5 → 6 (no re-ejecutes celdas sueltas que dejen tensores viejos en GPU).
4. Si persiste: `max_seq_length=384` o desactiva eval en caliente:
   ```python
   eval_strategy="no",
   load_best_model_at_end=False,
   ```
5. Último recurso en celda 2: `Qwen/Qwen2.5-Coder-3B-Instruct`.

### ❌ `evaluation_strategy` unexpected keyword
**Causa:** Versión nueva de transformers.
**Solución:** Cambiar `evaluation_strategy` por `eval_strategy`.

### ❌ `dataset_text_field` unexpected keyword en SFTTrainer
**Causa:** Versión nueva de TRL (≥ 0.13).
**Solución:** Mover `dataset_text_field` y `max_seq_length` (o `max_length`) dentro de `SFTConfig`, no en `SFTTrainer`.

### ❌ `max_length` unexpected keyword en SFTConfig (celda 6)
**Causa:** Con **`trl==0.12.x`** (celda 1 de esta guía) el parámetro se llama **`max_seq_length`**, no `max_length`.
**Solución:** Usar la celda 6 actualizada de esta guía (`max_seq_length=1024`).

### ❌ `max_seq_length` unexpected keyword en SFTConfig
**Causa:** TRL muy reciente (≥ 0.24) renombró el parámetro.
**Solución:** Cambiar `max_seq_length` por `max_length` y `tokenizer=` por `processing_class=tokenizer` en `SFTTrainer`.

### ❌ `module 'triton.backends' has no attribute 'compiler'`
**Causa:** Conflicto de versiones tras cambiar runtime.
**Solución:** Usar la celda 1 con versiones fijas explícitas y reiniciar el runtime.

### ❌ `No module named 'triton.ops'` al cargar el modelo (celda 2)
**Causa:** Colab trae Triton ≥ 3.2; `bitsandbytes==0.44.0` (u otras versiones viejas) importan `triton.ops`, que ya no existe.

**Solución (en orden):**
1. Ejecutar la **celda 1 actualizada** (`bitsandbytes==0.45.5`, `torch==2.4.1`).
2. `Runtime → Disconnect and delete runtime` y repetir **celda 0 → 1 → 2**.
3. Si persiste, en una celda nueva antes de la 2:
   ```python
   !pip install -q --force-reinstall bitsandbytes==0.45.5
   ```
   Reinicia runtime y vuelve a la celda 0.

### ❌ `No module named 'sentencepiece'`
**Causa:** Falta la librería para el tokenizador.
```powershell
pip install sentencepiece
```

### ❌ `invalid choice: q4_k_m` en convert_hf_to_gguf.py
**Causa:** El script solo convierte formato, no cuantiza.
**Solución:** Convertir a f16 primero, luego cuantizar con `llama-quantize.exe`.

### ❌ `Error: no FROM line` en Ollama
**Causa:** El Modelfile tiene extensión oculta (.txt) o está vacío.
```powershell
dir Modelfile*          # verificar nombre
Get-Content Modelfile   # verificar contenido
notepad Modelfile       # editar si hace falta
```

### ❌ `400 Bad Request: invalid model name` en `ollama create`
**Causa habitual:** la línea `FROM` del Modelfile usa una **ruta absoluta con espacios** (p. ej. `.../Pygenesis ResolveExpert AI/archivo.gguf`). Ollama corta la ruta en el espacio y falla al resolver el GGUF.

**Solución:**
1. Ejecutar desde la carpeta del repo: `cd "...\Pygenesis ResolveExpert AI"`.
2. En el Modelfile usar ruta relativa: `FROM ./pygenesis-resolve-q4km.gguf`.
3. Volver a crear: `ollama create pygenesis-resolve -f Modelfile`.

### ❌ Respuesta en bucle infinito en Ollama
**Causa:** Template incorrecto en el Modelfile.
**Solución:** Usar el template ChatML con tokens de stop:
```
PARAMETER stop "<|im_end|>"
PARAMETER stop "<|im_start|>"
```

### ❌ Modo thinking visible en las respuestas (solo Qwen3)
**Causa:** Qwen3 tiene thinking integrado en los pesos.
**Solución en FastAPI:**
```python
import re

def filtrar_thinking(texto: str) -> str:
    texto = re.sub(r"<think>.*?</think>", "", texto, flags=re.DOTALL)
    if "</think>" in texto:
        texto = texto.split("</think>")[-1]
    return texto.strip()
```

---

## Flujo completo resumido

```
0. PC: process_dataset.py → resolve_train.json + resolve_eval.json (PYgenesis system)
        ↓
1. Colab: subir JSON → entrenar LoRA con GPU T4 (~90–120 min, 7B)
        ↓
2. Descargar adaptador LoRA (~100 MB)
        ↓
3. PC (CPU/RAM): fusionar LoRA (conversion/fusionar.py o fusionar.py de la guía)
        ↓
4. PC: convertir a GGUF f16 (convert_hf_to_gguf.py)
        ↓
5. PC: cuantizar a Q4_K_M (llama-quantize.exe)
        ↓
6. PC: ollama create pygenesis-coder -f Modelfile
        ↓
7. (Opcional) backend FastAPI con RAG
        ↓
8. Plugin Unity → consulta al modelo
```

---

*Documento generado para el proyecto Pygenesis ResolveExpert AI — Mayo 2026*
