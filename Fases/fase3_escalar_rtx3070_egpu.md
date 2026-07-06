# Fase 3 — Escalar a RTX 3070 12GB eGPU

> **Hardware:** Ryzen 7 6800H + RTX 3070 12GB vía eGPU (USB4/Thunderbolt 4)  
> **Modelos disponibles:** Qwen2.5-Coder-7B (cómodo) · Qwen2.5-Coder-14B (justo)  
> **Objetivo:** Entrenar el modelo experto definitivo con mayor calidad, velocidad y capacidad.

---

## 3.1 Configurar el eGPU en Linux

### Verificar que el sistema detecta el eGPU Thunderbolt

```bash
# Conectar el eGPU ANTES de encender, o reconectar en caliente si el BIOS lo permite
sudo apt install bolt

# Listar dispositivos Thunderbolt
boltctl list

# Autorizar el eGPU (primera vez)
boltctl enroll --policy auto <UUID-DEL-DISPOSITIVO>

# Verificar que la NVIDIA aparece en el sistema
lspci | grep -i nvidia
# Debe mostrar: NVIDIA Corporation GA104 [GeForce RTX 3070 ...]
```

### Instalar drivers NVIDIA y CUDA

```bash
# Añadir repositorio NVIDIA
sudo apt install -y ubuntu-drivers-common
sudo ubuntu-drivers autoinstall

# O instalar versión específica (recomendada para RTX 3070)
sudo apt install -y nvidia-driver-545

# Reiniciar
sudo reboot

# Verificar tras reinicio
nvidia-smi
# Debe mostrar: NVIDIA GeForce RTX 3070, 12GB
```

### Instalar CUDA Toolkit

```bash
# CUDA 12.1 (compatible con PyTorch más reciente)
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt update
sudo apt install -y cuda-toolkit-12-1

# Añadir al PATH
echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc

# Verificar
nvcc --version
```

---

## 3.2 Limitaciones del eGPU vía USB4

El adaptador USB4 introduce una penalización de ancho de banda respecto a PCIe interno. Esto es importante entenderlo:

| Conexión | Ancho de banda | Impacto en entrenamiento |
|---|---|---|
| PCIe 4.0 x16 (interno) | ~32 GB/s | Referencia (100%) |
| Thunderbolt 4 / USB4 | ~5 GB/s | ~70–80% del rendimiento |

**Implicaciones prácticas:**
- Inferencia: impacto mínimo (~5% más lento)
- Entrenamiento: ~20–30% más lento que PCIe interno
- Sigue siendo **5–10× más rápido** que la Radeon 680M con CPU offload

### Optimizar para eGPU

```bash
# Verificar que el enlace es USB4 Gen 2×2 (40 Gbps)
sudo lshw -C display | grep -i "width\|clock"

# Reducir overhead PCIe — añadir al arranque del sistema
# En /etc/default/grub, añadir a GRUB_CMDLINE_LINUX_DEFAULT:
# pcie_aspm=off

sudo update-grub
sudo reboot
```

---

## 3.3 Reinstalar PyTorch con soporte CUDA

```bash
source ~/Resolve-finetune-env/bin/activate

# Desinstalar versión ROCm anterior
pip uninstall torch torchvision torchaudio -y

# Instalar PyTorch con CUDA 12.1
pip install torch torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu121

# Verificar
python3 -c "
import torch
print('CUDA disponible:', torch.cuda.is_available())
print('GPU:', torch.cuda.get_device_name(0))
print('VRAM:', round(torch.cuda.get_device_properties(0).total_memory / 1e9, 2), 'GB')
print('CUDA version:', torch.version.cuda)
"
```

### Reinstalar Unsloth con CUDA

```bash
# Unsloth para CUDA (más optimizado que la versión ROCm)
pip uninstall unsloth -y
pip install "unsloth[colab-new] @ git+https://github.com/unslothai/unsloth.git"

# Verificar instalación
python3 -c "from unsloth import FastLanguageModel; print('Unsloth OK')"
```

---

## 3.4 Script de entrenamiento para Qwen2.5-Coder-7B

