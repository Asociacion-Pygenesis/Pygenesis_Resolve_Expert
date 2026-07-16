# Fase 1 — Plugin base en Resolve

Objetivo del hito: que Resolve Studio reconozca el plugin y abra una ventana flotante básica.

---

## Checklist (repo)

- [x] Estructura `com.pygenesis.davinci.tutor/` con `manifest.xml`, `main.js`, `index.html`
- [x] Id único: `com.pygenesis.davinci.tutor`
- [x] Script `install_plugin.ps1` para la ruta de Windows
- [x] UI oscura alineada con Resolve (`#1e1e1e`)

## Checklist (en tu máquina)

- [ ] Localizar SDK: `Help > Documentation > Developer > Workflow Integrations`
- [ ] Ejecutar `plugin/scripts/install_plugin.ps1`
- [ ] Reiniciar Resolve Studio
- [ ] Abrir: `Workspace > Workflow Integrations > Pygenesis Resolve Tutor`
- [ ] Confirmar estado verde *Conectado a DaVinci Resolve*

---

## SDK de Blackmagic

El binario `WorkflowIntegration.node` **no se versiona en git** (viene con Resolve).

Rutas típicas en Windows:

```
%ProgramData%\Blackmagic Design\DaVinci Resolve\Support\Developer\Workflow Integrations\Examples\SamplePlugin\
C:\Program Files\Blackmagic Design\DaVinci Resolve\Developer\Workflow Integrations\Examples\SamplePlugin\
```

En Resolve 19+ existen dos ejemplos:

- `SamplePlugin` — Electron con sandbox (recomendado a largo plazo)
- `CompatibleSamplePlugin` — modo compatibilidad sin sandbox

Este plugin usa el patrón **CompatibleSamplePlugin** para simplificar la Fase 1.

### Formato obligatorio de `manifest.xml` (Resolve 20)

Blackmagic **no** usa `<Main>` en la raíz. El formato correcto es:

```xml
<BlackmagicDesign>
    <Plugin>
        <Id>com.pygenesis.davinci.tutor</Id>
        <Name>Pygenesis Resolve Tutor</Name>
        <Version>0.1.0</Version>
        <Description>...</Description>
        <FilePath>main.js</FilePath>
    </Plugin>
</BlackmagicDesign>
```

Si el manifest es inválido, Resolve no registra ningún plugin y el menú **Workspace → Workflow Integrations** puede quedar inactivo.

---

## Solución de problemas

| Síntoma | Causa probable | Acción |
|---------|----------------|--------|
| No aparece en el menú | `manifest.xml` con formato incorrecto | Debe usar `<Plugin>` y `<FilePath>main.js</FilePath>` (ver SamplePlugin del SDK) |
| **Workflow Integrations** gris / inactivo | Ningún plugin válido registrado | Corrige manifest, reinstala con `-Force`, reinicia Resolve Studio |
| Ventana en blanco | `main.js` o `index.html` ausentes | Reinstalar con `-Force` |
| Error `WorkflowIntegration.node` | Binario no copiado o corrupto | Copiar de nuevo desde `Examples/SamplePlugin/` |
| `Initialize()` false | Id del manifest distinto | Debe ser exactamente `com.pygenesis.davinci.tutor` |

---

## Siguiente fase

Fase 2: chat con scroll, input fijo abajo, `marked.js` y estados de carga. Ver `RoadmapCreacionPlugin.md`.
