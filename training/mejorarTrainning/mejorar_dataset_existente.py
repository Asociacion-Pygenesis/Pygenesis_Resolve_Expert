"""Mejora respuestas existentes con Gemini sin pisar el dataset original.

Entrada por defecto: training/data/train/resolve_train.json
Salida por defecto: training/data/raw/gemini/mejorado.json

Uso:
  python mejorarTrainning/mejorar_dataset_existente.py --max-examples 100
"""

from __future__ import annotations

import argparse
import time
from pathlib import Path

from tqdm import tqdm

from gemini_common import (
    DEFAULT_MODEL,
    RESOLVE_SYSTEM,
    call_gemini,
    gemini_client,
    is_good_answer,
    load_existing_if_append,
    load_json,
    rate_limiter_for_tier,
    raw_gemini_dir,
    resolve_tier,
    tier_rpm,
    tier_sleep_extra,
    training_root,
    write_json,
)


PROMPT_MEJORA = """Tienes esta pregunta y respuesta sobre DaVinci Resolve.
Reescribe la respuesta para mejorarla, manteniendo la intención original.

Objetivos:
- Más clara, práctica y precisa.
- Pasos concretos en la interfaz de Resolve cuando aporte valor.
- Explica decisiones importantes sin volverte excesivamente largo.
- Menciona errores comunes si son relevantes.
- No inventes menús o funciones de Resolve.
- No incluyas preámbulo tipo "Aquí tienes".
- No cierres con "En resumen", "En conclusión" ni frases sobre tu rol.

PREGUNTA:
{pregunta}

RESPUESTA ORIGINAL:
{respuesta}

Devuelve solo la respuesta mejorada."""


def first_turns(item: dict) -> tuple[str, str] | None:
    convs = item.get("conversations") or []
    humans = [c.get("value", "") for c in convs if c.get("from") == "human"]
    answers = [c.get("value", "") for c in convs if c.get("from") == "gpt"]
    if len(humans) != 1 or len(answers) != 1:
        return None
    question, answer = humans[0].strip(), answers[0].strip()
    if not question or not answer:
        return None
    return question, answer


def main() -> int:
    parser = argparse.ArgumentParser(description="Mejora ejemplos single-turn con Gemini.")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument(
        "--input",
        default=str(training_root() / "data" / "train" / "resolve_train.json"),
        help="Dataset ShareGPT a mejorar.",
    )
    parser.add_argument("--output", default="mejorado.json")
    parser.add_argument("--append", action="store_true")
    parser.add_argument("--max-examples", type=int, default=100)
    parser.add_argument("--offset", type=int, default=0)
    parser.add_argument("--tier", choices=("free", "plus"), default=None)
    parser.add_argument("--sleep", type=float, default=-1.0)
    parser.add_argument("--rpm", type=float, default=0.0)
    parser.add_argument("--min-ratio", type=float, default=0.75)
    args = parser.parse_args()

    tier = resolve_tier(args.tier)
    sleep_extra = tier_sleep_extra(tier, None if args.sleep < 0 else args.sleep)
    rpm = None if args.rpm <= 0 else args.rpm

    source_path = Path(args.input)
    source = load_json(source_path)
    selected = source[args.offset :]
    if args.max_examples > 0:
        selected = selected[: args.max_examples]

    client = gemini_client()
    rate_limiter = rate_limiter_for_tier(tier, rpm)
    output_path = raw_gemini_dir() / args.output
    mejorado = load_existing_if_append(output_path, args.append)

    for item in tqdm(selected, desc="Gemini mejora"):
        pair = first_turns(item)
        if pair is None:
            continue
        pregunta, respuesta = pair
        prompt = PROMPT_MEJORA.format(pregunta=pregunta, respuesta=respuesta)

        respuesta_mejorada = call_gemini(
            prompt,
            client=client,
            model=args.model,
            temperature=0.45,
            max_output_tokens=2400,
            rate_limiter=rate_limiter,
        )
        if not is_good_answer(respuesta_mejorada, min_chars=80):
            continue
        if len((respuesta_mejorada or "").strip()) < len(respuesta) * args.min_ratio:
            continue

        mejorado.append(
            {
                "conversations": [
                    {"from": "system", "value": RESOLVE_SYSTEM},
                    {"from": "human", "value": pregunta},
                    {"from": "gpt", "value": respuesta_mejorada or ""},
                ],
                "metadata": {
                    "fuente": "gemini_mejorado",
                    "origen": str(source_path),
                    "modelo": args.model,
                },
            }
        )
        write_json(output_path, mejorado)

        if sleep_extra > 0:
            time.sleep(sleep_extra)

    print(f"Ejemplos mejorados: {len(mejorado)} -> {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