```python
# scripts/train_phase3_7b.py
import os
import json
import torch
from datasets import Dataset
from trl import SFTTrainer, SFTConfig
from unsloth import FastLanguageModel
from unsloth.chat_templates import get_chat_template

# ─── Configuración 7B con 12GB VRAM ──────────────────────────────
MODEL_NAME    = "unsloth/Qwen2.5-Coder-7B-Instruct"
MAX_SEQ_LEN   = 4096       # Podemos subir con 12GB
LORA_RANK     = 32         # Más capacidad que en fase 2
LORA_ALPHA    = 64
BATCH_SIZE    = 2          # Podemos subir a 2 con 12GB
GRAD_ACCUM    = 4          # Batch efectivo = 8
LEARNING_RATE = 2e-4
NUM_EPOCHS    = 3          # Entrenamos por épocas, no por steps
OUTPUT_DIR    = os.path.expanduser("~/resolve-expert/models/checkpoints/phase3-7b")
DATASET_PATH  = os.path.expanduser("~/resolve-expert/data/train/resolve_train.json")

# ─── Cargar modelo ───────────────────────────────────────────────
print("Cargando Qwen2.5-Coder-7B...")
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name     = MODEL_NAME,
    max_seq_length = MAX_SEQ_LEN,
    dtype          = torch.bfloat16,   # bfloat16 en RTX 3070
    load_in_4bit   = True,             # QLoRA 4-bit
)
tokenizer = get_chat_template(tokenizer, chat_template="qwen-2.5")

# ─── LoRA con más capacidad ──────────────────────────────────────
model = FastLanguageModel.get_peft_model(
    model,
    r              = LORA_RANK,
    target_modules = [
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj", "down_proj",
    ],
    lora_alpha     = LORA_ALPHA,
    lora_dropout   = 0,
    bias           = "none",
    use_gradient_checkpointing = "unsloth",
    random_state   = 42,
)

print(f"Parámetros entrenables: {model.num_parameters(only_trainable=True):,}")

# ─── Dataset ─────────────────────────────────────────────────────
with open(DATASET_PATH, encoding="utf-8") as f:
    raw_data = json.load(f)

def format_conversation(item):
    convs = item["conversations"]
    messages = []
    for c in convs:
        role_map = {"system": "system", "human": "user", "gpt": "assistant"}
        role = role_map.get(c["from"], c["from"])
        messages.append({"role": role, "content": c["value"]})
    text = tokenizer.apply_chat_template(
        messages, tokenize=False, add_generation_prompt=False
    )
    return {"text": text}

dataset = Dataset.from_list(raw_data)
dataset = dataset.map(format_conversation, remove_columns=dataset.column_names)
split   = dataset.train_test_split(test_size=0.1, seed=42)

# ─── Entrenamiento ───────────────────────────────────────────────
training_args = SFTConfig(
    output_dir                  = OUTPUT_DIR,
    num_train_epochs            = NUM_EPOCHS,
    per_device_train_batch_size = BATCH_SIZE,
    gradient_accumulation_steps = GRAD_ACCUM,
    warmup_ratio                = 0.05,
    learning_rate               = LEARNING_RATE,
    bf16                        = True,
    logging_steps               = 10,
    eval_steps                  = 200,
    save_steps                  = 500,
    evaluation_strategy         = "steps",
    save_strategy               = "steps",
    load_best_model_at_end      = True,
    optim                       = "adamw_8bit",
    weight_decay                = 0.01,
    lr_scheduler_type           = "cosine",
    report_to                   = "none",
    dataset_text_field          = "text",
    max_seq_length              = MAX_SEQ_LEN,
    packing                     = True,    # Packing ON con 12GB — más eficiente
)

trainer = SFTTrainer(
    model         = model,
    tokenizer     = tokenizer,
    train_dataset = split["train"],
    eval_dataset  = split["test"],
    args          = training_args,
)

print("Iniciando entrenamiento 7B...")
trainer_stats = trainer.train()

# ─── Guardar ─────────────────────────────────────────────────────
lora_output = os.path.expanduser("~/resolve-expert/models/lora-adapters/phase3-7b")
model.save_pretrained(lora_output)
tokenizer.save_pretrained(lora_output)

print(f"\nAdaptador guardado en: {lora_output}")
print(f"Tiempo: {trainer_stats.metrics['train_runtime']:.0f}s")
print(f"Loss final: {trainer_stats.metrics['train_loss']:.4f}")
```

