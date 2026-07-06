# Roadmap dataset — Pygenesis ResolveExpert AI

## Fase 1a — Sintético general (empezar aquí)

- **Objetivo:** pares instrucción→respuesta sobre DaVinci Resolve en ShareGPT.
- **Generador:** modelo en `config/ollama.json`.
- **System en datos:** `training/scripts/_resolve_system.py` → `RESOLVE_SYSTEM`.
- **Comandos:** `scripts/run_synthetic_general.ps1` o `generate_synthetic.py` + `process_dataset.py`.

## Fase 1b — Manual + PDF

1. `ingest_resolve_manual.py` — URLs en `config/resolve_manual_urls.txt`.
2. `generate_qa_from_manual.py --corpus resolve`.
3. PDFs en `data/raw/pdf/` → `ingest_pdf_manual.py` → `--corpus resolve_pdf`.
4. `process_dataset.py`.

## Fase 1c — Gemini

- `mejorarTrainning/generate_dataset_gemini.py` → `resolve_gemini_base.json`
- `mejorarTrainning/generar_conversaciones.py` → `multiturn.json`
- `mejorarTrainning/run_gemini_batch.ps1`

## Fase 2 — Fine-tuning

- Colab QLoRA → LoRA ZIP → `conversion/fusionar.py` → GGUF → `ollama create pygenesis-resolve`
