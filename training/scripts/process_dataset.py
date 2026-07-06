"""
Une fuentes raw en ShareGPT limpio: data/train/resolve_train.json y data/eval/resolve_eval.json.

Fuentes soportadas:
  - data/raw/synthetic/synthetic_qa.json (salida de generate_synthetic.py)
  - data/raw/synthetic/manual_qa_sharegpt.json (Resolve; generate_qa_from_manual.py)
  - data/raw/synthetic/pdf_manual_qa_sharegpt.json (PDF Resolve; --corpus resolve_pdf)
  - data/raw/gemini/*.json (salida de mejorarTrainning/*)
  - data/raw/stackoverflow/resolve_qa.json (opcional)

Uso:
  python scripts/process_dataset.py
  python scripts/process_dataset.py --eval-ratio 0.15
"""

from __future__ import annotations

import argparse
import json
import random
import re
import sys
from pathlib import Path

from _resolve_system import RESOLVE_SYSTEM, normalize_sharegpt_system
from _training_paths import training_root


def _strip_html(t: str) -> str:
    return re.sub(r"<[^>]+>", "", t or "")


def load_stackoverflow(path: Path) -> list[dict]:
    if not path.is_file():
        return []
    with open(path, encoding="utf-8") as f:
        items = json.load(f)
    system = RESOLVE_SYSTEM
    out: list[dict] = []
    for item in items:
        q = _strip_html(item.get("question", ""))
        a = _strip_html(item.get("answer", ""))
        if len(q) < 20 or len(a) < 50:
            continue
        out.append(
            {
                "conversations": [
                    {"from": "system", "value": system},
                    {"from": "human", "value": q.strip()},
                    {"from": "gpt", "value": a.strip()},
                ]
            }
        )
    return out


def load_synthetic(path: Path) -> list[dict]:
    if not path.is_file():
        return []
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def load_json_dir(path: Path) -> list[dict]:
    if not path.is_dir():
        return []
    rows: list[dict] = []
    for file_path in sorted(path.glob("*.json")):
        rows.extend(load_synthetic(file_path))
    return rows


def is_valid(item: dict) -> bool:
    convs = item.get("conversations") or []
    if len(convs) < 3:
        return False
    human = next((c["value"] for c in convs if c.get("from") == "human"), "")
    gpt = next((c["value"] for c in convs if c.get("from") == "gpt"), "")
    if len(human) < 20 or len(gpt) < 80:
        return False
    if len(gpt) > 8000:
        return False
    return True


def dedupe(items: list[dict]) -> list[dict]:
    seen: set[str] = set()
    out: list[dict] = []
    for item in items:
        convs = item.get("conversations") or []
        human = next((c["value"] for c in convs if c.get("from") == "human"), "")
        key = human[:120].lower().strip()
        if key in seen:
            continue
        seen.add(key)
        out.append(item)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--eval-ratio", type=float, default=0.15, help="Fracción para eval (0–0.5)")
    ap.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Semilla para mezclar antes del split train/eval.",
    )
    args = ap.parse_args()
    ratio = min(0.5, max(0.05, float(args.eval_ratio)))

    root = training_root()
    raw_syn = root / "data" / "raw" / "synthetic" / "synthetic_qa.json"
    raw_manual = root / "data" / "raw" / "synthetic" / "manual_qa_sharegpt.json"
    raw_pdf = root / "data" / "raw" / "synthetic" / "pdf_manual_qa_sharegpt.json"
    raw_gemini = root / "data" / "raw" / "gemini"
    raw_so = root / "data" / "raw" / "stackoverflow" / "resolve_qa.json"

    all_data: list[dict] = []
    all_data.extend(load_synthetic(raw_syn))
    all_data.extend(load_synthetic(raw_manual))
    all_data.extend(load_synthetic(raw_pdf))
    all_data.extend(load_json_dir(raw_gemini))
    all_data.extend(load_stackoverflow(raw_so))

    if not all_data:
        print(
            "No hay datos: generate_synthetic.py, generate_qa_from_manual.py "
            "(resolve/resolve_pdf), mejorarTrainning/*, o resolve_qa.json.",
            file=sys.stderr,
        )
        return 1

    filtered = [normalize_sharegpt_system(d) for d in all_data if is_valid(d)]
    deduped = dedupe(filtered)

    rng = random.Random(args.seed)
    rng.shuffle(deduped)

    split_idx = max(1, int(len(deduped) * (1.0 - ratio)))
    train_data = deduped[:split_idx]
    eval_data = deduped[split_idx:] or deduped[-1:]

    train_dir = root / "data" / "train"
    eval_dir = root / "data" / "eval"
    train_dir.mkdir(parents=True, exist_ok=True)
    eval_dir.mkdir(parents=True, exist_ok=True)

    train_path = train_dir / "resolve_train.json"
    eval_path = eval_dir / "resolve_eval.json"
    with open(train_path, "w", encoding="utf-8") as f:
        json.dump(train_data, f, indent=2, ensure_ascii=False)
    with open(eval_path, "w", encoding="utf-8") as f:
        json.dump(eval_data, f, indent=2, ensure_ascii=False)

    print(f"Train: {len(train_data)} -> {train_path}")
    print(f"Eval:  {len(eval_data)} -> {eval_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
