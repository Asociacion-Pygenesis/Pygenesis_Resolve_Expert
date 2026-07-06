"""
Genera conversaciones ShareGPT a partir de .txt ya ingeridos (manual Resolve o PDF).

Uso:
  python scripts/ingest_resolve_manual.py --max-pages 15
  python scripts/generate_qa_from_manual.py --max-chunks 40
  python scripts/ingest_pdf_manual.py
  python scripts/generate_qa_from_manual.py --corpus resolve_pdf --max-chunks 40 --sleep 0.5
  python scripts/process_dataset.py
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from pathlib import Path

import requests
from tqdm import tqdm

from _resolve_system import OLLAMA_JSON_GENERATOR_SYSTEM, RESOLVE_SYSTEM
from _training_paths import load_json_config, ollama_api_base, training_root


def _parse_json_array(raw: str) -> list[dict]:
    s = raw.strip()
    if s.startswith("```"):
        for part in s.split("```"):
            p = part.strip()
            if p.startswith("json"):
                p = p[4:].strip()
            if p.startswith("["):
                s = p
                break
    m = re.search(r"\[.*\]", s, re.DOTALL)
    if not m:
        raise ValueError("sin array JSON")
    data = json.loads(m.group(0))
    if isinstance(data, dict):
        return [data]
    return data


def ask_ollama(host: str, model: str, prompt: str, system: str, think: bool, timeout: int) -> str:
    url = f"{host}/api/generate"
    payload = {
        "model": model,
        "prompt": prompt,
        "system": system,
        "stream": False,
        "think": think,
        "options": {"temperature": 0.5, "num_predict": 1200},
    }
    r = requests.post(url, json=payload, timeout=timeout)
    r.raise_for_status()
    return (r.json() or {}).get("response", "") or ""


def chunk_text(text: str, max_chars: int, overlap: int) -> list[str]:
    text = text.strip()
    if len(text) <= max_chars:
        return [text] if text else []
    chunks: list[str] = []
    start = 0
    while start < len(text):
        end = min(len(text), start + max_chars)
        piece = text[start:end].strip()
        if len(piece) > 200:
            chunks.append(piece)
        if end >= len(text):
            break
        start = max(0, end - overlap)
    return chunks


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--corpus",
        choices=("resolve", "resolve_pdf"),
        default="resolve",
        help="resolve=docs web; resolve_pdf=PDFs en resolve-pdf-txt",
    )
    ap.add_argument("--chunk-size", type=int, default=2200)
    ap.add_argument("--overlap", type=int, default=200)
    ap.add_argument("--max-chunks", type=int, default=0)
    ap.add_argument("--timeout", type=int, default=240)
    ap.add_argument("--sleep", type=float, default=0.5)
    ap.add_argument("--think", action="store_true")
    ap.add_argument("--append", action="store_true")
    args = ap.parse_args()

    root = training_root()
    if args.corpus == "resolve":
        txt_dir = root / "data" / "processed" / "resolve-manual-txt"
        out_name = "manual_qa_sharegpt.json"
        fragment_title = (
            "Fragmento de documentación DaVinci Resolve (solo referencia; "
            "no inventes pasos o menús que no aparezcan aquí)"
        )
        ingest_hint = "ingest_resolve_manual.py (config/resolve_manual_urls.txt)"
    else:
        txt_dir = root / "data" / "processed" / "resolve-pdf-txt"
        out_name = "pdf_manual_qa_sharegpt.json"
        fragment_title = (
            "Fragmento de manual PDF de DaVinci Resolve (solo referencia; "
            "no inventes pasos que no aparezcan aquí)"
        )
        ingest_hint = "ingest_pdf_manual.py (data/raw/pdf/*.pdf)"

    if not txt_dir.is_dir() or not any(txt_dir.glob("*.txt")):
        print("No hay .txt en", txt_dir, f"— ejecuta antes {ingest_hint}", file=sys.stderr)
        return 1

    cfg = load_json_config("ollama.json")
    host = ollama_api_base(cfg.get("base_url", "http://127.0.0.1:11434"))
    model = cfg["model"]
    think = args.think or bool(cfg.get("think", False))

    all_chunks: list[tuple[str, str]] = []
    for path in sorted(txt_dir.glob("*.txt")):
        body = path.read_text(encoding="utf-8", errors="ignore")
        for ch in chunk_text(body, args.chunk_size, args.overlap):
            all_chunks.append((path.name, ch))

    if args.max_chunks > 0:
        all_chunks = all_chunks[: args.max_chunks]

    out_path = root / "data" / "raw" / "synthetic" / out_name
    out_path.parent.mkdir(parents=True, exist_ok=True)
    rows: list[dict] = []
    if args.append and out_path.is_file():
        rows = json.loads(out_path.read_text(encoding="utf-8"))

    prompt_tpl = """{title}:
---
{chunk}
---

Genera exactamente 1 par pregunta-respuesta técnica en español sobre DaVinci Resolve basado en este fragmento.
Responde SOLO con este JSON (un elemento en el array, sin markdown ni texto extra):
[{{"question":"...","answer":"..."}}]
Usa comillas dobles JSON válidas (escapa comillas internas con \\")."""

    desc = "Manual Resolve->Q&A" if args.corpus == "resolve" else "PDF Resolve->Q&A"
    for fname, chunk in tqdm(all_chunks, desc=desc):
        prompt = prompt_tpl.format(title=fragment_title, chunk=chunk[:8000])
        try:
            raw = ask_ollama(
                host, model, prompt, OLLAMA_JSON_GENERATOR_SYSTEM, think, args.timeout
            )
            pairs = _parse_json_array(raw)
            for pair in pairs:
                q = pair.get("question")
                a = pair.get("answer")
                if isinstance(q, str) and isinstance(a, str) and len(q) > 15 and len(a) > 60:
                    rows.append(
                        {
                            "conversations": [
                                {"from": "system", "value": RESOLVE_SYSTEM},
                                {"from": "human", "value": q.strip()},
                                {"from": "gpt", "value": f"[Fuente: {fname}]\n{a.strip()}"},
                            ]
                        }
                    )
        except (requests.RequestException, ValueError, json.JSONDecodeError, KeyError) as e:
            tqdm.write(f"Saltado {fname}: {e}")
        if args.sleep > 0:
            time.sleep(args.sleep)

    out_path.write_text(json.dumps(rows, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Guardado {len(rows)} conversaciones en {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
