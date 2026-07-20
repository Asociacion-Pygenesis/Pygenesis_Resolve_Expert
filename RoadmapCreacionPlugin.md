# Roadmap: Desarrollo del Plugin (Workflow Integration)

Este roadmap se enfoca en la creación de la interfaz visual dentro de DaVinci Resolve Studio y su conectividad con el puente de inferencia local.

---

## 📅 Fase 1: Configuración del Entorno y Estructura Base (Semana 1)
* [x] **Investigación del SDK Oficial:** Documentado en [`plugin/docs/FASE1.md`](plugin/docs/FASE1.md). Ejemplos en `Help > Documentation > Developer > Workflow Integrations`.
* [x] **Creación del Directorio de Sistema:** Código en [`plugin/com.pygenesis.davinci.tutor/`](plugin/com.pygenesis.davinci.tutor/). Instalación con [`plugin/scripts/install_plugin.ps1`](plugin/scripts/install_plugin.ps1).
  * *Windows:* `C:\ProgramData\Blackmagic Design\DaVinci Resolve\Support\Workflow Integration Plugins\`
  * *macOS:* `/Library/Application Support/Blackmagic Design/DaVinci Resolve/Workflow Integration Plugins/`
* [x] **Configuración del Manifiesto:** `manifest.xml` con Id `com.pygenesis.davinci.tutor` y entrada `main.js` → `index.html`.
* [x] **Hito:** Plugin visible en `Workspace > Workflow Integrations` con ventana flotante.

## 📅 Fase 2: Diseño de la Interfaz y UI del Chat (Semana 2)
* [x] **Mimetización Estética:** Paleta Resolve (`#1e1e1e`), tipografía compacta en [`plugin/com.pygenesis.davinci.tutor/css/styles.css`](plugin/com.pygenesis.davinci.tutor/css/styles.css).
* [x] **Componentes de la Ventana:** Historial con scroll + input fijo abajo ([`index.html`](plugin/com.pygenesis.davinci.tutor/index.html)).
* [x] **Renderizado Markdown:** `marked.js` en [`js/vendor/marked.min.js`](plugin/com.pygenesis.davinci.tutor/js/vendor/marked.min.js).
* [x] **Estados Visuales de Feedback:** Spinner y banner de desconexión del **puente** ([`js/chat-ui.js`](plugin/com.pygenesis.davinci.tutor/js/chat-ui.js)).
* [x] **Hito:** Chat probado (v0.2.0; transición a puente en lugar de Ollama directo).

> **Arquitectura acordada:** el plugin habla con `backend/` (puente FastAPI), no con Ollama. Ver [`plugin/docs/ARQUITECTURA_PUENTE.md`](plugin/docs/ARQUITECTURA_PUENTE.md).

## 📅 Fase 3: Conectividad y Capa de Red Local (Semana 3)
* [x] **Arquitectura de Peticiones:** `chat-api.js` → puente en `localhost:8000` (stream + fallback).
* [x] **Gestión de Contexto Interno:** [`js/resolve-context.js`](plugin/com.pygenesis.davinci.tutor/js/resolve-context.js) vía `WorkflowIntegration.node`.
* [x] **Extracción de Variables de Estado:** Página activa, proyecto y timeline → `contexto_proyecto`.
* [ ] **Hito:** Verificar respuestas contextualizadas al cambiar de página en Resolve.

## 📅 Fase 4: Pulido de Sistema e Instalador (Semana 4)
* [x] **Motor propio (sin Ollama):** `backend/inference.py` con `llama-cpp-python` + GGUF.
* [x] **Detección GPU:** NVIDIA → CUDA, AMD → Vulkan (`detect_gpu.ps1`, `install_inference.ps1`).
* [x] **Instalador unificado:** `installer/install_pygenesis.ps1` (GPU + modelo HF + plugin).
* [ ] **Control de Errores Críticos:** Pantallas de contingencia si el modelo no está descargado/cargado.
* [x] **Publicar modelo en Hugging Face** y actualizar `installer/model.source.json` (`SuNavar/Pygenesis_ResolveExpert`).
* [x] **Instalador cerrado:** `Install.bat` + Companion con asistente de setup (estado + instalar lo que falta) + `build_release.ps1`.
* [ ] **Evaluación automática** con `test_llm_davinci_resolve.md` vía puente.