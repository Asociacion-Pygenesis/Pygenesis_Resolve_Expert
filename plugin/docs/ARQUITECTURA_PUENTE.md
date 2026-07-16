# Arquitectura: plugin ↔ puente de inferencia

Mismo patrón que **Pygenesis Unity**: el plugin **no** llama al motor LLM directamente.

---

## Capas

```
┌─────────────────────────────────────┐
│  DaVinci Resolve Studio             │
│  Plugin Workflow Integration        │
│  (Electron / index.html + JS)       │
└──────────────┬──────────────────────┘
               │  HTTP  localhost:8000
               │  POST /consultar/stream (SSE)
               │  GET  /health
               ▼
┌─────────────────────────────────────┐
│  Puente de inferencia (backend/)    │
│  FastAPI · RESOLVE_SYSTEM · RAG     │
│  llama-cpp-python · GGUF en memoria │
│  response_filters · contexto Resolve│
└─────────────────────────────────────┘
```

**Sin Ollama en producción.** El puente carga el GGUF directamente con `llama-cpp-python`.

---

## Backend GPU

| GPU detectada | Backend | Instalación |
|---------------|---------|-------------|
| NVIDIA | `cuda` | Wheel CUDA (`install_inference.ps1`) |
| AMD Radeon | `vulkan` | Build con `GGML_VULKAN=on` |
| Ninguna / fallback | `cpu` | Wheel CPU |

Detección: `backend/scripts/detect_gpu.ps1`  
Config persistida: `%LOCALAPPDATA%\Pygenesis\bridge.env`

Variables:

| Variable | Descripción |
|----------|-------------|
| `PYGENESIS_GPU_BACKEND` | `cuda` \| `vulkan` \| `cpu` \| `auto` |
| `PYGENESIS_MODEL_PATH` | Ruta al `.gguf` |
| `PYGENESIS_N_CTX` | Contexto (default 8192) |
| `PYGENESIS_N_GPU_LAYERS` | Capas en GPU (default -1 = todas) |

---

## Modelo

- Archivo: `pygenesis-resolve-q4km.gguf`
- Ubicación por defecto: `%LOCALAPPDATA%\Pygenesis\models\`
- Distribución: Hugging Face (ver `installer/model.source.json`)
- Instalador: `installer/install_pygenesis.ps1`

---

## API del puente (contrato plugin)

### `GET /health`

```json
{
  "status": "ok",
  "modelo": "pygenesis-resolve",
  "backend": "cuda",
  "model_path": "C:\\Users\\...\\Pygenesis\\models\\pygenesis-resolve-q4km.gguf",
  "model_loaded": true,
  "fragmentos": 0,
  "rag_activo": false,
  "error": null
}
```

Si el GGUF no existe: `status: "degraded"`, `model_loaded: false`.

### `POST /consultar/stream` (SSE, usado por el plugin)

Streaming en tiempo real. Eventos SSE:

```json
{"token": "fragmento"}
{"done": true, "respuesta": "texto limpio final", "fragmentos_usados": 0}
```

### `POST /consultar` (respuesta completa)

**Request:**

```json
{
  "prompt": "¿Cómo activo proxies en Resolve?",
  "contexto_proyecto": "Página activa: Edit\nProyecto: Demo",
  "modo_json": false
}
```

**Response:**

```json
{
  "respuesta": "…",
  "fragmentos_usados": 0
}
```

---

## Instalación

```powershell
# Instalador unificado (GPU + modelo HF + plugin)
Set-Location "C:\Users\navar\PycharmProjects\Pygenesis_ResolveExpert\installer"
.\install_pygenesis.ps1

# Solo motor de inferencia (desarrollo)
Set-Location "..\backend\scripts"
.\install_inference.ps1
```

## Arrancar el puente

```powershell
Set-Location "C:\Users\navar\PycharmProjects\Pygenesis_ResolveExpert\backend"
.\start_backend.ps1
```

`start_backend.ps1` carga automáticamente `%LOCALAPPDATA%\Pygenesis\bridge.env`.

---

## Desarrollo vs producción

| Componente | Desarrollo | Producción |
|------------|------------|------------|
| Ollama | Opcional (dataset sintético) | No usado |
| GGUF local | Raíz del repo o `%LOCALAPPDATA%` | Descargado por instalador |
| Inferencia | `backend/inference.py` | Igual |
