¿Cuáles son las siete páginas principales de DaVinci Resolve y para qué sirve cada una?
edit
Las siete páginas principales de DaVinci Resolve son: 1) Timeline, donde puedes ver la secuencia de clips y ajustar sus parámetros; 2) Edit, donde se realizan cambios en el audio o video; 3) Color, donde se aplica color corrección a los clips; 4) Fusion, donde se combinan distintos elementos para crear una imagen final; 5) Fairlight, donde se ajusta y mezcla el audio; 6) Deliver, donde se prepara la entrega del proyecto; y 7) Project Manager, donde se gestionan los proyectos.


What is the difference between the Cut page and the Edit page?
edit
The Cut page is used to organize clips on a timeline, while the Edit page is used to edit the audio or video of individual clips.


¿Qué diferencia hay entre la página Cut y la página Edit?
edit
La página Cut se utiliza para organizar clips en una línea de tiempo, mientras que la página Edit se utiliza para editar el audio o video de clips individuales.


¿Qué es un "Render Cache" y qué tipos existen?
edit
Un Render Cache es una versión de bajo rendimiento de un clip o composición que se crea automáticamente cuando se reproduce la escena en tiempo real. Los render caches pueden reducir significativamente el tiempo de renderizado para efectos de imagen intensivos y permitir un flujo de trabajo más fluido mientras se trabaja con proyectos grandes. Existen dos tipos de Render Cache: 1) Cache on Disk, que almacena los archivos de renderizado en la misma ubicación del proyecto, y 2) Cache in Project Media Pool, que almacena los archivos de renderizado en un archivo separado dentro del pool de medios del proyecto.


¿Para qué sirve el Media Pool y cómo se organiza?
edit
El Media Pool es una biblioteca de medios que contiene todos los clips utilizados en un proyecto. Se organiza al mostrar los clips en función de sus propiedades, como nombre o fecha, y permite buscar clips rápidamente utilizando la barra de búsqueda. Los clips se pueden ordenar y reordenar fácilmente dentro del Media Pool para facilitar el acceso a ellos durante la edición.


¿Qué es el "Color Management" (Gestión de color) en Resolve y por qué es importante?
edit
El Color Management (Gestión de color) en Resolve se refiere a los procesos utilizados para convertir un color entre diferentes sistemas de colores. Es importante porque permite a los artistas trabajar con imágenes de alta calidad mientras mantienen una consistencia adecuada y precisa en la reproducción final del contenido. Por ejemplo, si estás trabajando con una imagen que fue grabada en una cámara DSLR y luego importada a Resolve, debes asegurarte de que se aplique la gestión de color correcta para mantener el equilibrio de cromos y la tonalidad original de la imagen.


¿Cuál es la diferencia entre un corte "Insert", "Overwrite" y "Replace" en la línea de tiempo?
edit
La diferencia entre un corte "Insert", "Overwrite" y "Replace" en la línea de tiempo radica en cómo se insertan o reemplazan los clips. Un corte "Insert" agrega el clip al final de la secuencia sin afectar los clips existentes. Un corte "Overwrite" reemplaza el clip actual con un nuevo clip sin afectar los clips restantes. Finalmente, un corte "Replace" reemplaza el clip actual y los siguientes clips con un nuevo clip.


¿Qué diferencia hay entre un "Compound Clip" y un "Timeline anidado" (Nested Timeline)?
edit
Un "Compound Clip" se utiliza para agrupar varios clips en una sola unidad, lo que facilita la edición y mejora el rendimiento de DaVinci Resolve. Por otro lado, un "Timeline anidado" (Nested Timeline) es similar a un "Compound Clip" pero permite trabajar con múltiples timelines simultáneamente. Los "Timelines anidados" también son útiles cuando se desea reutilizar una secuencia de clips en varios proyectos diferentes.


¿Para qué se usa la herramienta "Match Frame" (F)?
edit
La herramienta "Match Frame" (F) se utiliza para sincronizar los frames entre dos clips o entre un clip y una imagen. Para hacerlo, selecciona el frame que deseas sincronizar en uno de los clips, luego selecciona la herramienta "Match Frame" (F) en el menú de edición. Finalmente, haz clic en el otro clip o imagen para sincronizar los frames.


