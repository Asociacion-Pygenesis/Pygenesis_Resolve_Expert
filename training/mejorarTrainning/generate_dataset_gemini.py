"""Genera ejemplos single-turn nuevos con Gemini para Pygenesis ResolveExpert AI.

Salida: training/data/raw/gemini/resolve_gemini_base.json

Uso:
  python mejorarTrainning/generate_dataset_gemini.py --limit 20
  python mejorarTrainning/generate_dataset_gemini.py --variations-per-topic 2 --append
"""

from __future__ import annotations

import argparse
import time

from tqdm import tqdm

from gemini_common import (
    DEFAULT_MODEL,
    GeminiRateLimiter,
    call_gemini,
    gemini_client,
    is_good_answer,
    load_existing_if_append,
    rate_limiter_for_tier,
    raw_gemini_dir,
    resolve_tier,
    sharegpt_item,
    tier_rpm,
    tier_sleep_extra,
    write_json,
)


def _existing_question_keys(dataset: list[dict]) -> set[str]:
    keys: set[str] = set()
    for item in dataset:
        for turn in item.get("conversations") or []:
            if turn.get("from") == "human":
                keys.add((turn.get("value") or "").strip()[:120].lower())
    return keys


TEMAS = {
    "edit_timeline": [
        "¿Cuál es la diferencia entre ripple edit y roll edit en la timeline?",
        "¿Cómo configuro proxies para editar material 4K en un portátil?",
        "¿Cómo sincronizo clips de multicámara por audio en Resolve?",
        "Explica el flujo del Media Pool: importar, bins y metadata",
        "¿Cómo hago un speed ramp con retime y optical flow?",
    ],
    "color": [
        "¿Cómo empiezo a corregir material LOG con un workflow color managed?",
        "Explica primaries wheels vs log wheels vs curves",
        "¿Cómo uso qualifiers para aislar tonos de piel?",
        "¿Qué scopes debo mirar para balancear blancos en HDR?",
        "¿Cuándo usar un LUT de input transform vs un creative LUT?",
        "¿Cómo hago matching entre dos planos con iluminación distinta?",
    ],
    "fusion": [
        "¿Cómo conecto MediaIn, Transform y Merge en Fusion?",
        "Explica tracking puntual vs planar tracker",
        "¿Cómo hago un keying básico con el Delta Keyer?",
        "¿Qué es el cache de Fusion y cuándo conviene activarlo?",
    ],
    "fairlight": [
        "¿Cómo organizo buses y submix en Fairlight?",
        "Explica loudness LUFS para entrega broadcast",
        "¿Cómo aplico ducking de música bajo diálogo?",
    ],
    "deliver": [
        "¿Qué codec elijo para YouTube: H.264 vs H.265?",
        "¿Cómo exporto ProRes 422 HQ para intercambio con otro editor?",
        "¿Qué preset de Deliver usar para redes sociales verticales?",
        "¿Cómo exporto con subtítulos quemados vs sidecar?",
    ],
    "general": [
        "¿Cuáles son las diferencias prácticas entre Resolve Free y Studio?",
        "¿Cómo configuro project settings de frame rate y resolución?",
        "Mi timeline va lenta con muchos efectos: ¿qué optimizo primero?",
        "¿Cómo hago backup seguro de proyecto y media?",
    ],
}


def generar_variaciones(
    pregunta_base: str,
    *,
    client,
    model: str,
    n: int,
    rate_limiter: GeminiRateLimiter,
) -> list[str]:
    if n <= 0:
        return []
    prompt = f"""Genera {n} variaciones diferentes de esta pregunta sobre DaVinci Resolve.
Mantén el tema, pero cambia contexto, nivel de dificultad o enfoque.
Devuelve solo las preguntas, una por línea, sin numeración.

Pregunta original: {pregunta_base}"""
    response = call_gemini(
        prompt,
        client=client,
        model=model,
        temperature=0.8,
        max_output_tokens=700,
        rate_limiter=rate_limiter,
    )
    if not response:
        return []
    return [line.strip(" -\t") for line in response.splitlines() if line.strip()][:n]


def main() -> int:
    parser = argparse.ArgumentParser(description="Genera dataset ShareGPT con Gemini (Resolve).")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--output", default="resolve_gemini_base.json")
    parser.add_argument("--append", action="store_true")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--offset", type=int, default=0)
    parser.add_argument("--variations-per-topic", type=int, default=0)
    parser.add_argument("--tier", choices=("free", "plus"), default=None)
    parser.add_argument("--sleep", type=float, default=-1.0)
    parser.add_argument("--rpm", type=float, default=0.0)
    parser.add_argument("--only-missing", action="store_true")
    parser.add_argument("--min-answer-chars", type=int, default=120)
    args = parser.parse_args()

    tier = resolve_tier(args.tier)
    sleep_extra = tier_sleep_extra(tier, None if args.sleep < 0 else args.sleep)
    rpm = None if args.rpm <= 0 else args.rpm

    client = gemini_client()
    rate_limiter = rate_limiter_for_tier(tier, rpm)
    print(f"Tier={tier} rpm={tier_rpm(tier, rpm):.1f} sleep_extra={sleep_extra}s")
    output_path = raw_gemini_dir() / args.output
    dataset = load_existing_if_append(output_path, args.append)
    seen_questions = _existing_question_keys(dataset) if args.only_missing else set()

    jobs: list[tuple[str, str, bool]] = []
    for categoria, preguntas in TEMAS.items():
        for pregunta in preguntas:
            jobs.append((categoria, pregunta, False))
            for variacion in generar_variaciones(
                pregunta,
                client=client,
                model=args.model,
                n=args.variations_per_topic,
                rate_limiter=rate_limiter,
            ):
                jobs.append((categoria, variacion, True))
                if sleep_extra > 0:
                    time.sleep(sleep_extra)

    if args.only_missing:
        jobs = [
            (cat, q, var)
            for cat, q, var in jobs
            if q.strip()[:120].lower() not in seen_questions
        ]
        print(f"Preguntas pendientes (only-missing): {len(jobs)}")

    if args.offset > 0:
        jobs = jobs[args.offset :]
    if args.limit > 0:
        jobs = jobs[: args.limit]

    print(f"Preguntas en este lote: {len(jobs)} (offset={args.offset}, limit={args.limit or 'all'})")
    if not jobs:
        print("Nada que generar en este lote.")
        return 0

    for categoria, pregunta, es_variacion in tqdm(jobs, desc="Gemini single-turn"):
        respuesta = call_gemini(
            pregunta,
            client=client,
            model=args.model,
            temperature=0.7,
            max_output_tokens=2048,
            rate_limiter=rate_limiter,
        )
        if is_good_answer(respuesta, min_chars=args.min_answer_chars):
            dataset.append(
                sharegpt_item(
                    pregunta,
                    respuesta or "",
                    metadata={
                        "fuente": "gemini_base",
                        "categoria": categoria,
                        "modelo": args.model,
                        "es_variacion": es_variacion,
                    },
                )
            )
            write_json(output_path, dataset)
            seen_questions.add(pregunta.strip()[:120].lower())
        if sleep_extra > 0:
            time.sleep(sleep_extra)

    print(f"Dataset generado: {len(dataset)} ejemplos -> {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
