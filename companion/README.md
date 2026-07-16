# Pygenesis Companion

Ventana flotante independiente para usuarios de **DaVinci Resolve Free** (y como alternativa en Studio). Reutiliza el chat y el puente de inferencia local, pero **no** necesita Workflow Integration ni `WorkflowIntegration.node`.

## Requisitos

- Puente activo en `http://localhost:8000` (`backend\start_backend.ps1`)
- Modelo GGUF instalado (`installer\install_pygenesis.ps1`)
- Node.js 18+ (para Electron)

## Instalación

```powershell
Set-Location "C:\Users\navar\PycharmProjects\Pygenesis_ResolveExpert\companion\scripts"
.\install_companion.ps1
```

Sincroniza `chat-api.js`, `chat-ui.js` y estilos desde el plugin Studio.

## Uso

1. Arranca el puente:

```powershell
cd backend
.\start_backend.ps1
```

2. Abre Companion:

```powershell
cd companion\scripts
.\start_companion.ps1
```

3. Indica manualmente la **página** en la que trabajas (Media, Cut, Edit, Fusion, Color, Fairlight, Deliver).
4. Opcional: nombre de proyecto y timeline.
5. Escribe tu pregunta.

La selección se guarda en `localStorage` del navegador Electron.

## Contexto inteligente

Igual que el plugin Studio:

- Si preguntas sobre Fusion pero indicaste Edit → aviso *Respuesta general*.
- Preguntas tipo «¿qué debería revisar?» usan la página seleccionada.
- El backend (`page_context.py`) sigue analizando el texto de la pregunta.

## Studio vs Free

| Edición | Opción recomendada |
|---------|-------------------|
| **Resolve Studio** | Plugin integrado: `Workspace → Workflow Integrations → Pygenesis Resolve Tutor` |
| **Resolve Free** | **Pygenesis Companion** (esta app) |

## Estructura

```
companion/
├── pygenesis-companion/
│   ├── main.js              # Electron standalone
│   ├── index.html           # UI + selector de página
│   ├── js/
│   │   ├── companion-context.js
│   │   ├── chat-api.js      # copia del plugin
│   │   └── chat-ui.js
│   └── css/styles.css
└── scripts/
    ├── install_companion.ps1
    └── start_companion.ps1
```

## Roadmap (fase 2)

- Script Lua interno en Resolve Free para leer página/proyecto automáticamente
- Acceso directo en el escritorio desde el instalador
- Icono de aplicación