¿Qué hace la función "Auto Sync" con clips de audio y vídeo por separado?
edit
La función "Auto Sync" sincroniza automáticamente los clips de audio y vídeo con base en la información del metadata del archivo. Para hacerlo, selecciona el clip que deseas sincronizar en la línea de tiempo, luego haz clic en el menú desplegable "Sync" y selecciona la opción "Auto Sync". Finalmente, DaVinci Resolve se encargará de sincronizar automáticamente los clips de audio y vídeo con base en la información del metadata del archivo.


¿Qué es un "Marker" y qué utilidad tiene en un flujo de trabajo colaborativo?
edit
Un "Marker" es una notación utilizada para marcar puntos importantes en un clip o secuencia de clips. En un flujo de trabajo colaborativo, los markers pueden ser útiles para indicar cambios realizados por diferentes personas y ayudar a mantener el seguimiento de los cambios realizados en cada clip. Por ejemplo, si dos artistas están trabajando en una película juntos, uno podría marcar con un marker rojo las partes del clip que ha editado y otro podrían marcar con un marker verde las partes del clip que ha editado él.


¿Qué diferencia hay entre "Ripple Delete" y "Delete" normal en la timeline?
edit
La diferencia radica en cómo se eliminan los clips de una secuencia. "Ripple Delete" elimina los clips seleccionados y reorganiza la secuencia, mientras que "Delete" normal solo elimina los clips seleccionados sin reorganizar la secuencia.


Explica cómo funciona el sistema de nodos en la página Color
edit
Para crear un efecto de color, arrastra los nodos deseados desde la biblioteca de efectos al lienzo de composición y conecta sus salidas a las entradas correspondientes del nodo final. Por ejemplo, para aplicar una corrección de color RGB, arrastra el nodo "RGB" desde la biblioteca de efectos al lienzo de composición y conecta su salida a la entrada correspondiente del nodo final.


¿Qué es una "Power Window" y para qué se utiliza?
edit
Una "Power Window" es una herramienta utilizada en DaVinci Resolve para ajustar el nivel de luz en un clip, especialmente cuando hay diferencias significativas entre las partes más oscuras y brillantes del mismo. Para utilizarla, selecciona el clip deseado y haz clic en la herramienta "Power Window" en la pestaña "Controls". Luego, arrastra los puntos de control para ajustar el nivel de luz según sea necesario.


¿Qué diferencia hay entre corrección "Primaria" y "Secundaria"?
edit
La corrección primaria se aplica a la imagen original mientras se realiza la edición. Se utilizan herramientas como el color wheel, la curva de RGB o los controles de correción para ajustar los colores de la imagen. La corrección secundaria se aplica después de que se ha realizado la edición y se utiliza para ajustar los colores finales de la película.


¿Qué es un LUT y qué tipos existen en Resolve?
edit
Los LUTs (Look Up Tables) son archivos predefinidos que contienen información sobre cómo transformar los colores de una imagen para crear un efecto específico. En DaVinci Resolve, puedes usar LUTs para aplicar cambios a la imagen sin tener que ajustar cada canal individualmente. Hay varios tipos de LUTs disponibles en Resolve, incluyendo paletos (palettes), correcciones de color (color corrections) y gráficos (graphics).


¿Qué es el "Qualifier" (HSL Qualifier) y cómo se usa en un flujo de corrección secundaria?
edit
El "Qualifier" es una herramienta que permite seleccionar los tonos o áreas específicas de la imagen para aplicarles un cambio. En un flujo de corrección secundaria, el qualifier puede ser útil para aplicar cambios solo a ciertos tonos o áreas de la imagen. Por ejemplo, si deseas aumentar la saturación de los colores verdes en una imagen, puedes utilizar el qualifier para seleccionar solo los tonos verdes y aplicarle un ajuste de saturación específico.


