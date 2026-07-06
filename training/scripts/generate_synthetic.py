"""
Genera pares ShareGPT con Ollama (/api/generate) para data/raw/synthetic/synthetic_qa.json.

Modelo: config/ollama.json (o ollama.example.json).

Uso:
  python scripts/generate_synthetic.py
  python scripts/generate_synthetic.py --max-concepts 0 --passes 3
"""

from __future__ import annotations

import argparse
import json
import random
import re
import sys
import time
from pathlib import Path

import requests
from tqdm import tqdm

from _resolve_system import OLLAMA_JSON_GENERATOR_SYSTEM, RESOLVE_SYSTEM
from _training_paths import load_json_config, ollama_api_base, training_root

RESOLVE_CONCEPTS = [
    "Proxies y optimized media en el Media Pool",
    "Ripple edit vs roll edit vs slip vs slide en la timeline",
    "Multicam editing y sincronización por audio",
    "Fusion: nodos Merge, Transform y MediaIn/MediaOut",
    "Color: primaries vs log wheels vs curves",
    "Qualifiers y power windows para aislar tonos de piel",
    "HDR grading y scopes (waveform, vectorscope, histogram)",
    "LUTs: input transform, creative LUT y export",
    "DaVinci YRGB color managed workflow",
    "Fairlight: buses, submix y sidechain",
    "Loudness (LUFS) y entrega para broadcast",
    "Deliver: ProRes vs H.264 vs H.265 para YouTube",
    "Frame rate y resolución en project settings",
    "Cache de Fusion y render en background",
    "Página Cut vs Edit: cuándo usar cada una",
    "Transiciones y cross dissolve en la timeline",
    "Speed change y retime con optical flow",
    "Noise reduction en Color (temporal vs spatial)",
    "Tracking en Fusion (point tracker vs planar)",
    "Resolve Free vs Studio: límites relevantes",
    "Collaboration y proyectos compartidos en red",
    "Import XML/AAF desde otros editores",
    "Subtitle tracks y export de subtítulos",
    "Audio sync y conformado de clips",
    "Node tree: serial vs parallel en Color",
    "Secondary corrections y fuera de gama",
    "Deliver presets para redes sociales",
    "GPU acceleration y preferencias de memoria",
    "Backup de proyectos y media management",
    "Resolve Scripting API (Python): conceptos básicos",
]

PROMPT_FROM_CONCEPT = """Genera exactamente 2 pares pregunta-respuesta de nivel intermedio sobre DaVinci Resolve:
{concept}
{extra}

Cada respuesta debe incluir pasos concretos en la interfaz de Resolve cuando aplique.
Formato EXACTO (solo esto, sin markdown):
[{{"question": "...", "answer": "..."}}, {{"question": "...", "answer": "..."}}]"""


def _parse_json_array(raw: str) -> list[dict]:
    s = raw.strip()
    if s.startswith("```"):
        parts = s.split("```")
        for p in parts:
            p = p.strip()
            if p.startswith("json"):
                p = p[4:].strip()
            if p.startswith("["):
                s = p
                break
    m = re.search(r"\[.*\]", s, re.DOTALL)
    if not m:
        raise ValueError("No se encontró array JSON")
    return json.loads(m.group(0))


def ask_ollama(
    *,
    host: str,
    model: str,
    prompt: str,
    system: str,
    think: bool,
    timeout: int,
) -> str:
    url = f"{host}/api/generate"
    payload = {
        "model": model,
        "prompt": prompt,
        "system": system,
        "stream": False,
        "think": think,
        "options": {"temperature": 0.65, "num_predict": 2048},
    }
    r = requests.post(url, json=payload, timeout=timeout)
    r.raise_for_status()
    return (r.json() or {}).get("response", "") or ""


def sharegpt_pair(question: str, answer: str, system: str) -> dict:
    return {
        "conversations": [
            {"from": "system", "value": system},
            {"from": "human", "value": question.strip()},
            {"from": "gpt", "value": answer.strip()},
        ]
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Generación sintética ShareGPT vía Ollama (Resolve)")
    ap.add_argument("--max-concepts", type=int, default=0, help="0 = todos los conceptos")
    ap.add_argument("--passes", type=int, default=1, help="Pasadas sobre la lista (barajada)")
    ap.add_argument("--timeout", type=int, default=240)
    ap.add_argument("--sleep", type=float, default=0.0)
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--append", action="store_true")
    ap.add_argument("--think", action="store_true")
    args = ap.parse_args()

    if args.seed is not None:
        random.seed(args.seed)

    root = training_root()
    cfg = load_json_config("ollama.json")
    host = ollama_api_base(cfg.get("base_url", "http://127.0.0.1:11434"))
    model = cfg["model"]
    think = args.think or bool(cfg.get("think", False))

    out_dir = root / "data" / "raw" / "synthetic"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "synthetic_qa.json"

    dataset_system = RESOLVE_SYSTEM
    ollama_system = OLLAMA_JSON_GENERATOR_SYSTEM
    all_rows: list[dict] = []
    if args.append and out_path.is_file():
        with open(out_path, encoding="utf-8") as f:
            prev = json.load(f)
        if isinstance(prev, list):
            all_rows.extend(prev)

    n_all = len(RESOLVE_CONCEPTS)
    cap = args.max_concepts if args.max_concepts > 0 else n_all
    cap = min(cap, n_all)
    passes = max(1, int(args.passes))

    for pass_i in range(passes):
        batch = list(RESOLVE_CONCEPTS)
        random.shuffle(batch)
        batch = batch[:cap]
        extra = ""
        if passes > 1:
            extra = f"\n(Pasada {pass_i + 1}/{passes}: plantea ángulos distintos a un tutorial genérico.)"
        desc = f"Conceptos p{pass_i + 1}/{passes}"
        for concept in tqdm(batch, desc=desc):
            prompt = PROMPT_FROM_CONCEPT.format(concept=concept, extra=extra)
            try:
                raw = ask_ollama(
                    host=host,
                    model=model,
                    prompt=prompt,
                    system=ollama_system,
                    think=think,
                    timeout=args.timeout,
                )
                for pair in _parse_json_array(raw):
                    q, a = pair.get("question"), pair.get("answer")
                    if isinstance(q, str) and isinstance(a, str) and len(q) > 10 and len(a) > 40:
                        all_rows.append(sharegpt_pair(q, a, dataset_system))
            except (requests.RequestException, ValueError, json.JSONDecodeError, KeyError) as e:
                print(f"Saltado concepto {concept!r}: {e}", file=sys.stderr)
            if args.sleep > 0:
                time.sleep(args.sleep)

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(all_rows, f, indent=2, ensure_ascii=False)

    print(f"Modelo={model!r} think={think} | Guardado {len(all_rows)} conversaciones en {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
