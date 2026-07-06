"""System prompts compartidos: Modelfile (inferencia) y ShareGPT (entrenamiento)."""

from __future__ import annotations

import re

# Debe coincidir con SYSTEM en Modelfile (raíz del repo).
RESOLVE_SYSTEM = """Eres Pygenesis ResolveExpert AI, asistente experto en DaVinci Resolve (edición, Color, Fusion, Fairlight y Deliver).

Responde en español salvo que pidan otro idioma. Usa JSON solo si lo piden explícitamente.
Explica pasos concretos en la interfaz de Resolve (páginas Edit, Cut, Fusion, Color, Fairlight, Deliver).
Diferencia Resolve Free vs Studio cuando importe. Si no sabes algo, dilo sin inventar.

Termina cuando la pregunta esté resuelta. No añadas cierres tipo "En resumen", "En conclusión" ni repitas tu rol."""

# Solo para llamadas Ollama que generan JSON; no guardar en el dataset.
OLLAMA_JSON_GENERATOR_SYSTEM = (
    "Eres un generador de datos de entrenamiento. "
    "Respondes únicamente con JSON válido según el esquema del mensaje del usuario. "
    "Sin markdown, sin texto antes ni después del JSON."
)

_CLOSING_START_RE = re.compile(
    r"^\s*(?:"
    r"en\s+resumen\b"
    r"|en\s+conclusión\b"
    r"|para\s+resumir\b"
    r"|resumiendo\b"
    r"|como\s+resumen\b"
    r"|en\s+síntesis\b"
    r"|en\s+sintesis\b"
    r")",
    re.IGNORECASE,
)

_ROLE_ECHO_RE = re.compile(
    r"\b(?:eres|soy)\s+(?:pygenesis\s+)?resolveexpert\b|orientado\s+a\s+soluciones",
    re.IGNORECASE,
)


def _paragraphs(text: str) -> list[str]:
    parts = re.split(r"\n\s*\n", text.strip())
    return [p.strip() for p in parts if p.strip()]


def _join_paragraphs(parts: list[str]) -> str:
    return "\n\n".join(parts).strip()


def clean_gpt_response(text: str) -> str:
    """Quita párrafos finales de resumen o eco del system prompt."""
    parts = _paragraphs(text)
    if not parts:
        return text.strip()

    changed = True
    while len(parts) > 1 and changed:
        changed = False
        last = parts[-1]
        if _CLOSING_START_RE.match(last) or _ROLE_ECHO_RE.search(last):
            parts.pop()
            changed = True

    return _join_paragraphs(parts)


def normalize_sharegpt_system(item: dict) -> dict:
    """Unifica system y limpia respuestas gpt (sin cierres de resumen/rol)."""
    for turn in item.get("conversations") or []:
        if turn.get("from") == "system":
            turn["value"] = RESOLVE_SYSTEM
        elif turn.get("from") == "gpt":
            turn["value"] = clean_gpt_response(turn.get("value") or "")
    return item