¿Qué es la rueda de "Log", "Lift/Gamma/Gain" y cuál es la diferencia principal en su uso?
edit
La rueda de "Log" se utiliza para ajustar los tonos más oscuros de una imagen, mientras que las ruedas de "Lift", "Gamma" y "Gain" se utilizan para ajustar los tonos más claros. La principal diferencia entre ellas es que la rueda de "Log" se centra en los tonos más oscuros de la imagen, mientras que las otras tres ruedas se centran en los tonos más claros.


¿Qué es ColorTrace / Remote Grades y para qué sirve?
edit
ColorTrace / Remote Grades es un servicio en línea que permite a los colores y gráficos colaborar desde cualquier lugar del mundo. Los colores pueden exportar una secuencia de tiempo o clip como proyecto, que se puede importar en cualquier sesión de ColorTrace para realizar ajustes de color, luego regresar y sincronizar los cambios con DaVinci Resolve.


¿Qué diferencia hay entre "Shot Match" y aplicar un grade manualmente?
edit
La diferencia radica en que el "Shot Match" automáticamente ajusta la iluminación de una secuencia a la iluminación de otra secuencia sin necesidad de ajustar cada parámetro individualmente. Por otro lado, aplicar un grade manualmente implica ajustar los parámetros de correción para lograr un efecto deseado.


¿En qué se diferencia el flujo de trabajo basado en nodos de Fusion frente al de capas (layer-based) de otros compositores?
edit
El flujo de trabajo basado en nodos es similar a la forma de trabajar con After Effects o Photoshop. En lugar de aplicar efectos a una capa, primero se configuran los efectos como nodos y luego se conectan para crear una secuencia. Esto permite una mayor control sobre el flujo de información entre los efectos.


¿Qué es un nodo "Merge" en Fusion y qué parámetros clave tiene?
edit
Un nodo "Merge" combina dos o más nodos anteriores en la secuencia de tiempo, creando una imagen final. El parámetro clave para este tipo de nodo es el modo de fusión (Merge Mode), que determina cómo se combinarán las imágenes. Selecciona esta opción desde la pestaña "Fusion" del menú desplegable en la parte superior derecha del panel del nodo Merge.


¿Qué es el "Delta Keyer" y cuándo se prefiere sobre un "Chroma Keyer" estándar?
edit
El Delta Keyer es una herramienta de Fusion que se utiliza para eliminar fuentes verdes o azules en una imagen mientras mantiene los bordes del objeto más suaves y naturales. Se prefiere cuando el sujeto tiene colores similares a los del fondo verde o azul, pero no es lo suficientemente claro como para un Chroma Keyer estándar. Por ejemplo, si se está trabajando con una imagen de una cebolla sobre un fondo verde, el Delta Keyer puede proporcionar mejores resultados que un Chroma Keyer estándar.


¿Qué es el tracker de Fusion (Tracker node) y qué tipos de seguimiento ofrece?
edit
El tracker de Fusion es una herramienta poderosa que permite seguir objetos o puntos en una imagen a lo largo del tiempo, y se utiliza para aplicar animación y transformaciones a los clips. Ofrece diferentes tipos de seguimiento, como el seguimiento de puntos (Tracker Nodes), el seguimiento de rastros (Trackers), el seguimiento de segmentos (Segment Tracker) y el seguimiento de curvas (Curve Tracker).


¿Cómo se conecta Fusion con la página Edit/Color dentro del mismo proyecto?
edit
Para conectar Fusion con la página Edit/Color, debes ir a la pestaña "Deliver" en la parte superior izquierda de la interfaz y hacer clic en el botón "Open in Color". Esto abrirá la página de color actual en DaVinci Resolve, permitiéndote trabajar en la secuencia desde Fusion.


¿Qué es un "Bus" en Fairlight y para qué se utiliza?
edit
Un bus es una ruta de audio que se utiliza para agrupar varios tracks. Esto puede ayudarte a gestionar fácilmente los clips de audio y aplicar efectos a un grupo de clips al mismo tiempo. Por ejemplo, si estás trabajando con un proyecto que incluye clips de diálogo y música, puedes crear un bus para cada categoría y luego aplicar efectos específicos a cada uno.


