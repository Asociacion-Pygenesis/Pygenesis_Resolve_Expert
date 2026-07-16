"""Detección de tema de pregunta vs página activa en Resolve."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Literal

ContextMode = Literal["contextual", "matched", "general", "mismatch"]

PAGE_LABELS: dict[str, str] = {
    "media": "Media",
    "cut": "Cut",
    "edit": "Edit",
    "fusion": "Fusion",
    "color": "Color",
    "fairlight": "Fairlight",
    "deliver": "Deliver",
}

_EXPLICIT_PAGE_RE: dict[str, re.Pattern[str]] = {
    "media": re.compile(r"\b(?:p[aá]gina\s+)?media(?:\s+pool)?\b", re.IGNORECASE),
    "cut": re.compile(r"\b(?:p[aá]gina\s+)?cut\b", re.IGNORECASE),
    "edit": re.compile(r"\b(?:p[aá]gina\s+)?edit(?:ar|\s+page)?\b", re.IGNORECASE),
    "fusion": re.compile(r"\b(?:p[aá]gina\s+)?fusion\b", re.IGNORECASE),
    "color": re.compile(r"\b(?:p[aá]gina\s+)?color\b", re.IGNORECASE),
    "fairlight": re.compile(r"\b(?:p[aá]gina\s+)?fairlight\b", re.IGNORECASE),
    "deliver": re.compile(r"\b(?:p[aá]gina\s+)?deliver\b", re.IGNORECASE),
}

_TOPIC_SCORE_RE: list[tuple[str, re.Pattern[str]]] = [
    (
        "fusion",
        re.compile(
            r"\b(?:fusion|merge\s+node|delta\s+keyer|chroma\s+keyer|keyer|tracker\s+node|"
            r"composit(?:or|ing)|nodo\s+merge)\b",
            re.IGNORECASE,
        ),
    ),
    (
        "color",
        re.compile(
            r"\b(?:color\s+grad(?:e|ing)|qualifier|lut[s]?|scopes?|primari[ao]s?|secundari[ao]s?|"
            r"power\s+window|color\s+management|shot\s+match|colortrace|vectorscope|waveform)\b",
            re.IGNORECASE,
        ),
    ),
    (
        "fairlight",
        re.compile(
            r"\b(?:fairlight|bus(?:es)?|loudness|lufs|adr|foley|mezcla\s+de\s+audio|"
            r"ecualizador|eq\b)\b",
            re.IGNORECASE,
        ),
    ),
    (
        "deliver",
        re.compile(
            r"\b(?:deliver|render\s+queue|exportar|codec[s]?|entrega|renderizar|"
            r"preset\s+de\s+render|cola\s+de\s+render)\b",
            re.IGNORECASE,
        ),
    ),
    (
        "edit",
        re.compile(
            r"\b(?:timeline|insert|overwrite|replace|compound\s+clip|nested\s+timeline|"
            r"match\s+frame|marker[s]?|ripple\s+delete|multicam|trim|ripple|roll)\b",
            re.IGNORECASE,
        ),
    ),
    (
        "cut",
        re.compile(r"\b(?:p[aá]gina\s+cut|cut\s+page|source\s+tape)\b", re.IGNORECASE),
    ),
    (
        "media",
        re.compile(r"\b(?:media\s+pool|smart\s+bin[s]?|importar\s+clips?)\b", re.IGNORECASE),
    ),
]

_CONTEXTUAL_QUESTION_RE = re.compile(
    r"(?:"
    r"\b(?:aqu[ií]|ac[aá])\b"
    r"|\besta\s+p[aá]gina\b"
    r"|\ben\s+esta\b"
    r"|desde\s+aqu[ií]"
    r")",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class ContextAnalysis:
    mode: ContextMode
    pagina_activa: str | None
    tema_pregunta: str | None

    @property
    def hay_desajuste(self) -> bool:
        return self.mode == "mismatch"


def detectar_tema_pregunta(prompt: str) -> str | None:
    for page, pattern in _EXPLICIT_PAGE_RE.items():
        if pattern.search(prompt):
            return page

    scores: dict[str, int] = {}
    for page, pattern in _TOPIC_SCORE_RE:
        hits = pattern.findall(prompt)
        if hits:
            scores[page] = scores.get(page, 0) + len(hits)

    if not scores:
        return None
    return max(scores, key=scores.get)


def es_pregunta_contextual(prompt: str) -> bool:
    return bool(_CONTEXTUAL_QUESTION_RE.search(prompt))


def analizar_modo_contexto(
    prompt: str,
    pagina_activa: str | None,
    *,
    es_revision: bool = False,
) -> ContextAnalysis:
    if es_revision:
        tema = detectar_tema_pregunta(prompt)
        if es_pregunta_contextual(prompt) or not tema:
            return ContextAnalysis(
                mode="contextual",
                pagina_activa=pagina_activa,
                tema_pregunta=pagina_activa,
            )
        if pagina_activa and tema != pagina_activa:
            return ContextAnalysis(
                mode="mismatch",
                pagina_activa=pagina_activa,
                tema_pregunta=tema,
            )
        return ContextAnalysis(
            mode="matched",
            pagina_activa=pagina_activa,
            tema_pregunta=tema,
        )

    if es_pregunta_contextual(prompt):
        return ContextAnalysis(
            mode="contextual",
            pagina_activa=pagina_activa,
            tema_pregunta=pagina_activa,
        )

    tema = detectar_tema_pregunta(prompt)

    if not pagina_activa:
        return ContextAnalysis(mode="general", pagina_activa=None, tema_pregunta=tema)

    if tema is None:
        return ContextAnalysis(
            mode="general",
            pagina_activa=pagina_activa,
            tema_pregunta=None,
        )

    if tema == pagina_activa:
        return ContextAnalysis(
            mode="matched",
            pagina_activa=pagina_activa,
            tema_pregunta=tema,
        )

    return ContextAnalysis(
        mode="mismatch",
        pagina_activa=pagina_activa,
        tema_pregunta=tema,
    )


def pagina_para_revision(analysis: ContextAnalysis, prompt: str, es_revision: bool) -> str | None:
    if not es_revision:
        return None
    if es_pregunta_contextual(prompt) or analysis.mode in {"contextual", "matched"}:
        return analysis.pagina_activa
    if analysis.tema_pregunta:
        return analysis.tema_pregunta
    return analysis.pagina_activa
