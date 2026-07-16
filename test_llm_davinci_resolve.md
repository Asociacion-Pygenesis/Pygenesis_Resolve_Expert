# Banco de Preguntas: Test para LLM especializado en DaVinci Resolve

Este documento contiene 30 preguntas de dificultad variada (básica, intermedia y avanzada) que cubren las principales áreas de DaVinci Resolve: Edit, Color, Fusion, Fairlight, Delivery y flujo de trabajo general. Cada pregunta incluye su respuesta de referencia para poder comparar contra la salida del modelo evaluado.

---

## Bloque 1 — Fundamentos y páginas de la interfaz

**1. ¿Cuáles son las siete páginas principales de DaVinci Resolve y para qué sirve cada una?**
Media, Cut, Edit, Fusion, Color, Fairlight y Deliver. Media es para organizar e importar clips; Cut es una versión simplificada de edición rápida; Edit es la línea de tiempo de edición principal; Fusion es composición y VFX con nodos; Color es la corrección y gradación de color (basada en nodos); Fairlight es la mezcla y edición de audio; Deliver es donde se configuran y exportan los renders finales.

**2. ¿Qué diferencia hay entre la página Cut y la página Edit?**
Cut está pensada para ediciones rápidas con una interfaz simplificada, doble línea de tiempo (source tape y timeline) y herramientas contextuales; Edit ofrece control total sobre pistas, efectos, transiciones y es la línea de tiempo tradicional multipista con acceso completo a todas las herramientas de edición.

**3. ¿Qué es un "Render Cache" y qué tipos existen?**
Es un sistema de precomputación que renderiza en segundo plano clips o nodos complejos para aliviar la reproducción en tiempo real. Existen el "User" cache (manual, marcando el clip) y el "Smart" cache (automático quando Resolve detecta complejidad, como múltiples nodos de Fusion o efectos pesados).

**4. ¿Para qué sirve el Media Pool y cómo se organiza?**
Es el repositorio central de todos los archivos multimedia importados (vídeo, audio, gráficos). Se organiza mediante bins (carpetas), smart bins (carpetas con reglas automáticas de filtrado) y metadatos personalizados para clasificar y buscar clips rápidamente.

**5. ¿Qué es el "Color Management" (Gestión de color) en Resolve y por qué es importante?**
Es el sistema que controla cómo se interpretan y transforman los espacios de color desde la cámara hasta la entrega final (por ejemplo, DaVinci Wide Gamut o ACES). Es importante porque asegura consistencia de color entre distintas cámaras, formatos y dispositivos de salida.

---

## Bloque 2 — Edición (Edit Page)

**6. ¿Cuál es la diferencia entre un corte "Insert", "Overwrite" y "Replace" en la línea de tiempo?**
Insert añade el clip empujando hacia la derecha todo lo que está después del punto de edición; Overwrite coloca el clip sobrescribiendo el contenido existente sin desplazar nada; Replace sustituye un clip de la timeline por otro manteniendo la duración y el punto de edición del clip original.

**7. ¿Qué es un "Compound Clip" y cuándo conviene usarlo?**
Es la agrupación de varios clips y pistas en un único clip contenedor que se comporta como un solo elemento en la timeline. Conviene usarlo para simplificar secuencias complejas (por ejemplo, una escena con múltiples cámaras ya sincronizadas) y mantener la timeline principal más ordenada.

**8. ¿Qué diferencia hay entre un "Compound Clip" y un "Timeline anidado" (Nested Timeline)?**
El Compound Clip vive dentro del mismo clip/timeline como un objeto encapsulado y no aparece como una timeline independiente en el Media Pool; la timeline anidada es una timeline completa e independiente que se inserta dentro de otra, y se puede abrir y editar como cualquier otra timeline del proyecto.

**9. ¿Para qué se usa la herramienta "Match Frame" (F)?**
Sirve para localizar en el Media Pool (o en otra timeline) el clip de origen exacto correspondiente al fotograma seleccionado en la timeline, útil para volver al material original y buscar tomas alternativas.

**10. ¿Qué hace la función "Auto Sync" con clips de audio y vídeo por separado?**
Sincroniza automáticamente clips de audio (por ejemplo, de una grabadora externa) con su vídeo correspondiente, usando timecode, forma de onda (waveform) o marcadores manuales como referencia.

