# Roadmap: Dataset, Entrenamiento y Fine-Tuning en Google Colab

Este roadmap define el pipeline de datos, la sintetización en formato instructivo y el proceso de fine-tuning (LoRA) utilizando el entorno de Google Colab.

---

## 📅 Fase 1: Extracción y Limpieza de Fuentes (Semana 1)
* [ ] **Procesamiento de Manuales Oficiales:** Ejecutar scripts en Python con `PyMuPDF` (`fitz`) para procesar el *Manual de Referencia de DaVinci Resolve* y las guías de entrenamiento de Blackmagic.
* [ ] **Extracción por Bloques:** Programar el extractor en modo `"blocks"` para evitar que las maquetaciones a doble columna o las capturas de pantalla rompan el orden del texto.
* [ ] **Scraping de Comunidades:** Desarrollar scrapers automatizados en Python para extraer hilos de soluciones técnicas del foro oficial de Blackmagic y de comunidades de postproducción, aislando la estructura "Pregunta del usuario ➔ Solución válida".
* [ ] **Sanitización Inicial:** Aplicar expresiones regulares (`re`) para eliminar metadatos, números de página repetidos, encabezados legales y ruido textual.

## 📅 Fase 2: Generación del Dataset Sintético (Semana 2)
* [ ] **Pipeline de Conversión Q&A:** Diseñar un script que envíe los bloques de texto limpios hacia un LLM local rápido encargado de actuar como sintetizador de datos.
* [ ] **Ingeniería de Prompts para Datos:** Configurar un System Prompt estricto que obligue al modelo a generar de 1 a 3 pares de preguntas/respuestas reales en base al fragmento técnico aportado.
* [ ] **Normalización al Formato Instruct:** Estructurar el output del pipeline en un JSON con formato Alpaca/Instruct estándar (`instruction`, `input`, `output`).
* [ ] **Control de Glosario Técnico:** Validar de forma manual o mediante scripts que las respuestas en español mantengan los nombres de las herramientas exactamente como aparecen en la UI de DaVinci Resolve (ej. *Vectorscope*, *Lift*, *Gamma*, *Gain*).

## 📅 Fase 3: Configuración del Entorno y Entrenamiento (Semana 3)
* [ ] **Preparación del Notebook:** Configurar el entorno de Google Colab instalando las dependencias críticas (`transformers`, `peft`, `bitsandbytes`, `trl`).
* [ ] **Carga Cuantizada del Modelo Base:** Cargar el modelo seleccionado (ej. *Llama 3.1 8B Instruct* o *Qwen 2.5 7B Instruct*) parametrizado en **4-bit** para optimizar el espacio en la VRAM de la GPU de Colab.
* [ ] **Inyección del Adaptador LoRA:** Configurar los hiperparámetros del entrenamiento:
  * Rangos óptimos (`r=16` o `32`, `lora_alpha=32` o `64`).
  * Módulos objetivo de atención (`q_proj`, `v_proj`, `k_proj`, `o_proj`).
* [ ] **Ejecución del SFT:** Lanzar el proceso con `SFTTrainer`, monitorizando las curvas de pérdida (*loss*) para evitar el sobreajuste y asegurar que aprenda el rol didáctico del tutor.

## 📅 Fase 4: Fusión y Optimización Local (Semana 4)
* [ ] **Persistencia del Adaptador:** Almacenar los pesos resultantes del adaptador LoRA de forma segura en Hugging Face.
* [ ] **Fusión de Pesos (Merge):** Combinar el LoRA entrenado con el modelo base original para generar un modelo unificado.
* [ ] **Conversión y Cuantización de Distribución:** Exportar el modelo final al formato específico que requiera vuestro puente de inferencia propio.
* [ ] **Optimización Local:** Cuantizar el modelo final (ej. a 4 o 5 bits) asegurando que consuma el mínimo de recursos del sistema en local, evitando interferir con el rendimiento y uso de GPU que DaVinci Resolve necesita durante la edición.