---

## 3.5 Alternativa: Qwen2.5-Coder-14B (máxima calidad)

Con 12GB de VRAM, el 14B cabe **en QLoRA 4-bit** pero con configuración más conservadora:

```python
# scripts/train_phase3_14b.py
# Solo cambia estos parámetros respecto al script 7B:

MODEL_NAME    = "unsloth/Qwen2.5-Coder-14B-Instruct"
MAX_SEQ_LEN   = 2048       # Reducir para que quepa
LORA_RANK     = 16         # Más bajo para ahorrar memoria
LORA_ALPHA    = 32
BATCH_SIZE    = 1          # Volver a 1 por restricción de VRAM
GRAD_ACCUM    = 8

# El resto del script es idéntico al 7B
```

> **Aviso:** El 14B con QLoRA 4-bit ocupa ~9–10GB de VRAM. Deja poco margen pero funciona. Si hay OOM reduce `MAX_SEQ_LEN` a 1024.

---

## 3.6 Monitorizar el entrenamiento en la RTX 3070

```bash
# Ver uso de GPU en tiempo real
watch -n 1 nvidia-smi

# Ver temperatura y velocidad del ventilador
nvidia-smi dmon -s pucvmet

# Monitorizar con más detalle
pip install nvitop
nvitop
```

### Métricas esperadas con RTX 3070

| Modelo | Velocidad | Tiempo/época (10k ejemplos) | VRAM usada |
|---|---|---|---|
| Qwen 3B | ~120 tokens/s | ~20 min | 5–6 GB |
| Qwen 7B | ~60 tokens/s | ~40 min | 9–10 GB |
| Qwen 14B | ~30 tokens/s | ~80 min | 11–12 GB |

---

## 3.7 Ampliar y mejorar el dataset en esta fase

Con la mayor capacidad del 7B/14B, el modelo puede aprender patrones más complejos. Amplía el dataset con:

```python
# scripts/generate_advanced_dataset.py
# Genera ejemplos avanzados usando el modelo 3B de Fase 2 como "profesor"

import requests
import json

OLLAMA_URL = "http://localhost:11434/api/generate"

ADVANCED_TOPICS = [
    # Patrones de arquitectura
    "Entity Component System (ECS) en Resolve DOTS",
    "State Machine pattern para IA de enemigos",
    "Command pattern para sistema de Undo/Redo",
    "Observer pattern con Resolve Events",
    
    # Optimización
    "Object Pooling con cola genérica en postproducción",
    "Occlusion Culling y LOD Groups scripting",
    "Batching dinámico y estático",
    "Profiler API para medir performance en runtime",
    
    # Sistemas de juego completos
    "Inventory system con drag & drop",
    "Quest system con ScriptableObjects",
    "Save system con binary serialization",
    "Dialogue system con árboles de decisión",
    "Procedural level generation básico",
    
    # Multijugador
    "Netcode for GameObjects basics",
    "Client-side prediction en Resolve",
    "Network variables y RPCs",
    
    # Shaders y gráficos
    "Shader Graph: dissolve effect",
    "Custom render pass en URP",
    "GPU Instancing para objetos repetidos",
]

def generate_advanced_qa(topic):
    prompt = f"""Genera un tutorial detallado sobre "{topic}" en Resolve3D con postproducción.
Incluye:
1. Explicación del concepto (2-3 párrafos)
2. Código de ejemplo completo y funcional
3. Cómo integrarlo en un proyecto real
4. Errores comunes y cómo evitarlos

Formato JSON:
[{{
  "question": "pregunta técnica específica sobre {topic}",
  "answer": "respuesta detallada con código"
}}]
Solo JSON."""
    
    payload = {
        "model": "resolve-expert",  # Usa tu modelo de fase 2
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.6, "num_predict": 2048}
    }
    r = requests.post(OLLAMA_URL, json=payload, timeout=300)
    return r.json().get("response", "")

all_advanced = []

for topic in ADVANCED_TOPICS:
    print(f"Generando: {topic}")
    response = generate_advanced_qa(topic)
    try:
        response = response.strip()
        if response.startswith("```"):
            response = response.split("\n", 1)[1].rsplit("```", 1)[0]
        pairs = json.loads(response)
        for pair in pairs:
            if "question" in pair and "answer" in pair:
                all_advanced.append({
                    "conversations": [
                        {"from": "system", "value": "Eres un experto en Resolve3D, postproducción y desarrollo de videojuegos."},
                        {"from": "human", "value": pair["question"]},
                        {"from": "gpt", "value": pair["answer"]}
                    ]
                })
    except Exception as e:
        print(f"  Error: {e}")

