"""Prueba rápida del puente de inferencia (sin Ollama)."""

from __future__ import annotations

import httpx

BRIDGE_URL = "http://localhost:8000"


def consultar_puente(prompt: str, contexto_proyecto: str = "") -> str:
    response = httpx.post(
        f"{BRIDGE_URL}/consultar",
        json={
            "prompt": prompt,
            "contexto_proyecto": contexto_proyecto,
            "modo_json": False,
        },
        timeout=300,
    )
    response.raise_for_status()
    return response.json().get("respuesta", "")


if __name__ == "__main__":
    health = httpx.get(f"{BRIDGE_URL}/health", timeout=5).json()
    print("Health:", health)

    if not health.get("model_loaded"):
        raise SystemExit(
            "Modelo no cargado. Ejecuta installer\\install_pygenesis.ps1 "
            "o coloca pygenesis-resolve-q4km.gguf en %LOCALAPPDATA%\\Pygenesis\\models\\"
        )

    respuesta = consultar_puente(
        "¿Cómo configuro proxies en DaVinci Resolve para editar material 4K?"
    )
    print("\n--- RESPUESTA FINAL ---")
    print(respuesta)