¿Qué es el "Loudness Meter" y por qué es relevante para la entrega final?
edit
El Loudness Meter es una herramienta que mide la nivelación de audio en una secuencia o clip, utilizando estándares como LUFS (Lumens Full Scale). Es relevante para la entrega final porque permite asegurarte de que los clips de audio cumplen con los requisitos de nivelación establecidos por el estándar ITU-R BS.1770-4. Si un clip no cumple con estos requisitos, puedes ajustarlo utilizando herramientas como Normalize o Limit para mejorar su nivelación.


¿Qué diferencia hay entre "ADR" y "Foley" dentro del flujo de Fairlight, y qué herramientas ofrece Resolve para ADR?
edit
Dentro del flujo de Fairlight, ADR se refiere a la grabación de diálogo sincronizado con video o imagen, mientras que Foley se refiere a los sonidos naturales producidos por objetos en una escena. Para ayudar en el proceso de grabación de ADR, Resolve ofrece herramientas como el Track FX, que permite aplicar efectos a un clip individual sin afectar otros clips en la pista. También ofrece la opción de sincronizar automáticamente los clips de audio con el video utilizando la función "Auto Sync".


¿Qué diferencia hay entre renderizar con "Individual clips" y usar un preset de "Render Queue" completo en la página Deliver?
edit
Para renderizar con "Individual clips", selecciona cada clip individualmente y haz clic en el botón "Render" para exportarlo como archivo separado. Por otro lado, para utilizar un preset de "Render Queue" completo, primero debes configurar las opciones de renderizado en la pestaña "Deliver" utilizando un preset predefinido, como "Optimized for web". Luego, puedes seleccionar varios clips individuales y arrastrarlos a la pestaña "Deliver", donde se aplicarán automáticamente las opciones de renderizado configuradas anteriormente.


¿Qué es un "Collaboration Project" (proyecto colaborativo) en Resolve y qué requisito de infraestructura necesita?
edit
Un Collaboration Project es un tipo de proyecto en DaVinci Resolve que permite a varios usuarios trabajar simultáneamente sobre una secuencia. Para crear un Collaboration Project, debes utilizar la opción "Collaboration" del menú "Project Type" y asegurarte de tener acceso a un servidor multicliente o una red privada dedicada.


¿En qué se diferencia el flujo de trabajo basado en nodos de Fusion frente al de capas (layer-based) de otros compositores?
edit
El flujo de trabajo basado en nodos es similar a la forma de trabajar con After Effects o Photoshop. En lugar de aplicar efectos a una capa, primero se configuran los efectos como nodos y luego se conectan para crear una secuencia. Esto permite una mayor control sobre el flujo de información entre los efectos.


¿Qué es un nodo "Merge" en Fusion y qué parámetros clave tiene?
edit
Un nodo "Merge" combina dos o más nodos anteriores en la secuencia de tiempo, creando una imagen final. El parámetro clave para este tipo de nodo es el modo de fusión (Merge Mode), que determina cómo se combinarán las imágenes. Selecciona esta opción desde la pestaña "Fusion" del menú desplegable en la parte superior derecha del panel del nodo Merge.


¿Qué es el "Delta Keyer" y cuándo se prefiere sobre un "Chroma Keyer" estándar?
edit
El Delta Keyer es una herramienta de Fusion que se utiliza para eliminar fuentes verdes o azules en una imagen mientras mantiene los bordes del objeto más suaves y naturales. Se prefiere cuando el sujeto tiene colores similares a los del fondo verde o azul, pero no es lo suficientemente claro como para un Chroma Keyer estándar. Por ejemplo, si se está trabajando con una imagen de una cebolla sobre un fondo verde, el Delta Keyer puede proporcionar mejores resultados que un Chroma Keyer estándar.


¿Qué es el tracker de Fusion (Tracker node) y qué tipos de seguimiento ofrece?
edit
El tracker de Fusion es una herramienta poderosa que permite seguir objetos o puntos en una imagen a lo largo del tiempo, y se utiliza para aplicar animación y transformaciones a los clips. Ofrece diferentes tipos de seguimiento, como el seguimiento de puntos (Tracker Nodes), el seguimiento de rastros (Trackers), el seguimiento de segmentos (Segment Tracker) y el seguimiento de curvas (Curve Tracker).


