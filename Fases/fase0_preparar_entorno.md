# Fase 0 — Preparar el entorno

> **Hardware objetivo:** Ryzen 7 6800H + Radeon 680M (ROCm) · CPU offload · Q4_K_M  
> **Objetivo de esta fase:** Tener Ollama, LM Studio y el entorno Python listos para trabajar.

---

## 0.1 Sistema operativo recomendado

ROCm tiene soporte oficial en **Linux**. Se recomienda:

- **Ubuntu 22.04 LTS** o **Ubuntu 24.04 LTS**
- Alternativa: **Fedora 39+**
- Windows funciona con Ollama pero ROCm está limitado; para entrenamiento usa Linux siempre que puedas.

Si usas Windows, considera instalar **WSL2 con Ubuntu 22.04** como entorno de entrenamiento.

---

## 0.2 Instalar drivers AMD ROCm

```bash
# Añadir repositorio AMD
sudo apt update
sudo apt install -y wget gnupg

wget https://repo.radeon.com/amdgpu-install/23.40.2/ubuntu/jammy/amdgpu-install_23.40.2.60402-1_all.deb
sudo dpkg -i amdgpu-install_23.40.2.60402-1_all.deb

# Instalar ROCm
sudo amdgpu-install --usecase=rocm,hiplibsdk

# Añadir tu usuario al grupo render y video
sudo usermod -aG render,video $USER

# Reiniciar
sudo reboot
```

### Verificar instalación de ROCm

```bash
rocm-smi
# Debe mostrar la Radeon 680M con temperatura, uso, etc.

rocminfo | grep "Name:"
# Debe aparecer: gfx1035 (nombre interno de la 680M)
```

### Variable de entorno crítica para la 680M

La Radeon 680M usa arquitectura **gfx1035**. Algunos programas no la detectan correctamente. Añade esto a tu `~/.bashrc` o `~/.zshrc`:

```bash
export HSA_OVERRIDE_GFX_VERSION=10.3.0
export ROCR_VISIBLE_DEVICES=0
```

Recarga el shell:

```bash
source ~/.bashrc
```

---

## 0.3 Instalar Ollama con soporte ROCm

```bash
# Instalación oficial (detecta ROCm automáticamente en Linux)
curl -fsSL https://ollama.com/install.sh | sh

# Verificar que Ollama ve la GPU AMD
ollama info
# Debe mostrar: AMD Radeon Graphics (o similar)
```

### Descargar el modelo base Qwen2.5-Coder

```bash
# Modelo principal — cuantización Q4_K_M (equilibrio velocidad/calidad)
ollama pull qwen2.5-coder:7b-instruct-q4_K_M

# Modelo ligero para generación de datos en paralelo
ollama pull qwen2.5-coder:1.5b

# Verificar que están disponibles
ollama list
```

### Test rápido de funcionamiento

```bash
ollama run qwen2.5-coder:7b-instruct-q4_K_M \
  "Escribe un MonoBehaviour en postproducción que mueva un objeto con Rigidbody"
```

Si responde correctamente, Ollama está funcionando.

---

## 0.4 Instalar LM Studio

LM Studio sirve para explorar modelos y hacer pruebas rápidas con interfaz gráfica.

```bash
# Descargar desde:
# https://lmstudio.ai

# En Linux, descargar el .AppImage
chmod +x LM_Studio-*.AppImage
./LM_Studio-*.AppImage
```

Dentro de LM Studio:
1. Busca `Qwen2.5-Coder-7B-Instruct-GGUF`
2. Selecciona la variante `Q4_K_M`
3. Descárgalo y prueba una conversación

---

## 0.5 Preparar el entorno Python para entrenamiento

```bash
# Instalar Python 3.11 (recomendado)
sudo apt install -y python3.11 python3.11-venv python3-pip

# Crear entorno virtual dedicado
python3.11 -m venv ~/Resolve-finetune-env
source ~/Resolve-finetune-env/bin/activate

# Actualizar pip
pip install --upgrade pip setuptools wheel
```

### Instalar PyTorch con soporte ROCm

```bash
# PyTorch para ROCm 5.7 (compatible con la 680M)
pip install torch torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/rocm5.7
```

### Verificar que PyTorch ve la GPU

```python
# Ejecuta esto en Python
import torch
print(torch.cuda.is_available())       # True (ROCm usa la API CUDA)
print(torch.cuda.get_device_name(0))   # AMD Radeon Graphics
print(torch.cuda.get_device_properties(0).total_memory)
```

### Instalar Unsloth y dependencias de entrenamiento

```bash
# Unsloth con soporte ROCm
pip install unsloth

# Dependencias adicionales
pip install \
  transformers \
  datasets \
  peft \
  trl \
  accelerate \
  bitsandbytes \
  sentencepiece \
  huggingface_hub \
  wandb \
  evaluate \
  rouge_score
```

> **Nota sobre bitsandbytes:** Si da error con ROCm, instala la versión de la comunidad:
> ```bash
> pip install bitsandbytes-rocm
> ```

---

## 0.6 Instalar herramientas de gestión de datos

```bash
pip install \
  argilla \        # Plataforma de etiquetado y revisión de datos
  cleanlab \       # Detección automática de errores en datasets
  pandas \
  datasets \       # Hugging Face Datasets
  jsonlines \
  tqdm
```

---

## 0.7 Estructura de directorios del proyecto

Crea esta estructura desde el principio:

```bash
mkdir -p ~/resolve-expert/{
  data/raw,
  data/processed,
  data/train,
  data/eval,
  models/checkpoints,
  models/lora-adapters,
  models/gguf,
  scripts,
  logs,
  evals
}
```

```
~/resolve-expert/
├── data/
│   ├── raw/           # Datos descargados sin procesar
│   ├── processed/     # Datos limpios en formato JSON
│   ├── train/         # Dataset de entrenamiento final
│   └── eval/          # Dataset de evaluación (10-15% del total)
├── models/
│   ├── checkpoints/   # Checkpoints durante el entrenamiento
│   ├── lora-adapters/ # Adaptadores LoRA entrenados
│   └── gguf/          # Modelos exportados para Ollama
├── scripts/           # Scripts de entrenamiento y evaluación
├── logs/              # Logs de entrenamiento (wandb, tensorboard)
└── evals/             # Resultados de evaluaciones
```

---

## 0.8 Cuenta en Hugging Face (opcional pero recomendado)

```bash
# Instalar CLI
pip install huggingface_hub

# Login (para descargar modelos y guardar checkpoints en la nube)
huggingface-cli login
# Introduce tu token de https://huggingface.co/settings/tokens
```

---

## ✅ Checklist de verificación — Fase 0 completada

- [ ] ROCm instalado y `rocm-smi` muestra la Radeon 680M
- [ ] Variable `HSA_OVERRIDE_GFX_VERSION=10.3.0` en `.bashrc`
- [ ] Ollama instalado y modelo `qwen2.5-coder:7b-instruct-q4_K_M` descargado
- [ ] LM Studio instalado y funcionando
- [ ] Entorno virtual Python 3.11 creado y activado
- [ ] PyTorch detecta la GPU con `torch.cuda.is_available() == True`
- [ ] Unsloth y dependencias instaladas sin errores
- [ ] Estructura de directorios `~/resolve-expert/` creada
- [ ] Cuenta Hugging Face configurada (opcional)

---

## ➡️ Siguiente paso

Con el entorno listo, continúa con la **Fase 1 — Construir el dataset**.
