# Fase 2 — Fine-tuning con Hardware Actual

> **Hardware:** Ryzen 7 6800H + Radeon 680M (ROCm) · CPU offload · QLoRA 4-bit  
> **Modelo recomendado:** Qwen2.5-Coder-3B-Instruct (arranca aquí) → luego 7B  
> **Objetivo:** Lanzar el primer ciclo de entrenamiento, verificar que funciona y obtener un primer adaptador LoRA.

---

## 2.1 Entender las limitaciones del hardware

| Recurso | Disponible | Uso esperado |
|---|---|---|
| RAM sistema | 16–32 GB | 12–18 GB durante entrenamiento |
| VRAM Radeon 680M | ~2 GB dedicados (compartidos con RAM) | Offload a CPU si se supera |
| CPU | Ryzen 7 6800H (8 cores) | Operaciones de CPU offload |
| Almacenamiento | SSD NVMe | Checkpoints cada N pasos |

Con estas cifras, el modelo de trabajo es **Qwen2.5-Coder-3B** con QLoRA 4-bit y CPU offload activado. El 7B también es posible pero más lento.

---

## 2.2 Verificaciones previas al entrenamiento

```bash
# Activar entorno virtual
source ~/Resolve-finetune-env/bin/activate

# Verificar GPU disponible
python3 -c "
import torch
print('CUDA/ROCm disponible:', torch.cuda.is_available())
print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'No detectada')
print('VRAM total:', round(torch.cuda.get_device_properties(0).total_memory / 1e9, 2), 'GB')
print('RAM disponible: usa htop para comprobarlo')
"

# Verificar que el dataset existe
ls -lh ~/resolve-expert/data/train/
ls -lh ~/resolve-expert/data/eval/
```

### Si la GPU no se detecta

```bash
# Asegúrate de que la variable está exportada
export HSA_OVERRIDE_GFX_VERSION=10.3.0
export ROCR_VISIBLE_DEVICES=0

# Reintentar
python3 -c "import torch; print(torch.cuda.is_available())"
```

---

## 2.3 Script principal de entrenamiento

Crea el archivo `scripts/train_phase2.py`:

```python
# scripts/train_phase2.py
import os
import json
import torch
from datasets import Dataset
from transformers import TrainingArguments
from trl import SFTTrainer, SFTConfig
from unsloth import FastLanguageModel
from unsloth.chat_templates import get_chat_template

# ─── Configuración ────────────────────────────────────────────────
MODEL_NAME    = "unsloth/Qwen2.5-Coder-3B-Instruct"  # Empieza con 3B
MAX_SEQ_LEN   = 2048       # Reducir a 1024 si hay OOM
LORA_RANK     = 8          # Bajo para hardware limitado
LORA_ALPHA    = 16
BATCH_SIZE    = 1          # Nunca subir de 1 en este hardware
GRAD_ACCUM    = 8          # Simula batch_size efectivo de 8
LEARNING_RATE = 2e-4
MAX_STEPS     = 1000       # Empieza con 500–1000 para validar
WARMUP_STEPS  = 50
OUTPUT_DIR    = os.path.expanduser("~/resolve-expert/models/checkpoints/phase2")
DATASET_PATH  = os.path.expanduser("~/resolve-expert/data/train/resolve_train.json")

# ─── Variables de entorno para ROCm ──────────────────────────────
os.environ["HSA_OVERRIDE_GFX_VERSION"] = "10.3.0"
os.environ["ROCR_VISIBLE_DEVICES"]     = "0"

# ─── Cargar modelo con QLoRA 4-bit ───────────────────────────────
print("Cargando modelo...")
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name     = MODEL_NAME,
    max_seq_length = MAX_SEQ_LEN,
    dtype          = None,       # Auto-detecta: bfloat16 en ROCm
    load_in_4bit   = True,       # QLoRA 4-bit — imprescindible
)

# Aplicar template de chat para Qwen
tokenizer = get_chat_template(tokenizer, chat_template="qwen-2.5")

# ─── Configurar LoRA ─────────────────────────────────────────────
model = FastLanguageModel.get_peft_model(
    model,
    r              = LORA_RANK,
    target_modules = [
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj", "down_proj",
    ],
    lora_alpha     = LORA_ALPHA,
    lora_dropout   = 0,          # 0 es óptimo según Unsloth
    bias           = "none",
    use_gradient_checkpointing = "unsloth",  # Reduce VRAM ~30%
    random_state   = 42,
)

print(f"Parámetros entrenables: {model.num_parameters(only_trainable=True):,}")
print(f"Parámetros totales: {model.num_parameters():,}")

# ─── Cargar y formatear dataset ──────────────────────────────────
print("Cargando dataset...")
with open(DATASET_PATH, encoding="utf-8") as f:
    raw_data = json.load(f)

def format_conversation(item):
    """Convierte formato ShareGPT al formato de chat del tokenizer."""
    convs = item["conversations"]
    messages = []
    for c in convs:
        role_map = {"system": "system", "human": "user", "gpt": "assistant"}
        role = role_map.get(c["from"], c["from"])
        messages.append({"role": role, "content": c["value"]})
    
    text = tokenizer.apply_chat_template(
        messages,
        tokenize=False,
        add_generation_prompt=False
    )
    return {"text": text}

dataset = Dataset.from_list(raw_data)
dataset = dataset.map(format_conversation, remove_columns=dataset.column_names)

# Split si no tienes archivo de eval separado
split = dataset.train_test_split(test_size=0.1, seed=42)
train_dataset = split["train"]
eval_dataset  = split["test"]

print(f"Train: {len(train_dataset)} | Eval: {len(eval_dataset)}")

# ─── Configurar entrenamiento ────────────────────────────────────
training_args = SFTConfig(
    output_dir                  = OUTPUT_DIR,
    per_device_train_batch_size = BATCH_SIZE,
    gradient_accumulation_steps = GRAD_ACCUM,
    warmup_steps                = WARMUP_STEPS,
    max_steps                   = MAX_STEPS,
    learning_rate               = LEARNING_RATE,
    fp16                        = not torch.cuda.is_bf16_supported(),
    bf16                        = torch.cuda.is_bf16_supported(),
    logging_steps               = 10,
    eval_steps                  = 100,
    save_steps                  = 200,
    evaluation_strategy         = "steps",
    save_strategy               = "steps",
    load_best_model_at_end      = True,
    optim                       = "adamw_8bit",   # Menor uso de RAM
    weight_decay                = 0.01,
    lr_scheduler_type           = "cosine",
    report_to                   = "none",          # Cambiar a "wandb" si quieres tracking
    dataset_text_field          = "text",
    max_seq_length              = MAX_SEQ_LEN,
    packing                     = False,           # False para evitar OOM
)

# ─── Lanzar entrenamiento ────────────────────────────────────────
trainer = SFTTrainer(
    model           = model,
    tokenizer       = tokenizer,
    train_dataset   = train_dataset,
    eval_dataset    = eval_dataset,
    args            = training_args,
)

print("Iniciando entrenamiento...")
print(f"Steps totales: {MAX_STEPS}")
print(f"Checkpoints cada: {training_args.save_steps} steps")

trainer_stats = trainer.train()

# ─── Guardar el adaptador LoRA ───────────────────────────────────
lora_output = os.path.expanduser("~/resolve-expert/models/lora-adapters/phase2-3b")
model.save_pretrained(lora_output)
tokenizer.save_pretrained(lora_output)

print(f"\nAdaptador LoRA guardado en: {lora_output}")
print(f"Tiempo de entrenamiento: {trainer_stats.metrics['train_runtime']:.0f}s")
print(f"Loss final: {trainer_stats.metrics['train_loss']:.4f}")
```

---

## 2.4 Lanzar el entrenamiento

```bash
# Activar entorno
source ~/Resolve-finetune-env/bin/activate

# Establecer variables ROCm
export HSA_OVERRIDE_GFX_VERSION=10.3.0
export ROCR_VISIBLE_DEVICES=0

# Lanzar entrenamiento (usa nohup para que no se corte si cierras la terminal)
nohup python3 ~/resolve-expert/scripts/train_phase2.py \
  > ~/resolve-expert/logs/train_phase2.log 2>&1 &

echo "PID del proceso: $!"

# Seguir el log en tiempo real
tail -f ~/resolve-expert/logs/train_phase2.log
```

### Monitorizar recursos durante el entrenamiento

```bash
# En otra terminal: ver GPU AMD
watch -n 2 rocm-smi

# Ver uso de CPU y RAM
htop

# Ver temperatura (importante en portátiles)
watch -n 5 "cat /sys/class/thermal/thermal_zone*/temp | awk '{print \$1/1000 \"°C\"}'"
```

---

## 2.5 Qué esperar durante el entrenamiento

| Métrica | Rango esperado (Fase 2) |
|---|---|
| Loss inicial | 2.0 – 2.5 |
| Loss a 500 steps | 1.2 – 1.8 |
| Loss a 1000 steps | 0.9 – 1.4 |
| Velocidad (CPU offload) | ~15–30 min por 100 steps |
| Temperatura CPU | 85–95°C (normal en portátil) |
| Uso de RAM | 14–20 GB |

> **Si hay Out Of Memory (OOM):**
> - Reduce `MAX_SEQ_LEN` a 1024
> - Reduce `LORA_RANK` a 4
> - Asegúrate de que `gradient_checkpointing = "unsloth"` está activo
> - Cierra el navegador y otras aplicaciones

