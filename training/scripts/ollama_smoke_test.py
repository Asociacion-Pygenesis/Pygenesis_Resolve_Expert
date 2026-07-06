"""
Prueba rápida de Ollama con think=false (recomendado para Qwen 3 y similares).
Uso (con venv activado): python scripts/ollama_smoke_test.py [mensaje]
"""
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from pathlib import Path


def _load_config() -> dict:
    root = Path(__file__).resolve().parent.parent
    for name in ("ollama.json", "ollama.example.json"):
        path = root / "config" / name
        if path.exists():
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
            return {k: v for k, v in data.items() if not k.startswith("_")}
    raise FileNotFoundError("Crea training/config/ollama.json (copia de ollama.example.json)")


def main() -> int:
    prompt = " ".join(sys.argv[1:]).strip() or "Responde exactamente la palabra: ok"
    cfg = _load_config()
    base = cfg.get("base_url", "http://127.0.0.1:11434").rstrip("/")
    model = cfg["model"]
    use_think = cfg.get("think", False)

    url = f"{base}/api/generate"
    body = {
        "model": model,
        "prompt": prompt,
        "stream": False,
        "think": use_think,
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            out = json.loads(resp.read().decode("utf-8"))
    except urllib.error.URLError as e:
        print("Error de red:", e)
        return 1

    text = (out.get("response") or "").strip()
    print("model:", model, "| think en petición:", use_think)
    print("respuesta:", repr(text)[:500])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
