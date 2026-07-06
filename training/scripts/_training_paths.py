"""Rutas y carga de config locales del proyecto training/."""

from __future__ import annotations

import json
from pathlib import Path


def training_root() -> Path:
    return Path(__file__).resolve().parent.parent


def load_json_config(name: str) -> dict:
    root = training_root()
    for fname in (name, name.replace(".json", ".example.json")):
        path = root / "config" / fname
        if path.is_file():
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
            return {k: v for k, v in data.items() if not str(k).startswith("_")}
    raise FileNotFoundError(f"No existe config/{name} ni .example en {root}")


def ollama_api_base(base_url: str) -> str:
    """http://host:11434/v1 -> http://host:11434 para /api/generate."""
    b = (base_url or "").rstrip("/")
    if b.endswith("/v1"):
        b = b[:-3]
    return b.rstrip("/")
