# Roadmap: Desarrollo del Plugin (Workflow Integration)

Este roadmap se enfoca en la creación de la interfaz visual dentro de DaVinci Resolve Studio y su conectividad con el puente de inferencia local.

---

## 📅 Fase 1: Configuración del Entorno y Estructura Base (Semana 1)
* [ ] **Investigación del SDK Oficial:** Localizar y extraer la carpeta de ejemplos de *Workflow Integrations* en la ruta de desarrollo de DaVinci Resolve Studio (`Help > Documentation > Developer`).
* [ ] **Creación del Directorio de Sistema:** Configurar la carpeta del proyecto en la ruta raíz que escanea DaVinci:
  * *Windows:* `C:\ProgramData\Blackmagic Design\DaVinci Resolve\Support\Workflow Integration Plugins\`
  * *macOS:* `/Library/Application Support/Blackmagic Design/DaVinci Resolve/Workflow Integration Plugins/`
* [ ] **Configuración del Manifiesto:** Escribir el archivo `manifest.xml` inicial definiendo el identificador único (`com.pygenesis.davinci.tutor`) y apuntando a un archivo `index.html` de prueba.
* [ ] **Hito:** Lograr que DaVinci reconozca el plugin, se muestre en `Workspace > Workflow Integrations` y levante una ventana flotante básica al hacer clic.

## 📅 Fase 2: Diseño de la Interfaz y UI del Chat (Semana 2)
* [ ] **Mimetización Estética:** Diseñar los estilos CSS utilizando la paleta de color oficial de la interfaz de DaVinci (fondos gris oscuro `#1e1e1e`, textos compactos y tipografía limpia).
* [ ] **Componentes de la Ventana:** Estructurar la zona de scroll para la conversación histórica y fijar la caja de texto (`input`) en la parte inferior.
* [ ] **Renderizado Markdown:** Integrar una librería JS ligera (como `marked.js`) para formatear las respuestas estructuradas del tutor (listas numeradas, negritas y pasos de interfaz).
* [ ] **Estados Visuales de Feedback:** Programar estados interactivos como el spinner de carga ("Pygenesis está pensando...") y alertas de desconexión.

## 📅 Fase 3: Conectividad y Capa de Red Local (Semana 3)
* [ ] **Arquitectura de Peticiones:** Implementar la lógica asíncrona en JS (`fetch` o `WebSockets`) para redirigir los prompts introducidos por el usuario hacia el backend de inferencia local (`http://localhost:XXXX`).
* [ ] **Gestión de Contexto Interno:** Importar el módulo nativo `WorkflowIntegration.node` en el frontend para permitir que el plugin se comunique con la API de DaVinci.
* [ ] **Extracción de Variables de Estado:** Programar funciones que detecten en qué página se encuentra el editor (Media, Edit, Color, Fairlight) para enviarlo de forma automática como variable de contexto oculta.

## 📅 Fase 4: Pulido de Sistema e Instalador (Semana 4)
* [ ] **Control de Errores Críticos:** Diseñar pantallas de contingencia en caso de que el binario de inferencia local no esté inicializado.
* [ ] **Ecosistema Integrado:** Empaquetar el desarrollo en un instalador automatizado que detecte las rutas del sistema del usuario, copie la carpeta del plugin y verifique la liberación de los puertos de red locales.