"""Backend FastAPI para Pygenesis ResolveExpert AI (inferencia local GGUF + RAG opcional)."""

from __future__ import annotations

import asyncio
import json
import pickle
import re
import threading
from contextlib import asynccontextmanager
from pathlib import Path

import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

import inference
from page_context import (
    PAGE_LABELS,
    ContextAnalysis,
    analizar_modo_contexto,
    pagina_para_revision,
)
from response_filters import limpiar_respuesta_modelo

import sys

_TRAINING_SCRIPTS = Path(__file__).resolve().parents[1] / "training" / "scripts"
if str(_TRAINING_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_TRAINING_SCRIPTS))
from _resolve_system import RESOLVE_SYSTEM  # noqa: E402

BACKEND_ROOT = Path(__file__).resolve().parent
VECTOR_DIR = BACKEND_ROOT / "vectorstore"

embedder = None
indice = None
fragmentos: list[dict] = []
_startup_state = {"phase": "starting", "detail": "Inicializando"}


def _cargar_rag() -> None:
    global embedder, indice, fragmentos
    indice_path = VECTOR_DIR / "indice.faiss"
    fragmentos_path = VECTOR_DIR / "fragmentos.pkl"
    if not indice_path.is_file() or not fragmentos_path.is_file():
        print("RAG no disponible (falta vectorstore/). El backend funcionará sin contexto.")
        return

    try:
        import faiss
        from sentence_transformers import SentenceTransformer
    except ImportError as exc:
        print(f"RAG omitido (dependencias no instaladas): {exc}")
        return

    print("Cargando base de conocimiento...")
    _startup_state.update({"phase": "loading_rag", "detail": "Cargando RAG"})
    embedder = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
    indice = faiss.read_index(str(indice_path))
    with open(fragmentos_path, "rb") as f:
        fragmentos = pickle.load(f)
    print(f"Base cargada: {len(fragmentos)} fragmentos")


def _startup_worker() -> None:
    try:
        _cargar_rag()
        _startup_state.update({"phase": "loading_model", "detail": "Cargando modelo GGUF"})
        try:
            inference.load_model()
        except RuntimeError as exc:
            print(f"AVISO: {exc}")
        status = inference.get_status()
        if status.get("loaded"):
            _startup_state.update({"phase": "ready", "detail": "Listo"})
        else:
            _startup_state.update(
                {
                    "phase": "degraded",
                    "detail": status.get("error") or "Modelo no cargado",
                }
            )
    except Exception as exc:  # noqa: BLE001 — no tumbar el proceso del puente
        print(f"ERROR en arranque en segundo plano: {exc}")
        _startup_state.update({"phase": "error", "detail": str(exc)})


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Responder /health al instante; RAG + GGUF pueden tardar minutos.
    _startup_state.update({"phase": "starting", "detail": "Arranque en segundo plano"})
    worker = threading.Thread(target=_startup_worker, name="pygenesis-startup", daemon=True)
    worker.start()
    yield
    inference.unload_model()