¿Cómo se conecta Fusion con la página Edit/Color dentro del mismo proyecto?
edit
Para conectar Fusion con la página Edit/Color, debes ir a la pestaña "Deliver" en la parte superior izquierda de la interfaz y hacer clic en el botón "Open in Color". Esto abrirá la página de color actual en DaVinci Resolve, permitiéndote trabajar en la secuencia desde Fusion.


¿Qué es un "Bus" en Fairlight y para qué se utiliza?
edit
Un bus es una ruta de audio que se utiliza para agrupar varios tracks. Esto puede ayudarte a gestionar fácilmente los clips de audio y aplicar efectos a un grupo de clips al mismo tiempo. Por ejemplo, si estás trabajando con un proyecto que incluye clips de diálogo y música, puedes crear un bus para cada categoría y luego aplicar efectos específicos a cada uno.


¿Qué es el "Loudness Meter" y por qué es relevante para la entrega final?
edit
El Loudness Meter es una herramienta que mide la nivelación de audio en una secuencia o clip, utilizando estándares como LUFS (Lumens Full Scale). Es relevante para la entrega final porque permite asegurarte de que los clips de audio cumplen con los requisitos de nivelación establecidos por el estándar ITU-R BS.1770-4. Si un clip no cumple con estos requisitos, puedes ajustarlo utilizando herramientas como Normalize o Limit para mejorar su nivelación.


¿Qué diferencia hay entre "ADR" y "Foley" dentro del flujo de Fairlight, y qué herramientas ofrece Resolve para ADR?
edit
Dentro del flujo de Fairlight, ADR se refiere a la grabación de diálogo sincronizado con video o imagen, mientras que Foley se refiere a los sonidos naturales producidos por objetos en una escena. Para ayudar en el proceso de grabación de ADR, Resolve ofrece herramientas como el Track FX, que permite aplicar efectos a un clip individual sin afectar otros clips en la pista. También ofrece la opción de sincronizar automáticamente los clips de audio con el video utilizando la función "Auto Sync".


¿Qué diferencia hay entre renderizar con "Individual clips" y usar un preset de "Render Queue" completo en la página Deliver?
edit
Para renderizar con "Individual clips", selecciona cada clip individualmente y haz clic en el botón "Render" para exportarlo como archivo separado. Por otro lado, para utilizar un preset de "Render Queue" completo, primero debes configurar las opciones de renderizado en la pestaña "Deliver" utilizando un preset predefinido, como "Optimized for web". Luego, puedes seleccionar varios clips individuales y arrastrarlos a la pestaña "Deliver", donde se aplicarán automáticamente las opciones de renderizado configuradas anteriormente.


¿Qué es un "Collaboration Project" (proyecto colaborativo) en Resolve y qué requisito de infraestructura necesita?
edit
Un Collaboration Project es un tipo de proyecto en DaVinci Resolve que permite a varios usuarios trabajar simultáneamente sobre una secuencia. Para crear un Collaboration Project, debes utilizar la opción "Collaboration" del menú "Project Type" y asegurarte de tener acceso a un servidor multicliente o una red privada dedicada.



¿En qué se diferencia el flujo de trabajo basado en nodos de Fusion frente al de capas (layer-based) de otros compositores?
edit
El flujo de trabajo basado en nodos es similar a la forma de trabajar con After Effects o Photoshop. En lugar de aplicar efectos a una capa, primero se configuran los efectos como nodos y luego se conectan para crear una secuencia. Esto permite una mayor control sobre el flujo de información entre los efectos.


¿Qué es un nodo "Merge" en Fusion y qué parámetros clave tiene?
edit
Un nodo "Merge" combina dos o más nodos anteriores en la secuencia de tiempo, creando una imagen final. El parámetro clave para este tipo de nodo es el modo de fusión (Merge Mode), que determina cómo se combinarán las imágenes. Selecciona esta opción desde la pestaña "Fusion" del menú desplegable en la parte superior derecha del panel del nodo Merge.


