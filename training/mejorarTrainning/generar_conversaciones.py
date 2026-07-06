"""Genera conversaciones multi-turn con Gemini para Pygenesis ResolveExpert AI.

Salida: training/data/raw/gemini/multiturn.json

Uso:
  python mejorarTrainning/generar_conversaciones.py --append --skip-existing --tier free
  python mejorarTrainning/generar_conversaciones.py --contexto "optimizando" --append
"""

from __future__ import annotations

import argparse
import sys
import time

from google.genai import types
from tqdm import tqdm

from gemini_common import (
    DEFAULT_MODEL,
    GEMINI_SYSTEM_PROMPT,
    RESOLVE_SYSTEM,
    GeminiRateLimiter,
    call_gemini,
    gemini_client,
    is_good_answer,
    load_existing_if_append,
    rate_limiter_for_tier,
    raw_gemini_dir,
    resolve_tier,
    tier_rpm,
    tier_sleep_extra,
    write_json,
)


# Free tier: cada escenario = varios turnos seguidos; conviene ir lento.
MULTITURN_FREE_RPM = 3.0
MULTITURN_FREE_SLEEP = 20.0
MULTITURN_FREE_429_MIN_WAIT = 55.0
MULTITURN_RETRIES = 12


ESCENARIOS_MULTITURN = [
    {
        "contexto": "Un editor corrige material LOG de cámara para un cortometraje",
        "turnos": [
            "Tengo material en S-Log3, ¿por dónde empiezo el color grading?",
            "El primer plano se ve bien pero el segundo está muy verde. ¿Cómo lo igualo?",
            "Quiero aislar solo la piel para un ajuste suave. ¿Qué herramienta uso?",
            "¿Cómo aplico un LUT creativo sin romper el balance que ya hice?",
            "¿Cómo exporto una still para que el director la revise?",
        ],
    },
    {
        "contexto": "Un usuario prepara la entrega final para YouTube",
        "turnos": [
            "Terminé el edit, ¿qué debo revisar antes de ir a la página Deliver?",
            "¿Qué resolución y bitrate recomiendas para YouTube 4K?",
            "El archivo pesa demasiado. ¿Cómo reduzco tamaño sin perder mucha calidad?",
            "¿Debo quemar subtítulos o entregarlos aparte?",
        ],
    },
    {
        "contexto": "Un compositor integra un título en Fusion",
        "turnos": [
            "Quiero añadir un título animado sobre mi clip. ¿Empiezo en Fusion o en Edit?",
            "¿Cómo hago un tracking simple para que el texto siga un objeto?",
            "El render de Fusion va muy lento. ¿Qué puedo cachear?",
        ],
    },
    {
        "contexto": "Un editor optimiza un proyecto pesado en portátil",
        "turnos": [
            "Resolve va lento con proxies desactivados. ¿Qué activo primero?",
            "¿Optimized media vs render cache: cuál me conviene en este caso?",
            "La timeline sigue entrecortada con muchos efectos de Color. ¿Qué hago?",
        ],
    },
]


def human_turn_count(item: dict) -> int:
    return sum(1 for m in item.get("conversations", []) if m.get("from") == "human")


def is_conversation_complete(item: dict, expected_turns: int) -> bool:
    return human_turn_count(item) >= expected_turns


def contextos_completos(conversaciones: list[dict]) -> set[str]:
    by_ctx: dict[str, int] = {}
    for esc in ESCENARIOS_MULTITURN:
        by_ctx[esc["contexto"].strip()] = len(esc["turnos"])
    done: set[str] = set()
    for item in conversaciones:
        ctx = (item.get("metadata") or {}).get("contexto", "").strip()
        if not ctx:
            continue
        expected = by_ctx.get(ctx)
        if expected and is_conversation_complete(item, expected):
            done.add(ctx)
    return done


def find_item_index_by_contexto(conversaciones: list[dict], contexto: str) -> int | None:
    ctx = contexto.strip()
    for i, item in enumerate(conversaciones):
        if (item.get("metadata") or {}).get("contexto", "").strip() == ctx:
            return i
    return None