output = os.path.expanduser("~/resolve-expert/data/raw/synthetic/advanced_qa.json")
with open(output, "w", encoding="utf-8") as f:
    json.dump(all_advanced, f, indent=2, ensure_ascii=False)

print(f"Ejemplos avanzados generados: {len(all_advanced)}")
```

---

## 3.8 Exportar el modelo final a Ollama

```python
# scripts/export_final.py
from unsloth import FastLanguageModel

LORA_PATH   = "~/resolve-expert/models/lora-adapters/phase3-7b"
GGUF_OUTPUT = "~/resolve-expert/models/gguf/resolve-expert-7b-final"

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name   = LORA_PATH,
    max_seq_length = 4096,
    dtype        = None,
    load_in_4bit = True,
)

# Exportar en Q4_K_M para uso diario
model.save_pretrained_gguf(GGUF_OUTPUT, tokenizer, quantization_method="q4_k_m")
print(f"Exportado: {GGUF_OUTPUT}-Q4_K_M.gguf")

# Exportar en Q8_0 para máxima calidad (más lento)
model.save_pretrained_gguf(GGUF_OUTPUT + "-q8", tokenizer, quantization_method="q8_0")
print(f"Exportado: {GGUF_OUTPUT}-q8-Q8_0.gguf")
```

### Modelfile final para Ollama

```
FROM ./resolve-expert-7b-final-Q4_K_M.gguf

SYSTEM """Eres resolve-expert, un asistente avanzado especializado en Resolve3D, postproducción y desarrollo de videojuegos.

Tus especialidades incluyen:
- Resolve Engine: MonoBehaviours, Physics, Animation, UI, Input System, Cinemachine
- postproducción avanzado: LINQ, async/await, eventos, delegates, generics
- Patrones de diseño para juegos: ECS, State Machine, Observer, Command, Object Pool
- Optimización: Profiler, batching, LOD, occlusion culling, memory management
- Sistemas de juego: inventario, diálogos, misiones, guardado, IA de enemigos
- Multijugador: Netcode for GameObjects, Mirror
- Shaders: Shader Graph, URP, HDRP

Proporciona siempre ejemplos de código postproducción funcionales y completos.
Explica el razonamiento detrás de cada solución.
Alerta sobre errores comunes y buenas prácticas."""

PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER top_k 40
PARAMETER num_ctx 8192
PARAMETER repeat_penalty 1.1
```

```bash
cd ~/resolve-expert/models/gguf/
ollama create resolve-expert-7b -f Modelfile

# Prueba final
ollama run resolve-expert-7b \
  "Diseña un sistema de inventario completo para un RPG en Resolve con soporte para stackables y drag&drop"
```

---

## 3.9 Integración opcional: asistente dentro del Resolve Editor

Puedes llamar a tu modelo desde el propio Resolve Editor con un script de editor:

```csharp
// Editor/ResolveExpertWindow.cs
using ResolveEngine;
using ResolveEditor;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;

public class ResolveExpertWindow : EditorWindow
{
    private string question = "";
    private string answer = "";
    private bool isLoading = false;
    private Vector2 scrollPos;

    [MenuItem("Tools/Resolve Expert AI")]
    public static void ShowWindow()
    {
        GetWindow<ResolveExpertWindow>("Resolve Expert AI");
    }