¿Qué es el "Delta Keyer" y cuándo se prefiere sobre un "Chroma Keyer" estándar?
edit
El Delta Keyer es una herramienta de Fusion que se utiliza para eliminar fuentes verdes o azules en una imagen mientras mantiene los bordes del objeto más suaves y naturales. Se prefiere cuando el sujeto tiene colores similares a los del fondo verde o azul, pero no es lo suficientemente claro como para un Chroma Keyer estándar. Por ejemplo, si se está trabajando con una imagen de una cebolla sobre un fondo verde, el Delta Keyer puede proporcionar mejores resultados que un Chroma Keyer estándar.


¿Qué es el tracker de Fusion (Tracker node) y qué tipos de seguimiento ofrece?
edit
El tracker de Fusion es una herramienta poderosa que permite seguir objetos o puntos en una imagen a lo largo del tiempo, y se utiliza para aplicar animación y transformaciones a los clips. Ofrece diferentes tipos de seguimiento, como el seguimiento de puntos (Tracker Nodes), el seguimiento de rastros (Trackers), el seguimiento de segmentos (Segment Tracker) y el seguimiento de curvas (Curve Tracker).


¿Cómo se conecta Fusion con la página Edit/Color dentro del mismo proyecto?
edit
Para conectar Fusion con la página Edit/Color, debes ir a la pestaña "Deliver" en la parte superior izquierda de la interfaz y hacer clic en el botón "Open in Color". Esto abrirá la página de color actual en DaVinci Resolve, permitiéndote trabajar en la secuencia desde Fusion.


¿Qué es un "Bus" en Fairlight y para qué se utiliza?
edit
Un bus es una ruta de audio que se utiliza para agrupar varios tracks. Esto puede ayudarte a gestionar fácilmente los clips de audio y aplicar efectos a un grupo de clips al mismo tiempo. Por ejemplo, si estás trabajando con un proyecto que incluye clips de diálogo y música, puedes crear un bus para cada categoría y luego aplicar efectos específicos a cada uno.


¿Qué es el "Loudness Meter" y por qué es relevante para la entrega final?
edit
El Loudness Meter es una herramienta que mide la nivelación de audio en una secuencia o clip, utilizando estándares como LUFS (Lumens Full Scale). Es relevante para la entrega final porque permite asegurarte de que los clips de audio cumplen con los requisitos de nivelación establecidos por el estándar ITU-R BS.1770-4. Si un clip no cumple con estos requisitos, puedes ajustarlo utilizando herramientas como Normalize o Limit para mejorar su nivelación.


¿Qué diferencia hay entre "ADR" y "Foley" dentro del flujo de Fairlight, y qué herramientas ofrece Resolve para ADR?
edit
Dentro del flujo de Fairlight, ADR se refiere a la grabación de diálogo sincronizado con video o imagen, mientras que Foley se refiere a los sonidos naturales producidos por objetos en una escena. Para ayudar en el proceso de grabación de ADR, Resolve ofrece herramientas como el Track FX, que permite aplicar efectos a un clip individual sin afectar otros clips en la pista. También ofrece la opción de sincronizar automáticamente los clips de audio con el video utilizando la función "Auto Sync".


¿Qué diferencia hay entre renderizar con "Individual clips" y usar un preset de "Render Queue" completo en la página Deliver?
edit
Para renderizar con "Individual clips", selecciona cada clip individualmente y haz clic en el botón "Render" para exportarlo como archivo separado. Por otro lado, para utilizar un preset de "Render Queue" completo, primero debes configurar las opciones de renderizado en la pestaña "Deliver" utilizando un preset predefinido, como "Optimized for web". Luego, puedes seleccionar varios clips individuales y arrastrarlos a la pestaña "Deliver", donde se aplicarán automáticamente las opciones de renderizado configuradas anteriormente.


¿Qué es un "Collaboration Project" (proyecto colaborativo) en Resolve y qué requisito de infraestructura necesita?
edit
Un Collaboration Project es un tipo de proyecto en DaVinci Resolve que permite a varios usuarios trabajar simultáneamente sobre una secuencia. Para crear un Collaboration Project, debes utilizar la opción "Collaboration" del menú "Project Type" y asegurarte de tener acceso a un servidor multicliente o una red privada dedicada.