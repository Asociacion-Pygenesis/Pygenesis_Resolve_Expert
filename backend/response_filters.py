"""Filtros post-proceso para respuestas de Ollama (thinking, citas de fuente, etc.)."""

from __future__ import annotations

import re

_THINKING_BLOCK_RE = re.compile(
    r"<think>.*?</think>",
    re.DOTALL | re.IGNORECASE,
)

# [Fuente: manual.txt], [Fuente manual: X.txt], variantes al inicio de la respuesta.
_FUENTE_LINE_RE = re.compile(
    r"^\s*\[Fuente(?:\s+manual)?\s*:[^\]]+\]\s*",
    re.IGNORECASE | re.MULTILINE,
)


def filtrar_thinking(texto: str) -> str:
    """Elimina bloques de thinking si el modelo los genera."""
    texto = _THINKING_BLOCK_RE.sub("", texto)
    if "</think>" in texto:
        texto = texto.split("</think>")[-1]
    return texto.strip()


def limpiar_citas_fuente(texto: str) -> str:
    """Quita prefijos [Fuente: ...] o [Fuente manual: ...] al inicio de la respuesta."""
    texto = texto.strip()
    while True:
        nuevo = _FUENTE_LINE_RE.sub("", texto, count=1)
        if nuevo == texto:
            break
        texto = nuevo.strip()
    return texto.strip()


def limpiar_respuesta_modelo(texto: str) -> str:
    """Pipeline completo: thinking → citas de fuente → trim."""
    return limpiar_citas_fuente(filtrar_thinking(texto))
