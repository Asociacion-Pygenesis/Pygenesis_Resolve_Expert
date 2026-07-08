"""
Extrae texto de PDFs en fuentesTrainning/ → data/processed/resolve-pdf-txt/*.txt

Un .txt por PDF (todas las páginas concatenadas). Luego:
  python scripts/generate_qa_from_manual.py --corpus resolve_pdf ...

Asegúrate de tener derecho a usar el PDF para tu dataset (licencia del editor).

Uso:
  python scripts/ingest_pdf_manual.py
  python scripts/ingest_pdf_manual.py --max-pages-per-pdf 5
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from tqdm import tqdm

from _training_paths import pdf_sources_dir, training_root


def _slug(name: str) -> str:
    stem = Path(name).stem
    s = re.sub(r"[^a-zA-Z0-9_.-]+", "_", stem).strip("_")
    return (s or "manual")[:180]


def _extract_pdf(path: Path, max_pages: int) -> str:
    try:
        from pypdf import PdfReader
    except ImportError as e:
        raise SystemExit(
            "Falta pypdf. Instala con: pip install pypdf\n"
            "(o re-ejecuta scripts/setup_env_windows.ps1 tras añadir pypdf a requirements.)"
        ) from e

    reader = PdfReader(str(path))
    n = len(reader.pages)
    limit = n if max_pages <= 0 else min(n, max_pages)
    parts: list[str] = []
    for i in range(limit):
        t = reader.pages[i].extract_text()
        if t and t.strip():
            parts.append(t.strip())
    return "\n\n".join(parts)


def main() -> int:
    ap = argparse.ArgumentParser(description="PDF → texto plano para pipeline manual/Q&A")
    ap.add_argument(
        "--pdf-dir",
        type=Path,
        default=None,
        help="Carpeta con .pdf (default: fuentesTrainning/)",
    )
    ap.add_argument(
        "--out-txt-dir",
        type=Path,
        default=None,
        help="Salida .txt (default: data/processed/resolve-pdf-txt)",
    )
    ap.add_argument("--max-pdfs", type=int, default=0, help="0 = todos los PDF del directorio")
    ap.add_argument(
        "--max-pages-per-pdf",
        type=int,
        default=0,
        help="0 = todas las páginas de cada PDF (útil para pruebas rápidas)",
    )
    args = ap.parse_args()

    root = training_root()
    pdf_dir = (args.pdf_dir or pdf_sources_dir()).resolve()
    out_dir = (args.out_txt_dir or (root / "data" / "processed" / "resolve-pdf-txt")).resolve()

    if not pdf_dir.is_dir():
        print("No existe la carpeta:", pdf_dir, file=sys.stderr)
        return 1

    pdfs = sorted(pdf_dir.glob("*.pdf"))
    if not pdfs:
        print("No hay archivos .pdf en", pdf_dir, file=sys.stderr)
        return 1

    if args.max_pdfs > 0:
        pdfs = pdfs[: args.max_pdfs]

    out_dir.mkdir(parents=True, exist_ok=True)
    for pdf_path in tqdm(pdfs, desc="PDF->txt"):
        slug = _slug(pdf_path.name)
        out_path = out_dir / f"{slug}.txt"
        try:
            text = _extract_pdf(pdf_path, args.max_pages_per_pdf)
        except Exception as e:  # noqa: BLE001 — mostrar fallo por archivo
            tqdm.write(f"Fallo {pdf_path.name}: {e}")
            continue
        if len(text.strip()) < 200:
            tqdm.write(f"Poco texto extraído (¿PDF escaneado?): {pdf_path.name}")
        out_path.write_text(text, encoding="utf-8", errors="ignore")

    print(f"TXT en: {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
