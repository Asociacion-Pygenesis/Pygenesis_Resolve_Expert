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
            if p.startswith(("[", "{")):
                s = p
                break
    candidates: list = []
    m = re.search(r"\[.*\]", s, re.DOTALL)
    if m:
        try:
            candidates.append(json.loads(m.group(0)))
        except json.JSONDecodeError:
            pass
    if s.startswith("{"):
        try:
            candidates.append(json.loads(s))
        except json.JSONDecodeError:
            pass
    pairs: list[dict] = []
    for data in candidates:
        items = data if isinstance(data, list) else [data]
        for item in items:
            if isinstance(item, dict) and "question" in item and "answer" in item:
                pairs.append(item)
    if pairs:
        return pairs
    # Fallback: extraer question/answer con regex si el JSON viene mal cerrado
    qm = re.search(r'"question"\s*:\s*"((?:[^"\\]|\\.)*)"', s, re.DOTALL)
    am = re.search(r'"answer"\s*:\s*"((?:[^"\\]|\\.)*)"', s, re.DOTALL)
    if qm and am:
        return [
            {
                "question": json.loads(f'"{qm.group(1)}"'),
                "answer": json.loads(f'"{am.group(1)}"'),
            }
        ]
    raise ValueError("sin array JSON")


def _save_rows(path: Path, rows: list[dict]) -> None:
    path.write_text(json.dumps(rows, indent=2, ensure_ascii=False), encoding="utf-8")


def ask_ollama(host: str, model: str, prompt: str, system: str, think: bool, timeout: int) -> str:
    url = f"{host}/api/generate"
    payload = {
        "model": model,
        "prompt": prompt,
        "system": system,
        "stream": False,
        "think": think,
        "format": "json",
        "options": {"temperature": 0.3, "num_predict": 2000},
    }
    r = requests.post(url, json=payload, timeout=timeout)
    r.raise_for_status()
    return (r.json() or {}).get("response", "") or ""


_SKIP_CHUNK_RE = re.compile(
    r"(all rights reserved|isbn\s+\d|blackmagic design|www\.blackmagicdesign\.com|"
    r"table of contents|índice|indice\b|notice of rights)",
    re.IGNORECASE,
)


def is_usable_chunk(text: str) -> bool:
    """Evita portadas, copyright e índices con poco contenido técnico."""
    if len(text.strip()) < 400:
        return False
    hits = len(_SKIP_CHUNK_RE.findall(text[:1200]))
    return hits < 2


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
    ap.add_argument(
        "--skip-chunks",
        type=int,
        default=0,
        help="Saltar los primeros N fragmentos (reanudar tras fallo)",
    )
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
        ingest_hint = "ingest_pdf_manual.py (fuentesTrainning/*.pdf)"

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
            if is_usable_chunk(ch):
                all_chunks.append((path.name, ch))

    if args.max_chunks > 0:
        all_chunks = all_chunks[: args.max_chunks]
    if args.skip_chunks > 0:
        all_chunks = all_chunks[args.skip_chunks :]

    out_path = root / "data" / "raw" / "synthetic" / out_name
    out_path.parent.mkdir(parents=True, exist_ok=True)
    rows: list[dict] = []
    if (args.append or args.skip_chunks > 0) and out_path.is_file():
        rows = json.loads(out_path.read_text(encoding="utf-8"))

    prompt_tpl = """{title}:
---
{chunk}
---

Genera exactamente 1 par pregunta-respuesta técnica en español sobre DaVinci Resolve basado en este fragmento.
Responde SOLO con este JSON (objeto, sin markdown ni texto extra):
{{"question":"...","answer":"..."}}
La respuesta debe tener pasos concretos (mínimo 3 frases). Usa comillas dobles JSON válidas."""

    desc = "Manual Resolve->Q&A" if args.corpus == "resolve" else "PDF Resolve->Q&A"
    for fname, chunk in tqdm(all_chunks, desc=desc):
        prompt = prompt_tpl.format(title=fragment_title, chunk=chunk[:8000])
        try:
            raw = ask_ollama(
                host, model, prompt, OLLAMA_JSON_GENERATOR_SYSTEM, think, args.timeout
            )
            pairs = _parse_json_array(raw)
            for pair in pairs:
                if not isinstance(pair, dict):
                    continue
                q = pair.get("question")
                a = pair.get("answer")
                if isinstance(q, str) and isinstance(a, str) and len(q) > 15 and len(a) > 60:
                    rows.append(
                        {
                            "source_file": fname,
                            "conversations": [
                                {"from": "system", "value": RESOLVE_SYSTEM},
                                {"from": "human", "value": q.strip()},
                                {"from": "gpt", "value": a.strip()},
                            ],
                        }
                    )
                    _save_rows(out_path, rows)
        except (requests.RequestException, ValueError, json.JSONDecodeError, KeyError, AttributeError) as e:
            tqdm.write(f"Saltado {fname}: {e}")
        if args.sleep > 0:
            time.sleep(args.sleep)

    _save_rows(out_path, rows)
    print(f"Guardado {len(rows)} conversaciones en {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