**11. ¿Qué es un "Marker" y qué utilidad tiene en un flujo de trabajo colaborativo?**
Es una anotación de color asociada a un punto concreto de la timeline o de un clip, con texto, duración y categoría. Es útil para dejar notas de revisión, señalar cambios pendientes o marcar puntos clave que otros colaboradores (editores, coloristas, sonidistas) pueden ver y filtrar.

**12. ¿Qué diferencia hay entre "Ripple Delete" y "Delete" normal en la timeline?**
"Delete" (o "Lift") elimina el clip dejando un hueco vacío en su lugar; "Ripple Delete" elimina el clip y cierra automáticamente el hueco, desplazando hacia la izquierda todo el contenido posterior.

---

## Bloque 3 — Color (Color Page)

**13. Explica cómo funciona el sistema de nodos en la página Color.**
Cada nodo representa una operación de corrección de color aplicada de forma secuencial o en paralelo. Los nodos en serie procesan la imagen uno tras otro (la salida de uno es la entrada del siguiente); los nodos en paralelo combinan varias correcciones sobre la misma imagen base mediante un nodo de mezcla (parallel mixer); también existen nodos layer, que permiten componer capas al estilo Photoshop.

**14. ¿Qué es una "Power Window" y para qué se utiliza?**
Es una máscara con forma geométrica o de curva libre que aísla una zona de la imagen para aplicar corrección de color solo en esa región, con posibilidad de trackear el movimiento del sujeto u objeto enmascarado.

**15. ¿Qué diferencia hay entre corrección "Primaria" y "Secundaria"?**
La corrección primaria afecta a toda la imagen de manera global (balance de blancos, exposición, contraste general); la corrección secundaria afecta solo a una parte específica de la imagen, aislada por color (qualifier), forma (power window) o zona tonal.

**16. ¿Qué es un LUT y qué tipos existen en Resolve?**
Un LUT (Look-Up Table) es una tabla matemática que transforma valores de color de entrada a otros de salida, usada para aplicar un "look" o para convertir entre espacios de color. En Resolve existen LUTs 1D (afectan canales por separado, usados típicamente para curvas de gamma) y 3D (afectan combinaciones de RGB, usados para looks creativos y conversiones de espacio de color).

**17. ¿Qué es el "Qualifier" (HSL Qualifier) y cómo se usa en un flujo de corrección secundaria?**
Es una herramienta que selecciona píxeles según su rango de matiz (Hue), saturación (Saturation) y luminancia (Luminance) usando un cuentagotas sobre la imagen. Se usa para aislar, por ejemplo, solo el color de la piel o el cielo, y aplicarles corrección sin afectar el resto de la imagen.

**18. ¿Qué es la rueda de "Log", "Lift/Gamma/Gain" y cuál es la diferencia principal en su uso?**
Lift/Gamma/Gain trabajan sobre sombras, medios tonos y altas luces respectivamente en un espacio de color ya interpretado (Rec.709, por ejemplo); las ruedas Log operan directamente sobre metraje logarítmico (footage log) antes de aplicar una transformación de color, controlando exposición general, contraste y pivote sin comprimir el rango dinámico.

**19. ¿Qué es ColorTrace / Remote Grades y para qué sirve?**
ColorTrace permite copiar la gradación completa (todos los nodos y ajustes) de un proyecto o timeline a otro, comparando y aplicando las correcciones a clips equivalentes de una nueva versión del corte, muy útil cuando la edición cambia y hay que re-conformar la gradación.

**20. ¿Qué diferencia hay entre "Shot Match" y aplicar un grade manualmente?**
"Shot Match" es una función automática que analiza dos imágenes y ajusta balance de color y exposición de un clip para que coincida visualmente con otro de referencia, acelerando el proceso; hacerlo manualmente da control total pero requiere más tiempo y criterio del colorista.

---

## Bloque 4 — Fusion (VFX y composición)

**21. ¿En qué se diferencia el flujo de trabajo basado en nodos de Fusion frente al de capas (layer-based) de otros compositores?**
En Fusion cada operación es un nodo conectado mediante entradas y salidas, permitiendo ramificaciones y combinaciones no lineales explícitas y visuales; en un flujo por capas, el orden de apilamiento de arriba a abajo determina implícitamente el orden de composición, lo cual es menos flexible para combinar múltiples fuentes de forma no secuencial.

