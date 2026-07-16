# Fase 2 — Interfaz de chat

Objetivo: ventana de chat con estilo Resolve, Markdown en respuestas y feedback visual.

---

## Qué incluye v0.2.0

- Paleta oscura Resolve (`#1e1e1e`, tipografía compacta)
- Historial con scroll; input fijo abajo
- **marked.js** para listas, negritas y pasos
- Spinner *"Pygenesis está pensando…"*
- Banner de desconexión si Ollama no responde o falta el modelo
- Consulta al **puente de inferencia** (`backend/` en `localhost:8000`), no a Ollama directo

> La Fase 3 añadirá el backend FastAPI y contexto de Resolve (página activa, proyecto).

---

## Instalar / actualizar

```powershell
Set-Location "C:\Users\navar\PycharmProjects\Pygenesis_ResolveExpert\plugin\scripts"
.\install_plugin.ps1 -Force
```

Cierra y reabre Resolve. Abre **Workspace → Workflow Integrations → Pygenesis Resolve Tutor**.

---

## Requisitos para chatear

1. **Ollama** en marcha con el modelo: `ollama create pygenesis-resolve -f Modelfile`
2. **Puente de inferencia** arrancado:
   ```powershell
   Set-Location "C:\Users\navar\PycharmProjects\Pygenesis_ResolveExpert\backend\scripts"
   .\start_backend.ps1
   ```
3. Plugin instalado y Resolve reiniciado

Arquitectura: [`docs/ARQUITECTURA_PUENTE.md`](ARQUITECTURA_PUENTE.md)

---

## Uso

- Escribe la pregunta y pulsa **Enviar** o **Enter** (Shift+Enter = nueva línea)
- Si Ollama no está disponible, verás el banner rojo y el botón deshabilitado
- **Reintentar** vuelve a comprobar la conexión

---

## Archivos nuevos

| Archivo | Rol |
|---------|-----|
| `js/chat-ui.js` | Mensajes, loading, banner, Markdown |
| `js/chat-api.js` | Health check y `POST /api/generate` |
| `js/vendor/marked.min.js` | Renderizado Markdown (offline) |

---

## Siguiente fase

Fase 3: `fetch` al backend FastAPI (`/consultar`), contexto de página Resolve y RAG opcional.