    void OnGUI()
    {
        GUILayout.Label("Resolve Expert AI (Local)", EditorStyles.boldLabel);
        GUILayout.Space(10);

        GUILayout.Label("Pregunta:");
        question = EditorGUILayout.TextArea(question, GUILayout.Height(80));

        GUILayout.Space(5);
        GUI.enabled = !isLoading && !string.IsNullOrEmpty(question);

        if (GUILayout.Button(isLoading ? "Consultando..." : "Preguntar"))
        {
            AskModel();
        }
        GUI.enabled = true;

        if (!string.IsNullOrEmpty(answer))
        {
            GUILayout.Space(10);
            GUILayout.Label("Respuesta:");
            scrollPos = EditorGUILayout.BeginScrollView(scrollPos, GUILayout.Height(300));
            EditorGUILayout.TextArea(answer, GUILayout.ExpandHeight(true));
            EditorGUILayout.EndScrollView();
        }
    }

    private async void AskModel()
    {
        isLoading = true;
        answer = "";
        Repaint();

        try
        {
            using var client = new HttpClient();
            client.Timeout = System.TimeSpan.FromSeconds(120);

            var payload = new
            {
                model = "resolve-expert-7b",
                prompt = question,
                stream = false
            };

            var json = JsonUtility.ToJson(payload);
            var content = new StringContent(json, Encoding.UTF8, "application/json");
            var response = await client.PostAsync("http://localhost:11434/api/generate", content);
            var responseJson = await response.Content.ReadAsStringAsync();

            // Parseo básico de la respuesta
            var idx = responseJson.IndexOf("\"response\":\"") + 12;
            var end = responseJson.IndexOf("\"", idx);
            answer = responseJson.Substring(idx, end - idx)
                .Replace("\\n", "\n")
                .Replace("\\t", "\t");
        }
        catch (System.Exception e)
        {
            answer = $"Error: {e.Message}\n¿Está Ollama corriendo? (ollama serve)";
        }
        finally
        {
            isLoading = false;
            Repaint();
        }
    }
}
```

---

## ✅ Checklist de verificación — Fase 3 completada

- [ ] RTX 3070 detectada por `nvidia-smi` con 12GB VRAM
- [ ] CUDA 12.1 instalado y verificado con `nvcc --version`
- [ ] PyTorch reinstalado con soporte CUDA (sin ROCm)
- [ ] Unsloth CUDA instalado correctamente
- [ ] Entrenamiento 7B completado (al menos 1 época)
- [ ] Loss final por debajo de 1.0
- [ ] Dataset ampliado con ejemplos avanzados
- [ ] Modelo 7B exportado a GGUF y funcionando en Ollama
- [ ] Prueba del modelo con 10+ preguntas técnicas Resolve — calidad notablemente superior a Fase 2
- [ ] Modelfile con system prompt definitivo configurado
- [ ] (Opcional) Script de editor en Resolve funcionando

---

## 📈 Próximos pasos tras la Fase 3

Una vez tengas el modelo base funcionando bien, puedes continuar iterando:

1. **Ampliar dataset** con tutoriales de YouTube transcritos, libros de desarrollo de juegos, documentación de assets populares (DOTween, Photon, PlayFab...)
2. **DPO (Direct Preference Optimization)** — anotar qué respuestas son mejores para alinear el modelo con tus preferencias
3. **Subir el modelo a Hugging Face** para no perderlo y compartirlo con la comunidad
4. **Probar Qwen2.5-Coder-32B** con la 3070 en GPTQ 4-bit (solo inferencia, entrenamiento requeriría más VRAM)

---

## 📁 Estructura final del proyecto

```
~/resolve-expert/
├── data/
│   ├── raw/           ← Datos originales (no borrar)
│   ├── processed/     ← Datos limpios intermedios
│   ├── train/         ← resolve_train.json (dataset final)
│   └── eval/          ← resolve_eval.json
├── models/
│   ├── checkpoints/   ← Checkpoints de entrenamiento
│   ├── lora-adapters/ ← phase2-3b/, phase3-7b/
│   └── gguf/          ← resolve-expert-7b-final-Q4_K_M.gguf
├── scripts/
│   ├── scrape_stackoverflow.py
│   ├── scrape_github.py
│   ├── generate_synthetic.py
│   ├── generate_advanced_dataset.py
│   ├── process_dataset.py
│   ├── train_phase2.py
│   ├── train_phase3_7b.py
│   ├── export_gguf.py
│   └── test_lora.py
└── logs/
    └── train_phase2.log / train_phase3.log
```