def resume_state_from_item(item: dict) -> tuple[list[dict[str, str]], list[dict[str, str]], int]:
    """Reconstruye historial API y dataset desde una conversación parcial guardada."""
    historial: list[dict[str, str]] = []
    conversacion_dataset = [{"from": "system", "value": RESOLVE_SYSTEM}]
    conv = item.get("conversations") or []
    i = 1
    while i < len(conv):
        if conv[i].get("from") != "human":
            i += 1
            continue
        human = conv[i].get("value", "")
        gpt = ""
        if i + 1 < len(conv) and conv[i + 1].get("from") == "gpt":
            gpt = conv[i + 1].get("value", "")
        conversacion_dataset.append({"from": "human", "value": human})
        conversacion_dataset.append({"from": "gpt", "value": gpt})
        historial.append({"role": "user", "text": human})
        historial.append({"role": "model", "text": gpt})
        i += 2
    return historial, conversacion_dataset, human_turn_count(item)


def generar_conversacion_completa(
    escenario: dict,
    *,
    client,
    model: str,
    sleep: float,
    rate_limiter: GeminiRateLimiter,
    retries: int,
    rate_limit_429_min_wait: float,
    partial_item: dict | None = None,
) -> tuple[dict | None, str]:
    """Devuelve (conversación, motivo_fallo). motivo_fallo vacío si OK."""
    expected = len(escenario["turnos"])
    historial: list[dict[str, str]] = []
    conversacion_dataset = [{"from": "system", "value": RESOLVE_SYSTEM}]
    start_idx = 0

    if partial_item is not None:
        historial, conversacion_dataset, start_idx = resume_state_from_item(partial_item)
        if start_idx > 0:
            print(
                f"  Reanudando '{escenario['contexto'][:50]}...' desde turno {start_idx + 1}/{expected}",
                file=sys.stderr,
            )

    system_instruction = f"{GEMINI_SYSTEM_PROMPT}\n\nContexto persistente: {escenario['contexto']}"
    fail_reason = ""

    for turn_idx, turno_usuario in enumerate(escenario["turnos"]):
        if turn_idx < start_idx:
            continue

        messages_api: list[types.Content] = []
        for msg in historial:
            messages_api.append(
                types.Content(role=msg["role"], parts=[types.Part(text=msg["text"])])
            )
        messages_api.append(types.Content(role="user", parts=[types.Part(text=turno_usuario)]))

        respuesta = call_gemini(
            messages_api,
            client=client,
            model=model,
            system_instruction=system_instruction,
            temperature=0.75,
            max_output_tokens=1800,
            retries=retries,
            rate_limit_429_min_wait=rate_limit_429_min_wait,
            rate_limiter=rate_limiter,
        )
        if not is_good_answer(respuesta, min_chars=80):
            if respuesta is None:
                fail_reason = f"sin respuesta (cuota/red) en turno {turn_idx + 1}/{expected}"
            else:
                fail_reason = f"respuesta demasiado corta en turno {turn_idx + 1}/{expected}"
            break

        conversacion_dataset.append({"from": "human", "value": turno_usuario})
        conversacion_dataset.append({"from": "gpt", "value": respuesta or ""})
        historial.append({"role": "user", "text": turno_usuario})
        historial.append({"role": "model", "text": respuesta or ""})

        if sleep > 0:
            time.sleep(sleep)

    n_turns = human_turn_count({"conversations": conversacion_dataset})
    if n_turns >= expected:
        return (
            {
                "conversations": conversacion_dataset,
                "metadata": {"fuente": "gemini_multiturn", "contexto": escenario["contexto"]},
            },
            "",
        )

    if n_turns >= 2:
        partial = {
            "conversations": conversacion_dataset,
            "metadata": {
                "fuente": "gemini_multiturn",
                "contexto": escenario["contexto"],
                "incompleto": True,
                "turnos_hechos": n_turns,
                "turnos_total": expected,
            },
        }
        if not fail_reason:
            fail_reason = f"incompleta ({n_turns}/{expected} turnos)"
        return partial, fail_reason

    if not fail_reason:
        fail_reason = f"muy pocos turnos ({n_turns}/{expected})"
    return None, fail_reason


def upsert_conversation(conversaciones: list[dict], conv: dict, contexto: str) -> None:
    idx = find_item_index_by_contexto(conversaciones, contexto)
    if idx is not None:
        conversaciones[idx] = conv
    else:
        conversaciones.append(conv)


