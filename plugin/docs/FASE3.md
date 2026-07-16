# Fase 3 — Contexto de Resolve

El plugin lee el estado de DaVinci Resolve y lo envía al puente como `contexto_proyecto` (campo oculto para el usuario, visible en la barra de contexto).

---

## Qué se captura

| Dato | API Resolve |
|------|-------------|
| Página activa | `GetCurrentPage()` → media, edit, color, fusion, fairlight, deliver… |
| Proyecto | `GetProjectManager().GetCurrentProject().GetName()` |
| Timeline | `GetCurrentProject().GetCurrentTimeline().GetName()` |

Ejemplo enviado al puente:

```text
Página activa: Color
Proyecto: Documental 2026
Timeline: Master v3
```

El backend lo inyecta en el prompt como bloque `system` adicional (ver `backend/main.py` → `construir_prompt`).

---

## Archivos

| Archivo | Rol |
|---------|-----|
| `js/resolve-context.js` | Lectura de Resolve + formato de contexto |
| `js/chat-ui.js` | Pasa `contextoProyecto` en cada consulta |
| Barra bajo el header | Muestra resumen: `Color · Documental 2026 · Master v3` |

La barra se actualiza cada 5 segundos y al abrir el plugin.

---

## Instalar v0.3.0

```powershell
Set-Location "C:\Users\navar\PycharmProjects\Pygenesis_ResolveExpert\plugin\scripts"
.\install_plugin.ps1 -Force
```

Reinicia Resolve. El puente debe seguir activo (`.\start_backend.ps1`).

---

## Probar

1. Abre un proyecto con timeline en Resolve.
2. Cambia de página (Edit → Color).
3. Verifica que la barra de contexto cambia.
4. Pregunta algo contextual, p. ej. *¿Qué debería revisar aquí en la página Color?*

---

## Siguiente (Fase 4)

Instalador unificado, pantallas de error si el puente no está activo, y empaquetado para distribución.
