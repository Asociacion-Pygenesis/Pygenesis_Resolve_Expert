"""Configuración del puente de inferencia (modelo GGUF y backend GPU)."""

from __future__ import annotations

import os
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parent
REPO_ROOT = BACKEND_ROOT.parent

MODEL_NAME = "pygenesis-resolve"
MODEL_FILENAME = "pygenesis-resolve-q4km.gguf"

IM_END = "<|" + "im_end|>"
STOP_SEQUENCES = [IM_END, "<|im_start|>"]

N_CTX = int(os.environ.get("PYGENESIS_N_CTX", "8192"))
N_PREDICT = int(os.environ.get("PYGENESIS_N_PREDICT", "2048"))
N_GPU_LAYERS = int(os.environ.get("PYGENESIS_N_GPU_LAYERS", "-1"))


def pygenesis_data_dir() -> Path:
    local = os.environ.get("LOCALAPPDATA") or os.environ.get("XDG_DATA_HOME")
    if local:
        return Path(local) / "Pygenesis"
    return REPO_ROOT / ".pygenesis"


def default_model_dir() -> Path:
    return pygenesis_data_dir() / "models"


def resolve_model_path() -> Path:
    env = os.environ.get("PYGENESIS_MODEL_PATH", "").strip()
    if env:
        return Path(env)

    candidates = [
        default_model_dir() / MODEL_FILENAME,
        REPO_ROOT / MODEL_FILENAME,
    ]
    for path in candidates:
        if path.is_file():
            return path
    return candidates[0]


def gpu_backend() -> str:
    """cuda | vulkan | cpu (auto detecta NVIDIA → cuda, AMD → vulkan, si no cpu)."""
    backend = os.environ.get("PYGENESIS_GPU_BACKEND", "auto").strip().lower()
    if backend in {"cuda", "vulkan", "cpu"}:
        return backend
    return _detect_gpu_backend()


def _detect_gpu_backend() -> str:
    if _has_nvidia_gpu():
        return "cuda"
    if _has_amd_gpu():
        return "vulkan"
    return "cpu"


def _has_nvidia_gpu() -> bool:
    import shutil
    import subprocess

    if not shutil.which("nvidia-smi"):
        return False
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=name", "--format=csv,noheader"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        return result.returncode == 0 and bool(result.stdout.strip())
    except (OSError, subprocess.SubprocessError):
        return False


def _has_amd_gpu() -> bool:
    try:
        import winreg

        with winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r"SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}",
        ) as key:
            index = 0
            while True:
                try:
                    subkey_name = winreg.EnumKey(key, index)
                    with winreg.OpenKey(key, subkey_name) as subkey:
                        try:
                            provider = winreg.QueryValueEx(subkey, "ProviderName")[0]
                            if provider and "AMD" in str(provider).upper():
                                return True
                        except OSError:
                            pass
                        try:
                            name = winreg.QueryValueEx(subkey, "DriverDesc")[0]
                            if name and ("AMD" in str(name).upper() or "RADEON" in str(name).upper()):
                                return True
                        except OSError:
                            pass
                    index += 1
                except OSError:
                    break
    except OSError:
        pass
    return False