app = FastAPI(title="Pygenesis ResolveExpert AI Backend", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class Consulta(BaseModel):
    prompt: str
    contexto_proyecto: str = ""
    modo_json: bool = False


def buscar_contexto(pregunta: str, top_k: int = 3) -> list:
    if embedder is None or indice is None:
        return []
    embedding = embedder.encode([pregunta]).astype("float32")
    distancias, indices = indice.search(embedding, top_k)
    resultados = []
    for i, idx in enumerate(indices[0]):
        if idx != -1 and distancias[0][i] < 2.0:
            resultados.append(fragmentos[idx])
    return resultados


_REVIEW_QUESTION_RE = re.compile(
    r"(?:"
    r"qu[eé]\s+(?:deber[ií]a|tengo\s+que|conviene|hay\s+que)\s+revisar"
    r"|qu[eé]\s+revisar"
    r"|revisar\s+(?:en|aqu[ií]|ac[aá])"
    r"|por\s+d[oó]nde\s+(?:empiezo|empezar|arrancar)"
    r"|checklist"
    r"|qu[eé]\s+mirar"
    r")",
    re.IGNORECASE,
)

_PAGE_HINTS: dict[str, str] = {
    "media": "Prioriza Media Pool, importación, bins, metadatos y organización de clips.",
    "cut": "Prioriza la página Cut, selección de takes y ensamblaje rápido.",
    "edit": "Prioriza timeline, herramientas de edición, trim, ripple, roll y multicam.",
    "fusion": "Prioriza compositing, nodos Fusion, efectos y tracking.",
    "color": (
        "Prioriza la página Color: scopes (waveform, vectorscope, parade), nodo corrector, "
        "rueda de color primarias, balance, qualifiers, power windows, stills, LUTs y color management."
    ),
    "fairlight": "Prioriza mezcla, buses, EQ, dinámica, loudness y limpieza de audio.",
    "deliver": "Prioriza presets de render, codecs, resolución, frame rate y cola de entrega.",
}

_PAGE_REVIEW_HINTS: dict[str, str] = {
    "color": (
        "El usuario pide una REVISIÓN de la página Color (checklist), no un tutorial de una sola herramienta.\n"
        "Responde con lista numerada de 5-8 puntos priorizados para Color en ESTE proyecto/timeline.\n"
        "Empieza mencionando el proyecto y la timeline por nombre (del contexto).\n"
        "Cubre: color management, scopes/exposición, árbol de nodos y shot matching, balance primario, "
        "secundarias si aplica, stills/LUTs, consistencia entre planos y preparación para Deliver.\n"
        "No empieces con 'Para resolver este problema'. No centres la respuesta solo en Qualifiers "
        "ni en un único menú del panel lateral."
    ),
    "edit": (
        "El usuario pide una REVISIÓN de la página Edit. Da un checklist de 5-8 puntos: "
        "estructura de timeline, sync, markers, transiciones, compound clips, proxies/cache, "
        "y coherencia antes de pasar a Color o Deliver."
    ),
    "fairlight": (
        "El usuario pide una REVISIÓN de Fairlight. Checklist: niveles, buses, EQ, dinámica, "
        "ruido, diálogos vs música, loudness (LUFS) y preparación para mezcla final."
    ),
    "deliver": (
        "El usuario pide una REVISIÓN de Deliver. Checklist: preset, resolución, frame rate, "
        "codec, color space de salida, in/out, cola de render y verificación del máster."
    ),
    "fusion": (
        "El usuario pide una REVISIÓN de Fusion. Checklist: nodos del clip activo, media in, "
        "merge/key, tracking, render cache y rendimiento."
    ),
    "media": (
        "El usuario pide una REVISIÓN del Media Pool. Checklist: bins, metadatos, proxies, "
        "clips sin vincular y organización antes de editar."
    ),
    "cut": (
        "El usuario pide una REVISIÓN de Cut. Checklist: selección de takes, ensamblaje, "
        "ritmo y paso a Edit si hace falta más control."
    ),
}


def _es_pregunta_revision(prompt: str) -> bool:
    return bool(_REVIEW_QUESTION_RE.search(prompt))


def _detectar_pagina(contexto_proyecto: str) -> str | None:
    for line in contexto_proyecto.splitlines():
        line = line.strip()
        if line.lower().startswith("página activa:"):
            label = line.split(":", 1)[1].strip().lower()
            mapping = {
                "media": "media",
                "cut": "cut",
                "edit": "edit",
                "fusion": "fusion",
                "color": "color",
                "fairlight": "fairlight",
                "deliver": "deliver",
            }
            return mapping.get(label, label)
    return None


def _bloque_contexto_plugin(contexto_proyecto: str, analysis: ContextAnalysis) -> str:
    pagina = analysis.pagina_activa
    hint = _PAGE_HINTS.get(pagina or "", "")
    base_info = contexto_proyecto.strip()

    if analysis.mode == "mismatch":
        tema = analysis.tema_pregunta or ""
        tema_label = PAGE_LABELS.get(tema, tema)
        activa_label = PAGE_LABELS.get(pagina or "", pagina or "Desconocida")
        bloque = (
            "Contexto desde el plugin Pygenesis (DaVinci Resolve Studio).\n"
            f"El usuario está en la página {activa_label} pero pregunta sobre {tema_label}.\n"
            f"IMPORTANTE: responde sobre {tema_label} como pregunta de conocimiento general.\n"
            "NO pidas cambiar de página ni digas que necesitas estar en otra página para responder.\n"
            "NO restrinjas la respuesta a la página activa.\n\n"
            f"{base_info}"
        )
        tema_hint = _PAGE_HINTS.get(tema, "")
        if tema_hint:
            bloque += f"\n\nEnfoque de la respuesta ({tema_label}):\n{tema_hint}"
        return bloque

    if analysis.mode == "general":
        return (
            "Contexto desde el plugin Pygenesis (DaVinci Resolve Studio).\n"
            "El usuario trabaja en el proyecto indicado abajo.\n"
            "Responde la pregunta directamente; no la limites solo a la página activa "
            "salvo que sea relevante para la pregunta.\n\n"
            f"{base_info}"
        )

    bloque = (
        "Contexto en tiempo real desde el plugin Pygenesis (DaVinci Resolve Studio).\n"
        "OBLIGATORIO: adapta TODA la respuesta a la página activa indicada abajo.\n"
        "Si el usuario dice 'aquí', 'esta página' o nombra una página, usa el contexto actual.\n"
        "No des un consejo genérico de otra página (p. ej. reproducir timeline en Edit "
        "si el usuario está en Color).\n\n"
        f"{base_info}"
    )
    if hint:
        bloque += f"\n\nEnfoque obligatorio para esta página:\n{hint}"
    return bloque


def _bloque_revision(pagina: str | None, prompt: str) -> str:
    if not _es_pregunta_revision(prompt):
        return ""
    review = _PAGE_REVIEW_HINTS.get(pagina or "")
    if not review:
        return (
            "El usuario pide qué revisar en la página activa. "
            "Responde con un checklist priorizado de 5-8 puntos de esa página, "
            "no con un tutorial de una sola herramienta."
        )
    return review


def construir_prompt(consulta: Consulta, contexto_rag: list) -> str:
    system = (
        RESOLVE_SYSTEM
        + "\n\nNo cites fuentes ni añadas prefijos tipo [Fuente: ...]."
    )

    im_end = "<|" + "im_end|>"
    prompt = f"<|im_start|>system\n{system}{im_end}\n"

    pagina = _detectar_pagina(consulta.contexto_proyecto)
    es_revision = _es_pregunta_revision(consulta.prompt)
    analysis = analizar_modo_contexto(
        consulta.prompt,
        pagina,
        es_revision=es_revision,
    )

    if consulta.contexto_proyecto.strip():
        prompt += (
            f"<|im_start|>system\n"
            f"{_bloque_contexto_plugin(consulta.contexto_proyecto, analysis)}{im_end}\n"
        )

    pagina_revision = pagina_para_revision(analysis, consulta.prompt, es_revision)
    revision = _bloque_revision(pagina_revision, consulta.prompt)
    if revision:
        prompt += f"<|im_start|>system\n{revision}{im_end}\n"

    if contexto_rag:
        ejemplos = ""
        for i, frag in enumerate(contexto_rag):
            ejemplos += (
                f"\nEjemplo {i + 1}:\nPregunta: {frag['pregunta']}\n"
                f"Respuesta: {frag['respuesta']}\n"
            )
        prompt += f"<|im_start|>system\nEjemplos de referencia:\n{ejemplos}{im_end}\n"

    user_msg = consulta.prompt
    if consulta.contexto_proyecto.strip():
        if analysis.mode == "mismatch":
            tema_label = PAGE_LABELS.get(analysis.tema_pregunta or "", analysis.tema_pregunta or "")
            activa_label = PAGE_LABELS.get(analysis.pagina_activa or "", analysis.pagina_activa or "")
            extra = (
                f"Responde sobre {tema_label}. El usuario está en {activa_label} "
                "pero la pregunta es de conocimiento general sobre esa área."
            )
        elif analysis.mode == "general":
            extra = (
                "Responde directamente a la pregunta; usa proyecto/timeline solo como referencia."
            )
        elif es_revision:
            extra = (
                "Es una pregunta de REVISIÓN/CHECKLIST: lista qué comprobar en la página indicada, "
                "no un procedimiento de un solo panel."
            )
        else:
            extra = (
                "El usuario pregunta desde Resolve; usa el contexto de página/proyecto del system anterior."
            )
        user_msg = f"{consulta.prompt}\n\n({extra})"

    prompt += f"<|im_start|>user\n{user_msg}{im_end}\n"
    prompt += "<|im_start|>assistant\n"
    return prompt


def _ensure_model_ready() -> None:
    status = inference.get_status()
    if not status["loaded"]:
        raise HTTPException(
            status_code=503,
            detail=status.get("error") or "Modelo no cargado",
        )


async def _stream_inference_sse(consulta: Consulta):
    _ensure_model_ready()
    contexto_rag = buscar_contexto(consulta.prompt, top_k=3)
    prompt_completo = construir_prompt(consulta, contexto_rag)
    loop = asyncio.get_running_loop()
    queue: asyncio.Queue[tuple[str, str | None]] = asyncio.Queue()
    acumulado = ""

    def worker() -> None:
        try:
            for token in inference.generate_stream(
                prompt_completo, modo_json=consulta.modo_json
            ):
                loop.call_soon_threadsafe(queue.put_nowait, ("token", token))
            loop.call_soon_threadsafe(queue.put_nowait, ("done", None))
        except Exception as exc:
            loop.call_soon_threadsafe(queue.put_nowait, ("error", str(exc)))

    threading.Thread(target=worker, daemon=True).start()

    while True:
        kind, data = await queue.get()
        if kind == "token" and data:
            acumulado += data
            yield f"data: {json.dumps({'token': data}, ensure_ascii=False)}\n\n"
        elif kind == "done":
            texto_limpio = limpiar_respuesta_modelo(acumulado)
            payload = {
                "done": True,
                "respuesta": texto_limpio,
                "fragmentos_usados": len(contexto_rag),
            }
            yield f"data: {json.dumps(payload, ensure_ascii=False)}\n\n"
            break
        elif kind == "error":
            raise RuntimeError(data or "Error de inferencia")


@app.post("/consultar")
async def consultar(consulta: Consulta):
    _ensure_model_ready()
    contexto_rag = buscar_contexto(consulta.prompt, top_k=3)
    prompt_completo = construir_prompt(consulta, contexto_rag)

    texto = await asyncio.to_thread(
        inference.generate,
        prompt_completo,
        modo_json=consulta.modo_json,
    )
    texto_limpio = limpiar_respuesta_modelo(texto)

    return {
        "respuesta": texto_limpio,
        "fragmentos_usados": len(contexto_rag),
    }


@app.post("/consultar/stream")
async def consultar_stream(consulta: Consulta):
    return StreamingResponse(
        _stream_inference_sse(consulta),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@app.get("/health")
async def health():
    model_status = inference.get_status()
    ok = model_status["loaded"]
    phase = _startup_state.get("phase") or "unknown"
    if ok:
        status = "ok"
    elif phase in {"starting", "loading_rag", "loading_model"}:
        status = "starting"
    else:
        status = "degraded"
    return {
        "status": status,
        "modelo": model_status["modelo"],
        "backend": model_status["backend"],
        "model_path": model_status["model_path"],
        "model_loaded": ok,
        "startup_phase": phase,
        "startup_detail": _startup_state.get("detail"),
        "fragmentos": len(fragmentos),
        "rag_activo": embedder is not None,
        "error": model_status.get("error") or (
            _startup_state.get("detail") if phase == "error" else None
        ),
    }
