"""Fusiona el adaptador LoRA con Qwen base y guarda el modelo merged."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import torch
from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer

DEFAULT_MODEL = "Qwen/Qwen2.5-Coder-7B-Instruct"
DEFAULT_LORA_DIRS = (
    "qwen-coder-resolve-lora",
    "pygenesis-resolve-lora",
)


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def find_lora_path(explicit: str | None) -> Path:
    root = repo_root()
    candidates: list[Path] = []

    if explicit:
        candidates.append(Path(explicit).expanduser())
        if not candidates[-1].is_absolute():
            candidates.append(root / explicit)

    for name in DEFAULT_LORA_DIRS:
        candidates.append(root / "modelos" / name)

    modelos = root / "modelos"
    if modelos.is_dir():
        for child in sorted(modelos.iterdir()):
            if child.is_dir() and (child / "adapter_config.json").is_file():
                candidates.append(child)

    seen: set[Path] = set()
    for path in candidates:
        resolved = path.resolve()
        if resolved in seen:
            continue
        seen.add(resolved)
        if (resolved / "adapter_config.json").is_file():
            return resolved

    searched = "\n".join(f"  - {p.resolve()}" for p in seen)
    raise FileNotFoundError(
        "No se encontró adapter_config.json.\n"
        f"Rutas comprobadas:\n{searched}\n\n"
        "Descomprime el ZIP de Colab en modelos/ (p. ej. modelos/qwen-coder-resolve-lora/) "
        "o pasa --lora-path con la carpeta que contiene adapter_config.json."
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Fusiona LoRA + Qwen base.")
    parser.add_argument(
        "--lora-path",
        default=None,
        help="Carpeta del adaptador (debe contener adapter_config.json).",
    )
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help="Modelo base en HuggingFace.",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="Carpeta de salida merged (por defecto: qwen-resolve-merged en la raíz del repo).",
    )
    args = parser.parse_args()

    lora_path = find_lora_path(args.lora_path)
    output_path = (
        Path(args.output).expanduser().resolve()
        if args.output
        else repo_root() / "qwen-resolve-merged"
    )

    print(f"Adaptador LoRA: {lora_path}")
    print(f"Modelo base:    {args.model}")
    print(f"Salida:         {output_path}")

    print("Cargando modelo base...")
    base_model = AutoModelForCausalLM.from_pretrained(
        args.model,
        dtype=torch.float16,
        device_map="cpu",
        trust_remote_code=True,
    )
    tokenizer = AutoTokenizer.from_pretrained(args.model, trust_remote_code=True)

    print("Fusionando LoRA...")
    merged = PeftModel.from_pretrained(base_model, str(lora_path))
    merged = merged.merge_and_unload()
    merged.save_pretrained(output_path)
    tokenizer.save_pretrained(output_path)

    print(f"Listo en {output_path}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except FileNotFoundError as exc:
        print(exc, file=sys.stderr)
        raise SystemExit(1)
