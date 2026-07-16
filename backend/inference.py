"""Motor de inferencia local con llama-cpp-python (GGUF, sin Ollama)."""

from __future__ import annotations

import threading
from collections.abc import Iterator
from dataclasses import dataclass
from typing import Any

from config import (
    MODEL_NAME,
    N_CTX,
    N_GPU_LAYERS,
    N_PREDICT,
    STOP_SEQUENCES,
    gpu_backend,
    resolve_model_path,
)

_lock = threading.Lock()
_llm: Any | None = None
_status: dict[str, Any] = {
    "loaded": False,
    "backend": None,
    "model_path": None,
    "error": None,
}


@dataclass
class GenerationOptions:
    temperature: float = 0.2
    top_p: float = 0.95
    top_k: int = 20
    repeat_penalty: float = 1.05
    max_tokens: int = N_PREDICT


def _llama_kwargs(model_path: str, backend: str) -> dict[str, Any]:
    kwargs: dict[str, Any] = {
        "model_path": model_path,
        "n_ctx": N_CTX,
        "verbose": False,
    }
    if backend in {"cuda", "vulkan"}:
        kwargs["n_gpu_layers"] = N_GPU_LAYERS
    else:
        kwargs["n_gpu_layers"] = 0
    return kwargs


def load_model(*, force: bool = False) -> None:
    global _llm

    with _lock:
        if _llm is not None and not force:
            return

        backend = gpu_backend()
        model_path = resolve_model_path()
        _status.update(
            {
                "loaded": False,
                "backend": backend,
                "model_path": str(model_path),
                "error": None,
            }
        )

        if not model_path.is_file():
            _status["error"] = f"Modelo no encontrado: {model_path}"
            _llm = None
            return

        try:
            from llama_cpp import Llama
        except ImportError as exc:
            _status["error"] = (
                "llama-cpp-python no instalado. Ejecuta backend/scripts/install_inference.ps1"
            )
            _llm = None
            raise RuntimeError(_status["error"]) from exc

        print(f"Cargando modelo ({backend}): {model_path}")
        _llm = Llama(**_llama_kwargs(str(model_path), backend))
        _status["loaded"] = True
        print(f"Modelo listo: {MODEL_NAME} [{backend}]")


def unload_model() -> None:
    global _llm
    with _lock:
        _llm = None
        _status["loaded"] = False


def get_status() -> dict[str, Any]:
    return {
        "modelo": MODEL_NAME,
        "loaded": _status["loaded"],
        "backend": _status["backend"] or gpu_backend(),
        "model_path": _status["model_path"] or str(resolve_model_path()),
        "error": _status["error"],
    }


def _require_llm() -> Any:
    if _llm is None:
        load_model()
    if _llm is None:
        raise RuntimeError(_status.get("error") or "Modelo no cargado")
    return _llm


def generate(prompt: str, *, modo_json: bool = False) -> str:
    llm = _require_llm()
    opts = GenerationOptions(temperature=0.1 if modo_json else 0.2)

    with _lock:
        result = llm(
            prompt,
            max_tokens=opts.max_tokens,
            temperature=opts.temperature,
            top_p=opts.top_p,
            top_k=opts.top_k,
            repeat_penalty=opts.repeat_penalty,
            stop=STOP_SEQUENCES,
            echo=False,
        )

    return result["choices"][0]["text"]


def generate_stream(prompt: str, *, modo_json: bool = False) -> Iterator[str]:
    llm = _require_llm()
    opts = GenerationOptions(temperature=0.1 if modo_json else 0.2)

    with _lock:
        stream = llm(
            prompt,
            max_tokens=opts.max_tokens,
            temperature=opts.temperature,
            top_p=opts.top_p,
            top_k=opts.top_k,
            repeat_penalty=opts.repeat_penalty,
            stop=STOP_SEQUENCES,
            echo=False,
            stream=True,
        )
        for chunk in stream:
            token = chunk["choices"][0]["text"]
            if token:
                yield token