**22. ¿Qué es un nodo "Merge" en Fusion y qué parámetros clave tiene?**
Es el nodo que combina (compone) dos imágenes, una de fondo (Background) y otra de primer plano (Foreground), usando su canal alfa. Sus parámetros clave incluyen Blend (opacidad), Apply Mode (modo de fusión), Position y Size (posición y escala del foreground).

**23. ¿Qué es el "Delta Keyer" y cuándo se prefiere sobre un "Chroma Keyer" estándar?**
Es una herramienta de keying que compara la imagen con y sin el fondo de color (chroma) capturado como referencia (clean plate), generando un canal alfa muy preciso. Se prefiere cuando el chroma tiene iluminación desigual o el sujeto tiene elementos translúcidos difíciles de extraer con un keyer estándar basado solo en rangos de color.

**24. ¿Qué es el tracker de Fusion (Tracker node) y qué tipos de seguimiento ofrece?**
Es una herramienta que analiza el movimiento de puntos de referencia en una secuencia para generar datos de posición, rotación y escala. Ofrece seguimiento de un punto, de cuatro puntos (para corner pin/perspectiva) y seguimiento de cámara en 3D (Camera Tracker).

**25. ¿Cómo se conecta Fusion con la página Edit/Color dentro del mismo proyecto?**
A través de "Fusion Clips" (clips que contienen una composición Fusion completa) o mediante la pestaña Fusion dentro del clip en la timeline, lo que permite aplicar efectos y composición sin salir del proyecto ni exportar/importar archivos intermedios.

---

## Bloque 5 — Fairlight (Audio)

**26. ¿Qué es un "Bus" en Fairlight y para qué se utiliza?**
Es un canal de mezcla intermedio al que se enrutan varias pistas (por ejemplo, todos los diálogos o toda la música) para aplicarles procesamiento conjunto (compresión, ecualización, volumen) antes de enviarlas al máster final.

**27. ¿Qué es el "Loudness Meter" y por qué es relevante para la entrega final?**
Es un medidor que muestra el nivel de sonoridad percibida en unidades LUFS (Loudness Units Full Scale), en lugar de solo picos en dB. Es relevante porque las plataformas de streaming y broadcast exigen estándares de loudness específicos (por ejemplo, -23 LUFS para EBU R128 o -14 LUFS para muchas plataformas online), y no cumplirlos puede provocar rechazo del material o normalización automática no deseada.

**28. ¿Qué diferencia hay entre "ADR" y "Foley" dentro del flujo de Fairlight, y qué herramientas ofrece Resolve para ADR?**
ADR (Automated/Additional Dialogue Replacement) consiste en regrabar diálogo en estudio para sincronizarlo con la imagen; Foley es la creación de efectos de sonido ambientales o de acción (pasos, roces, objetos) sincronizados con la imagen. Resolve ofrece una herramienta de ADR integrada con cue markers automáticos, cuenta regresiva visual y grabación en múltiples takes directamente sincronizados con la timeline.

---

## Bloque 6 — Deliver, formatos y flujo de proyecto

**29. ¿Qué diferencia hay entre renderizar con "Individual clips" y usar un preset de "Render Queue" completo en la página Deliver?**
Renderizar clips individuales exporta cada clip seleccionado como archivo separado (útil para VFX o entregas por plano); un preset de Render Queue exporta la timeline completa como un único archivo (o varios) según el formato y códec configurado, pensado para entregas de máster completo o para plataformas específicas (YouTube, Vimeo, broadcast).

**30. ¿Qué es un "Collaboration Project" (proyecto colaborativo) en Resolve y qué requisito de infraestructura necesita?**
Es un modo de proyecto que permite a varios usuarios trabajar simultáneamente sobre el mismo proyecto (con bloqueo de bins/timelines para evitar conflictos), sincronizando cambios en tiempo casi real. Requiere una base de datos PostgreSQL alojada en red (Disk Database compartida, Resolve Project Server, o Blackmagic Cloud) accesible por todos los puestos de trabajo.

---

*Documento pensado para evaluar precisión terminológica, comprensión de flujo de trabajo y profundidad técnica de un LLM especializado en DaVinci Resolve. Se recomienda puntuar cada respuesta del modelo comparándola con la respuesta de referencia en términos de exactitud, completitud y ausencia de alucinaciones.*
