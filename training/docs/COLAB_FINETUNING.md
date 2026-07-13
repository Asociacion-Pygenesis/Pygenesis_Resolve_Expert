# Fine-tuning en Google Colab — Pygenesis ResolveExpert AI

Guía paso a paso para copiar y pegar **una celda cada vez** en [Google Colab](https://colab.research.google.com).

**Modelo base:** `Qwen/Qwen2.5-Coder-7B-Instruct` (QLoRA 4-bit)  
**Dataset actual:** 1.227 train · 217 eval · system alineado con `Modelfile`  
**Salida:** adaptador LoRA `qwen-coder-resolve-lora.zip` (~100–150 MB)

---

## Antes de abrir Colab

### En tu PC

```powershell
Set-Location "C:\Users\navar\PycharmProjects\Pygenesis_ResolveExpert\training"
python scripts\process_dataset.py
.\scripts\zip_colab_dataset.ps1
# → training\data\colab_dataset.zip
```

Sube a Colab el archivo **`colab_dataset.zip`** (contiene `resolve_train.json` y `resolve_eval.json`).

### En Hugging Face

1. Crea un token de lectura: [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens)
2. Acepta la licencia de [Qwen2.5-Coder-7B-Instruct](https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct) (o 3B si la T4 no aguanta el 7B)

### En Colab

1. **Nuevo notebook** → menú **Runtime → Change runtime type → T4 GPU → Save**
2. Panel **Secrets** (🔑) → nuevo secreto:
   - **Nombre:** `HF_TOKEN`
   - **Valor:** `hf_xxxxxxxxxxxx`
   - Activar **Notebook access**

---

## Celda 0 — Verificar GPU

> Tipo de celda: **Código**. Ejecutar **siempre primero**.

```python
import torch

if torch.cuda.is_available():
    print(f"✅ GPU: {torch.cuda.get_device_name(0)}")
    print(f"   VRAM total: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")
else:
    print("❌ No hay GPU — cambia el runtime antes de continuar")
    raise SystemExit("Sin GPU no tiene sentido continuar")
```

**Si no hay GPU:** `Runtime → Disconnect and delete runtime` y vuelve a intentarlo.

---

## Celda 1 — Instalar dependencias (versiones fijas)

> Tipo de celda: **Código**. **No importes nada al final.** Tras ejecutarla, **reinicia el runtime** (obligatorio).

```python
import sys

# Desinstalar paquetes preinstalados de Colab que chocan con el stack de entrenamiento
!{sys.executable} -m pip install -q -U pip
!{sys.executable} -m pip uninstall -y torch torchvision torchaudio bitsandbytes transformers trl peft accelerate 2>/dev/null || true

!{sys.executable} -m pip install -q torch==2.4.1 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
!{sys.executable} -m pip install -q transformers==4.47.0 peft==0.13.2 datasets trl==0.12.0 bitsandbytes==0.45.5 accelerate==1.2.1 sentencepiece

print("=" * 60)
print("✅ Paquetes instalados.")
print("⚠️  OBLIGATORIO: menú Runtime → Restart session")
print("    Luego ejecuta la Celda 1b (NO repitas la 0 ni la 1).")
print("=" * 60)
```

**Por qué el reinicio:** si ejecutaste la celda 0 antes, PyTorch antiguo queda cargado en RAM. Instalar otra versión con `pip` sin reiniciar provoca errores como `GuardSource has no attribute LOCAL_NN_MODULE` al importar `bitsandbytes`.

El aviso de `gradio` vs `huggingface-hub` es **inofensivo** (Colab trae Gradio; este notebook no lo usa).

---

## Celda 1b — Verificar entorno (después del reinicio)

> Tipo de celda: **Código**. Ejecutar **solo tras** `Runtime → Restart session`.

```python
import torch
import bitsandbytes as bnb
import transformers
from transformers import BitsAndBytesConfig

if not torch.cuda.is_available():
    raise SystemExit("❌ Sin GPU — Runtime → Change runtime type → T4 GPU")

print(f"✅ GPU: {torch.cuda.get_device_name(0)}")
print(f"   VRAM: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")
print(f"✅ torch {torch.__version__}")
print(f"✅ bitsandbytes {bnb.__version__} | transformers {transformers.__version__}")

_ = BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_compute_dtype=torch.float16)
print("✅ BitsAndBytesConfig OK — continúa con la Celda 2")
```

**Si falla aquí con `triton.ops`:** `Runtime → Disconnect and delete runtime` → celda 0 → celda 1 → **reiniciar** → celda 1b.

---

## Celda 2 — Cargar modelo Qwen2.5-Coder-7B

> Tipo de celda: **Código**. Tarda varios minutos en descargar (~15 GB).

```python
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from google.colab import userdata

hf_token = userdata.get("HF_TOKEN")

model_name = "Qwen/Qwen2.5-Coder-7B-Instruct"
# Si OOM en celdas 5–6, cambia a: "Qwen/Qwen2.5-Coder-3B-Instruct"

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.float16,
    bnb_4bit_use_double_quant=True,
)

tokenizer = AutoTokenizer.from_pretrained(
    model_name,
    trust_remote_code=True,
    token=hf_token,
)

model = AutoModelForCausalLM.from_pretrained(
    model_name,
    quantization_config=bnb_config,
    device_map="auto",
    trust_remote_code=True,
    torch_dtype=torch.float16,
    token=hf_token,
)

print(f"Modelo cargado en: {next(model.parameters()).device}")
```

---

## Celda 3 — Subir dataset

> Tipo de celda: **Código**. Al ejecutar, elige `colab_dataset.zip` desde tu PC.

```python
from google.colab import files

print("Sube colab_dataset.zip (desde training/data/colab_dataset.zip en tu PC)")
uploaded = files.upload()

!unzip -o colab_dataset.zip -d /content
!ls -lh /content/resolve_train.json /content/resolve_eval.json
```

Debes ver ambos JSON en `/content/`.

---

## Celda 4 — Cargar y formatear ShareGPT → ChatML

> Tipo de celda: **Código**. Convierte el formato del repo al template de Qwen.

```python
import json
from datasets import Dataset

DATA_DIR = "/content"
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


train_dataset = load_and_format(f"{DATA_DIR}/resolve_train.json")
eval_dataset = load_and_format(f"{DATA_DIR}/resolve_eval.json")

print(f"Train: {len(train_dataset)} ejemplos")
print(f"Eval:  {len(eval_dataset)} ejemplos")
print("\nVista previa (primeros 500 caracteres):")
print(train_dataset[0]["text"][:500])
```

Comprueba que el bloque `system` incluye la estructura didáctica (CONTEXTO / PASOS / BUENAS PRÁCTICAS).

---

## Celda 5 — Configurar LoRA

> Tipo de celda: **Código**.

```python
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training

model = prepare_model_for_kbit_training(model, use_gradient_checkpointing=True)
model.config.use_cache = False  # obligatorio al entrenar; ahorra VRAM

lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    target_modules=[
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj", "down_proj",
    ],
    lora_dropout=0.05,
    bias="none",
    task_type="CAUSAL_LM",
)

model = get_peft_model(model, lora_config)
model.print_trainable_parameters()
# Esperado: ~0,5 % parámetros entrenables
```

---

## Celda 6 — Entrenar

> Tipo de celda: **Código**. Con 1.227 ejemplos y 3 epochs: **~2–3 h** en T4 (7B).

```python
import gc
import os

import torch
from trl import SFTTrainer, SFTConfig

os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

gc.collect()
torch.cuda.empty_cache()

# trl==0.12.x → max_seq_length (NO max_length)
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

### Qué mirar en el log

```
step  50 | train_loss: 1.4x | eval_loss: 1.3x   ← debería bajar
step 100 | train_loss: 1.1x | eval_loss: 1.2x
step 200 | train_loss: 0.9x | eval_loss: 1.2x   ← si eval sube mucho: sobreentrenamiento
```

### Si CUDA OOM

1. Baja `max_seq_length` a **384**
2. O cambia en celda 2 a `Qwen/Qwen2.5-Coder-3B-Instruct` y repite celdas **5 → 6**

---

## Celda 7 — Guardar adaptador LoRA

> Tipo de celda: **Código**.

```python
model.save_pretrained("./qwen-coder-resolve-lora")
tokenizer.save_pretrained("./qwen-coder-resolve-lora")

print("✅ Adaptador guardado en ./qwen-coder-resolve-lora")
```

---

## Celda 8 — Comprimir y descargar

> Tipo de celda: **Código**. Descarga el ZIP a tu PC.

```python
import shutil
from google.colab import files

shutil.make_archive("qwen-coder-resolve-lora", "zip", "./qwen-coder-resolve-lora")
files.download("qwen-coder-resolve-lora.zip")

print("Descarga iniciada (~100–150 MB)")
```

---

## Después de Colab (en tu PC)

```powershell
# 1. Descomprime el ZIP en la raíz del repo
#    → modelos\qwen-coder-resolve-lora\  (debe contener adapter_config.json)

# 2. Fusionar LoRA + base Qwen
cd C:\Users\navar\PycharmProjects\Pygenesis_ResolveExpert
python conversion\fusionar.py

# 3. GGUF + Ollama (script automatizado)
.\conversion\convertir_gguf.ps1 -RemoveF16After -OllamaCreate
```

Guía completa post-Colab: [`../../guia_finetuning_resolve.md`](../../guia_finetuning_resolve.md) (secciones 6–9).

---

## Errores frecuentes

| Error | Solución |
|-------|----------|
| `GuardSource ... LOCAL_NN_MODULE` al importar bnb | Ejecutaste imports en celda 1 sin reiniciar → **Runtime → Restart session** → celda **1b** |
| `No module named 'triton.ops'` | Reiniciar runtime; repetir 0 → 1 → reiniciar → 1b |
| Aviso `gradio` / `huggingface-hub` | Ignorar (no usamos Gradio en este notebook) |
| `CUDA out of memory` | `max_seq_length=384` o modelo 3B |
| `401` / `403` en HuggingFace | Revisa `HF_TOKEN` en Secrets y licencia del modelo |
| `resolve_train.json` not found | Repite celda 3; comprueba `!ls /content/*.json` |
| Colab desconecta la sesión | Vuelve a ejecutar desde celda 0; los checkpoints en `./qwen-coder-resolve` se pierden si no guardaste |

---

## Checklist

- [ ] `colab_dataset.zip` generado en el PC
- [ ] Runtime T4 activo
- [ ] Secret `HF_TOKEN` configurado
- [ ] Celdas 0 → 1 → **reinicio** → 1b → 2–8 ejecutadas sin error
- [ ] `qwen-coder-resolve-lora.zip` descargado
- [ ] `fusionar.py` ejecutado en el PC
- [ ] Modelo probado con `ollama run pygenesis-resolve`
