"""Backend FastAPI para Pygenesis ResolveExpert AI (Ollama + RAG opcional)."""

from __future__ import annotations

import pickle
from pathlib import Path

import faiss
import httpx
import numpy as np
from fastapi import FastAPI
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer

from response_filters import limpiar_respuesta_modelo

app = FastAPI(title="Pygenesis ResolveExpert AI Backend")

OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL_NAME = "pygenesis-resolve"

BACKEND_ROOT = Path(__file__).resolve().parent
VECTOR_DIR = BACKEND_ROOT / "vectorstore"

embedder: SentenceTransformer | None = None
indice: faiss.Index | None = None
fragmentos: list[dict] = []


def _cargar_rag() -> None:
    global embedder, indice, fragmentos
    indice_path = VECTOR_DIR / "indice.faiss"
    fragmentos_path = VECTOR_DIR / "fragmentos.pkl"
    if not indice_path.is_file() or not fragmentos_path.is_file():
        print("RAG no disponible (falta vectorstore/). El backend funcionará sin contexto.")
        return

    print("Cargando base de conocimiento...")
    embedder = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
    indice = faiss.read_index(str(indice_path))
    with open(fragmentos_path, "rb") as f:
        fragmentos = pickle.load(f)
    print(f"Base cargada: {len(fragmentos)} fragmentos")


_cargar_rag()


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


def construir_prompt(consulta: Consulta, contexto_rag: list) -> str:
    system = """Eres Pygenesis ResolveExpert AI, asistente experto en DaVinci Resolve (edición, Color, Fusion, Fairlight y Deliver).

Responde en español salvo que pidan otro idioma. Usa JSON solo si lo piden explícitamente.
Si no sabes algo, dilo sin inventar.

No cites fuentes ni añadas prefijos tipo [Fuente: ...].
No añadas cierres tipo "En resumen" ni repitas tu rol."""

    im_end = "<|" + "im_end|>"
    prompt = f"<|im_start|>system\n{system}{im_end}\n"

    if consulta.contexto_proyecto:
        prompt += (
            f"<|im_start|>system\nContexto del proyecto en Resolve:\n"
            f"{consulta.contexto_proyecto}{im_end}\n"
        )

    if contexto_rag:
        ejemplos = ""
        for i, frag in enumerate(contexto_rag):
            ejemplos += (
                f"\nEjemplo {i + 1}:\nPregunta: {frag['pregunta']}\n"
                f"Respuesta: {frag['respuesta']}\n"
            )
        prompt += f"<|im_start|>system\nEjemplos de referencia:\n{ejemplos}{im_end}\n"

    prompt += f"<|im_start|>user\n{consulta.prompt}{im_end}\n"
    prompt += "<|im_start|>assistant\n"
    return prompt


@app.post("/consultar")
async def consultar(consulta: Consulta):
    contexto_rag = buscar_contexto(consulta.prompt, top_k=3)
    prompt_completo = construir_prompt(consulta, contexto_rag)

    async with httpx.AsyncClient(timeout=120) as client:
        response = await client.post(
            OLLAMA_URL,
            json={
                "model": MODEL_NAME,
                "prompt": prompt_completo,
                "stream": False,
                "raw": True,
                "options": {
                    "temperature": 0.1 if consulta.modo_json else 0.2,
                    "top_p": 0.95,
                    "top_k": 20,
                    "presence_penalty": 1.5,
                    "stop": ["<|im_end|>", "<|im_start|>"],
                },
            },
        )

        data = response.json()
        texto_limpio = limpiar_respuesta_modelo(data.get("response", ""))

        return {
            "respuesta": texto_limpio,
            "fragmentos_usados": len(contexto_rag),
        }


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "modelo": MODEL_NAME,
        "fragmentos": len(fragmentos),
        "rag_activo": embedder is not None,
    }