def main() -> int:
    parser = argparse.ArgumentParser(description="Genera conversaciones multi-turn con Gemini.")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--output", default="multiturn.json")
    parser.add_argument("--append", action="store_true")
    parser.add_argument("--repetitions", type=int, default=1)
    parser.add_argument("--limit", type=int, default=0, help="Máximo de escenarios en esta ejecución (0 = todos).")
    parser.add_argument("--offset", type=int, default=0, help="Saltar los N primeros escenarios del listado.")
    parser.add_argument(
        "--skip-existing",
        action="store_true",
        help="Omitir escenarios ya completos (todos los turnos) en multiturn.json.",
    )
    parser.add_argument(
        "--contexto",
        action="append",
        default=[],
        metavar="TEXTO",
        help="Solo escenarios cuyo contexto contenga este texto (repetible).",
    )
    parser.add_argument("--tier", choices=("free", "plus"), default=None)
    parser.add_argument("--sleep", type=float, default=-1.0)
    parser.add_argument("--rpm", type=float, default=0.0)
    parser.add_argument("--retries", type=int, default=0, help=f"0 = {MULTITURN_RETRIES} por defecto.")
    args = parser.parse_args()

    tier = resolve_tier(args.tier)
    if args.sleep < 0:
        sleep_extra = MULTITURN_FREE_SLEEP if tier == "free" else tier_sleep_extra(tier, None)
    else:
        sleep_extra = args.sleep
    if args.rpm <= 0 and tier == "free":
        rpm = MULTITURN_FREE_RPM
    else:
        rpm = None if args.rpm <= 0 else args.rpm
    retries = args.retries if args.retries > 0 else MULTITURN_RETRIES
    wait_429 = MULTITURN_FREE_429_MIN_WAIT if tier == "free" else 20.0

    print(
        f"Tier={tier} rpm={tier_rpm(tier, rpm):.1f} sleep={sleep_extra:.0f}s "
        f"retries={retries} espera_429>={wait_429:.0f}s"
    )

    client = gemini_client()
    rate_limiter = rate_limiter_for_tier(tier, rpm)
    output_path = raw_gemini_dir() / args.output
    conversaciones = load_existing_if_append(output_path, args.append)

    completos = contextos_completos(conversaciones) if args.skip_existing else set()

    escenarios = list(ESCENARIOS_MULTITURN)
    if args.contexto:
        needles = [n.lower() for n in args.contexto]
        escenarios = [
            e for e in escenarios if any(n in e["contexto"].lower() for n in needles)
        ]
    if args.skip_existing:
        escenarios = [e for e in escenarios if e["contexto"].strip() not in completos]
    if args.offset > 0:
        escenarios = escenarios[args.offset :]
    if args.limit > 0:
        escenarios = escenarios[: args.limit]

    print(f"Escenarios en este lote: {len(escenarios)} (skip-existing={args.skip_existing})")
    if not escenarios:
        print("Nada que generar: todos los escenarios completos ya están en multiturn.json.")
        return 0

    guardadas = 0
    fallidas: list[str] = []

    jobs = escenarios * max(1, args.repetitions)
    for escenario in tqdm(jobs, desc="Gemini multi-turn"):
        ctx = escenario["contexto"]
        partial_idx = find_item_index_by_contexto(conversaciones, ctx)
        partial_item = None
        if partial_idx is not None:
            existing = conversaciones[partial_idx]
            if not is_conversation_complete(existing, len(escenario["turnos"])):
                partial_item = existing

        conv, fail = generar_conversacion_completa(
            escenario,
            client=client,
            model=args.model,
            sleep=sleep_extra,
            rate_limiter=rate_limiter,
            retries=retries,
            rate_limit_429_min_wait=wait_429,
            partial_item=partial_item,
        )
        if conv:
            upsert_conversation(conversaciones, conv, ctx)
            write_json(output_path, conversaciones)
            if not (conv.get("metadata") or {}).get("incompleto"):
                guardadas += 1
                print(f"  OK: {ctx[:60]}...", file=sys.stderr)
            else:
                fallidas.append(f"{ctx[:50]}... ({fail})")
        else:
            fallidas.append(f"{ctx[:50]}... ({fail or 'fallo'})")

    print(f"Conversaciones en archivo: {len(conversaciones)} -> {output_path}")
    print(f"Nuevas completas en esta pasada: {guardadas}")
    if fallidas:
        print("No completadas / reintentar más tarde:", file=sys.stderr)
        for line in fallidas:
            print(f"  - {line}", file=sys.stderr)
        print(
            "Sugerencia: espera 10-15 min (cuota diaria/RPM) y ejecuta un escenario:\n"
            '  python mejorarTrainning/generar_conversaciones.py --append --tier free '
            '--contexto "optimizando"',
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
