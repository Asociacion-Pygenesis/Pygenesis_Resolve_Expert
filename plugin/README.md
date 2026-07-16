# Plugin — Pygenesis Resolve Tutor

Workflow Integration Plugin para **DaVinci Resolve Studio** (no funciona en la edición Free).

Conecta la interfaz dentro de Resolve con el modelo `pygenesis-resolve` vía Ollama/backend local (fases posteriores).

---

## Requisitos

- **DaVinci Resolve Studio** (19+ recomendado)
- SDK de Workflow Integrations incluido con Resolve:
  `Help > Documentation > Developer > Workflow Integrations`

---

## Fase 1 — Instalación y ventana base

### 1. Instalar el plugin

```powershell
Set-Location "C:\Users\navar\PycharmProjects\Pygenesis_ResolveExpert\plugin\scripts"
.\install_plugin.ps1
```

Si ya estaba instalado:

```powershell
.\install_plugin.ps1 -Force
```

### 2. Abrir en Resolve

1. Cierra Resolve por completo (si estaba abierto).
2. Abre **DaVinci Resolve Studio**.
3. Menú: **Workspace → Workflow Integrations → Pygenesis Resolve Tutor**.

### 3. Verificar

La ventana debe mostrar:

- Título *Pygenesis Resolve Tutor*
- Mensaje *Fase 1 — Plugin base*
- Estado **Conectado a DaVinci Resolve** (verde) si `WorkflowIntegration.node` se copió bien

Si aparece error de `WorkflowIntegration.node`, cópialo manualmente desde:

```
Help > Documentation > Developer
  → Workflow Integrations/Examples/SamplePlugin/WorkflowIntegration.node
```

Destino:

```
%ProgramData%\Blackmagic Design\DaVinci Resolve\Support\Workflow Integration Plugins\com.pygenesis.davinci.tutor\
```

---

## Estructura

```
plugin/
├── com.pygenesis.davinci.tutor/
│   ├── manifest.xml      # Id: com.pygenesis.davinci.tutor
│   ├── main.js           # Ventana Electron
│   ├── preload.js        # Carga WorkflowIntegration.node
│   ├── index.html        # UI de prueba (Fase 1)
│   ├── css/styles.css
│   └── js/app.js
├── scripts/
│   └── install_plugin.ps1
└── docs/
    └── FASE1.md
```

---

## Rutas del sistema

| SO | Carpeta de plugins |
|----|---------------------|
| Windows | `%ProgramData%\Blackmagic Design\DaVinci Resolve\Support\Workflow Integration Plugins\` |
| macOS | `/Library/Application Support/Blackmagic Design/DaVinci Resolve/Workflow Integration Plugins/` |

---

## Roadmap del plugin

Ver [`RoadmapCreacionPlugin.md`](../RoadmapCreacionPlugin.md) en la raíz del repo.

| Fase | Estado |
|------|--------|
| 1 — Estructura base y ventana | Completada |
| 2 — UI chat + Markdown | v0.2.0 |
| 3 — Puente + contexto Resolve | v0.3.0 |
| 4 — Instalador completo | Pendiente |

Guía Fase 3: [`docs/FASE3.md`](docs/FASE3.md)

Guía Fase 2: [`docs/FASE2.md`](docs/FASE2.md)
