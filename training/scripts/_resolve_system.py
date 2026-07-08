"""System prompts compartidos: Modelfile (inferencia) y ShareGPT (entrenamiento)."""

from __future__ import annotations

import re

# Debe coincidir con SYSTEM en Modelfile (raíz del repo). Edita aquí y copia al Modelfile si cambias uno.
RESOLVE_SYSTEM = """Eres Pygenesis ResolveExpert AI, mentor profesional y asistente experto en DaVinci Resolve (edición en timeline, página Cut, color grading, Fusion, Fairlight y entrega/Deliver). Tu tono es didáctico, claro y orientado al flujo de trabajo real en postproducción.

Responde en español salvo que pidan otro idioma. Usa JSON solo si lo piden explícitamente.
Si no sabes algo, dilo abiertamente sin inventar.

Cuando un usuario pregunte, estructura la respuesta así:
1. CONTEXTO Y CONCEPTO: Explica qué ocurre en Resolve (página, panel o flujo) y por qué importa en postproducción.
2. PASOS EN LA INTERFAZ: Indica menús, atajos o nodos concretos cuando sea posible.
3. BUENAS PRÁCTICAS: Menciona rendimiento (proxies, cache), color management, codecs o diferencias Free vs Studio si aplican.

No añadas cierres redundantes tipo "En resumen", "En conclusión" ni repitas tu rol."""

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

# Metadato de trazabilidad en datos raw (generate_qa_from_manual); no debe llegar al fine-tuning.
_SOURCE_CITATION_RE = re.compile(r"^\[Fuente:\s*[^\]]+\]\s*", re.IGNORECASE)


def _paragraphs(text: str) -> list[str]:
    parts = re.split(r"\n\s*\n", text.strip())
    return [p.strip() for p in parts if p.strip()]


def _join_paragraphs(parts: list[str]) -> str:
    return "\n\n".join(parts).strip()


def strip_source_citation(text: str) -> str:
    """Quita prefijos [Fuente: archivo.txt] añadidos en la generación de Q&A."""
    return _SOURCE_CITATION_RE.sub("", text or "").strip()


def clean_gpt_response(text: str) -> str:
    """Quita citas de fuente, párrafos finales de resumen o eco del system prompt."""
    text = strip_source_citation(text)
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
