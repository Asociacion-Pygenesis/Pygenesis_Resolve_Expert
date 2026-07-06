"""Comprueba que el venv de training tiene PyTorch y dependencias básicas."""
from __future__ import annotations

import importlib.util
import sys


def _ok(name: str) -> bool:
    return importlib.util.find_spec(name) is not None


def main() -> int:
    print("Python:", sys.version.split()[0])
    missing = [p for p in ("torch", "transformers", "datasets", "peft", "trl") if not _ok(p)]
    if missing:
        print("Faltan paquetes:", ", ".join(missing))
        return 1

    import torch

    print("torch:", torch.__version__)
    print("cuda disponible (NVIDIA):", torch.cuda.is_available())
    if torch.cuda.is_available():
        print("dispositivo 0:", torch.cuda.get_device_name(0))

    import transformers

    print("transformers:", transformers.__version__)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
