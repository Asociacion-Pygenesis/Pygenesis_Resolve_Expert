"""Helpers compartidos para generar y mejorar datasets con Gemini.

La Gema se replica pasando su prompt como system_instruction. El dataset
entrenable siempre guarda RESOLVE_SYSTEM para mantenerlo alineado con Ollama.
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Any

from google import genai
from google.genai import types

TRAINING_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = TRAINING_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from _resolve_system import RESOLVE_SYSTEM, normalize_sharegpt_system  # noqa: E402
from _training_paths import training_root  # noqa: E402


GEMINI_SYSTEM_PROMPT = """Eres una Gema especializada en DaVinci Resolve para Pygenesis ResolveExpert AI.
Tu objetivo es generar respuestas de alta calidad para entrenar un asistente experto en postproducción.

Cuando respondas:
- Responde siempre en español salvo que el usuario pida otro idioma.
- Sé práctico y preciso; resuelve la pregunta de principio a fin.
- Usa terminología correcta de Resolve: Media Pool, timeline, nodes, Fusion, scopes, Deliver, Fairlight.
- Indica pasos en la interfaz (página Edit, Color, Fusion, etc.) cuando sea posible.
- Diferencia Resolve Free vs Studio si aplica.
- No inventes menús o funciones. Si no estás seguro, indícalo.
- No uses markdown JSON salvo que el usuario pida JSON explícitamente.
- No cierres con "En resumen", "En conclusión", "Para resumir" ni frases sobre tu rol.
- El último párrafo debe ser contenido útil (paso, ajuste o consejo concreto), no un meta-resumen.
"""


DEFAULT_MODEL = "gemini-2.5-flash"
# Free tier gemini-2.5-flash: ~5 RPM. Plus/paid en AI Studio suele ser mucho mayor (mira tu panel).
DEFAULT_FREE_TIER_RPM = 5
DEFAULT_PLUS_TIER_RPM = 30  # conservador; sube si AI Studio muestra RPM mas alto
DEFAULT_MIN_INTERVAL_SEC = 60.0 / DEFAULT_FREE_TIER_RPM + 1.0

TIER_PRESETS: dict[str, dict[str, float]] = {
    "free": {"rpm": DEFAULT_FREE_TIER_RPM, "sleep_extra": 2.0},
    "plus": {"rpm": DEFAULT_PLUS_TIER_RPM, "sleep_extra": 0.5},
}


def resolve_tier(tier: str | None = None) -> str:
    raw = (tier or os.environ.get("GEMINI_TIER") or "free").strip().lower()
    return raw if raw in TIER_PRESETS else "free"


def tier_rpm(tier: str, rpm_override: float | None = None) -> float:
    if rpm_override is not None and rpm_override > 0:
        return rpm_override
    return TIER_PRESETS[resolve_tier(tier)]["rpm"]


def tier_sleep_extra(tier: str, sleep_override: float | None = None) -> float:
    if sleep_override is not None and sleep_override >= 0:
        return sleep_override
    return TIER_PRESETS[resolve_tier(tier)]["sleep_extra"]


def rate_limiter_for_tier(tier: str, rpm: float | None = None) -> GeminiRateLimiter:
    return GeminiRateLimiter.from_rpm(tier_rpm(tier, rpm))


class GeminiRateLimiter:
    """Espacia llamadas para no superar RPM del plan gratuito."""

    def __init__(self, min_interval_sec: float = DEFAULT_MIN_INTERVAL_SEC) -> None:
        self.min_interval_sec = max(0.0, min_interval_sec)
        self._last_call_at = 0.0

    def wait(self) -> None:
        if self.min_interval_sec <= 0:
            return
        elapsed = time.monotonic() - self._last_call_at
        if elapsed < self.min_interval_sec:
            time.sleep(self.min_interval_sec - elapsed)

    def mark_called(self) -> None:
        self._last_call_at = time.monotonic()

    @classmethod
    def from_rpm(cls, rpm: float) -> GeminiRateLimiter:
        rpm = max(0.1, rpm)
        return cls(60.0 / rpm + 0.5)


def _parse_retry_seconds(exc: BaseException, *, fallback_sec: float = DEFAULT_MIN_INTERVAL_SEC) -> float | None:
    text = str(exc)
    m = re.search(r"retry in (\d+(?:\.\d+)?)s", text, re.I)
    if m:
        return float(m.group(1))
    m = re.search(r"'retryDelay':\s*'(\d+)s'", text)
    if m:
        return float(m.group(1))
    if "429" in text or "RESOURCE_EXHAUSTED" in text:
        return fallback_sec
    return None


def _is_rate_limit_error(exc: BaseException) -> bool:
    text = str(exc)
    return "429" in text or "RESOURCE_EXHAUSTED" in text or "quota" in text.lower()


def raw_gemini_dir() -> Path:
    out = training_root() / "data" / "raw" / "gemini"
    out.mkdir(parents=True, exist_ok=True)
    return out


def load_json(path: Path) -> list[dict[str, Any]]:
    if not path.is_file():
        return []
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(rows, indent=2, ensure_ascii=False), encoding="utf-8")


def gemini_client() -> genai.Client:
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError(
            "Falta GEMINI_API_KEY. En PowerShell: "
            '$env:GEMINI_API_KEY = "tu_clave_de_google_ai_studio"'
        )
    return genai.Client(api_key=api_key)


def call_gemini(
    prompt: str | list[types.Content],
    *,
    client: genai.Client | None = None,
    model: str = DEFAULT_MODEL,
    system_instruction: str = GEMINI_SYSTEM_PROMPT,
    temperature: float = 0.7,
    max_output_tokens: int = 2048,
    retries: int = 6,
    retry_base_sleep: float = 2.0,
    rate_limit_429_min_wait: float = 0.0,
    rate_limiter: GeminiRateLimiter | None = None,
    min_interval_sec: float | None = None,
) -> str | None:
    client = client or gemini_client()
    if rate_limiter is None:
        interval = DEFAULT_MIN_INTERVAL_SEC if min_interval_sec is None else min_interval_sec
        rate_limiter = GeminiRateLimiter(interval)

    for attempt in range(retries):
        rate_limiter.wait()
        try:
            response = client.models.generate_content(
                model=model,
                config=types.GenerateContentConfig(
                    system_instruction=system_instruction,
                    temperature=temperature,
                    max_output_tokens=max_output_tokens,
                ),
                contents=prompt,
            )
            rate_limiter.mark_called()
            text = (response.text or "").strip()
            return text or None
        except Exception as exc:  # SDK/network/rate limit errors vary by version.
            if _is_rate_limit_error(exc):
                wait_s = _parse_retry_seconds(
                    exc, fallback_sec=rate_limiter.min_interval_sec
                ) or rate_limiter.min_interval_sec
                wait_s = max(
                    wait_s,
                    rate_limiter.min_interval_sec,
                    rate_limit_429_min_wait,
                ) + 1.0
                print(
                    f"Cuota Gemini (429): esperando {wait_s:.0f}s antes de reintentar "
                    f"({attempt + 1}/{retries})...",
                    file=sys.stderr,
                )
                time.sleep(wait_s)
                rate_limiter.mark_called()
                continue
            print(f"Gemini error intento {attempt + 1}/{retries}: {exc}", file=sys.stderr)
            if attempt + 1 < retries:
                time.sleep(retry_base_sleep * (2**attempt))
    return None


def sharegpt_item(
    question: str,
    answer: str,
    *,
    metadata: dict[str, Any] | None = None,
    system: str = RESOLVE_SYSTEM,
) -> dict[str, Any]:
    item: dict[str, Any] = {
        "conversations": [
            {"from": "system", "value": system.strip()},
            {"from": "human", "value": question.strip()},
            {"from": "gpt", "value": answer.strip()},
        ]
    }
    if metadata:
        item["metadata"] = metadata
    return normalize_sharegpt_system(item)


def is_good_answer(answer: str | None, *, min_chars: int = 100, max_chars: int = 8000) -> bool:
    if not answer:
        return False
    n = len(answer.strip())
    return min_chars <= n <= max_chars


def load_existing_if_append(path: Path, append: bool) -> list[dict[str, Any]]:
    if append and path.is_file():
        data = load_json(path)
        if isinstance(data, list):
            return data
    return []