---

## 2.6 Probar el modelo tras el entrenamiento

```python
# scripts/test_lora.py
from unsloth import FastLanguageModel
from unsloth.chat_templates import get_chat_template

LORA_PATH = "~/resolve-expert/models/lora-adapters/phase2-3b"

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name   = LORA_PATH,
    max_seq_length = 2048,
    dtype        = None,
    load_in_4bit = True,
)
tokenizer = get_chat_template(tokenizer, chat_template="qwen-2.5")
FastLanguageModel.for_inference(model)

def ask(question):
    messages = [
        {"role": "system", "value": "Eres un experto en Resolve3D, postproducción y desarrollo de videojuegos."},
        {"role": "user", "content": question}
    ]
    inputs = tokenizer.apply_chat_template(
        messages,
        tokenize=True,
        add_generation_prompt=True,
        return_tensors="pt"
    ).to("cuda")
    
    outputs = model.generate(
        input_ids  = inputs,
        max_new_tokens = 512,
        temperature = 0.7,
        do_sample  = True,
    )
    return tokenizer.decode(outputs[0][inputs.shape[1]:], skip_special_tokens=True)

# Preguntas de prueba
preguntas = [
    "¿Cómo implemento un sistema de inventario básico en Resolve?",
    "Explica la diferencia entre Update() y FixedUpdate() en Resolve",
    "¿Cómo uso ScriptableObjects para guardar datos de personajes en un RPG?",
]

for p in preguntas:
    print(f"\n{'='*60}")
    print(f"PREGUNTA: {p}")
    print(f"\nRESPUESTA:\n{ask(p)}")
```

```bash
python3 scripts/test_lora.py
```

---

## 2.7 Exportar a GGUF para usar con Ollama

```python
# scripts/export_gguf.py
from unsloth import FastLanguageModel

LORA_PATH  = "~/resolve-expert/models/lora-adapters/phase2-3b"
GGUF_OUTPUT = "~/resolve-expert/models/gguf/resolve-expert-3b"

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name   = LORA_PATH,
    max_seq_length = 2048,
    dtype        = None,
    load_in_4bit = True,
)

# Exportar en Q4_K_M (mejor equilibrio tamaño/calidad)
model.save_pretrained_gguf(
    GGUF_OUTPUT,
    tokenizer,
    quantization_method = "q4_k_m"
)
print(f"Modelo exportado a: {GGUF_OUTPUT}.gguf")
```

```bash
python3 scripts/export_gguf.py
```

### Registrar el modelo en Ollama

Crea el archivo `~/resolve-expert/models/gguf/Modelfile`:

```
FROM ./resolve-expert-3b-Q4_K_M.gguf

SYSTEM """Eres resolve-expert, un asistente especializado en Resolve3D, postproducción y desarrollo de videojuegos.
Proporciona respuestas técnicas precisas con ejemplos de código cuando sea apropiado.
Eres experto en: MonoBehaviours, física, animaciones, UI, shaders, optimización y patrones de diseño para juegos."""

PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER num_ctx 4096
```

```bash
cd ~/resolve-expert/models/gguf/
ollama create resolve-expert -f Modelfile

# Probar
ollama run resolve-expert "¿Cómo hago un sistema de diálogo en Resolve?"
```

---

## 2.8 Iteraciones recomendadas en esta fase

No entrenes una sola vez. El proceso óptimo es:

1. **Iteración 1:** 500 steps con el dataset inicial → evalúa calidad
2. **Iteración 2:** Corrige problemas del dataset, 1000 steps → evalúa
3. **Iteración 3:** Amplía dataset con los tipos de preguntas donde falla → 2000 steps

Para cada iteración ajusta estos hiperparámetros:

```python
# Si el modelo "olvida" cómo hablar (catastrofic forgetting):
LEARNING_RATE = 1e-4    # Reducir a la mitad

# Si el loss no baja:
LORA_RANK = 16          # Aumentar capacidad

# Si quieres más épocas en vez de más steps:
# Cambia max_steps por num_train_epochs = 3
```

---

## ✅ Checklist de verificación — Fase 2 completada

- [ ] GPU detectada correctamente por PyTorch/ROCm
- [ ] Primer entrenamiento completado sin errores OOM
- [ ] Loss final por debajo de 1.5
- [ ] Adaptador LoRA guardado en `models/lora-adapters/phase2-3b`
- [ ] Test manual con 5 preguntas Resolve — respuestas coherentes y con código postproducción
- [ ] Modelo exportado a GGUF y funcionando en Ollama
- [ ] Al menos 2 iteraciones de entrenamiento completadas

---

## ➡️ Siguiente paso

Con el pipeline de entrenamiento funcionando, continúa con la **Fase 3 — Escalar a RTX 3070 eGPU**.
