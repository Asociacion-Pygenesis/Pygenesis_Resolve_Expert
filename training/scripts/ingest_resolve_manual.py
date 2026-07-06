"""
Descarga páginas HTML por lista de URLs y las guarda como HTML + texto plano.

Por defecto: documentación DaVinci Resolve (config/resolve_manual_urls.txt →
resolve-docs/html, resolve-manual-txt).

Respeta --delay entre peticiones. Uso personal / investigación; revisa los
términos de uso del sitio que descargues (Blackmagic Design, etc.).

Uso:
  python scripts/ingest_resolve_manual.py
  python scripts/ingest_resolve_manual.py --max-pages 10 --delay 2.0
"""

from __future__ import annotations

import argparse
import re
import time
from pathlib import Path
from urllib.parse import urlparse

import html2text
import requests
from tqdm import tqdm

from _training_paths import training_root

USER_AGENT = "PygenesisResolveExpert-Training/1.0 (+personal dataset; contact: local)"


def _slug_from_url(url: str) -> str:
    path = urlparse(url).path.strip("/").replace("/", "_")
    if not path:
        path = "index"
    return re.sub(r"[^a-zA-Z0-9_.-]+", "_", path)[:180]


def _load_urls(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    out: list[str] = []
    for line in lines:
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        if s.startswith("http"):
            out.append(s)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--urls-file",
        type=Path,
        default=None,
        help="Fichero con una URL por línea (default: config/resolve_manual_urls.txt)",
    )
    ap.add_argument("--max-pages", type=int, default=0, help="0 = todas las URLs del fichero")
    ap.add_argument("--delay", type=float, default=1.5, help="Segundos entre descargas")
    ap.add_argument("--timeout", type=int, default=60)
    ap.add_argument(
        "--raw-html-subdir",
        type=str,
        default="resolve-docs/html",
        help="Subcarpeta bajo data/raw/",
    )
    ap.add_argument(
        "--processed-txt-subdir",
        type=str,
        default="resolve-manual-txt",
        help="Subcarpeta bajo data/processed/",
    )
    ap.add_argument(
        "--job-desc",
        type=str,
        default="Manual Resolve",
        help="Texto de la barra de progreso (tqdm)",
    )
    args = ap.parse_args()

    root = training_root()
    url_file = args.urls_file or (root / "config" / "resolve_manual_urls.txt")
    if not url_file.is_file():
        raise SystemExit(f"No existe {url_file}")

    urls = _load_urls(url_file)
    if args.max_pages > 0:
        urls = urls[: args.max_pages]

    html_dir = (root / "data" / "raw" / Path(args.raw_html_subdir)).resolve()
    txt_dir = (root / "data" / "processed" / Path(args.processed_txt_subdir)).resolve()
    html_dir.mkdir(parents=True, exist_ok=True)
    txt_dir.mkdir(parents=True, exist_ok=True)

    h = html2text.HTML2Text()
    h.ignore_links = False
    h.ignore_images = True
    h.body_width = 0

    session = requests.Session()
    session.headers.update({"User-Agent": USER_AGENT})

    for url in tqdm(urls, desc=args.job_desc):
        slug = _slug_from_url(url)
        try:
            r = session.get(url, timeout=args.timeout)
            r.raise_for_status()
            html = r.text
            (html_dir / f"{slug}.html").write_text(html, encoding="utf-8", errors="ignore")
            text = h.handle(html)
            (txt_dir / f"{slug}.txt").write_text(text, encoding="utf-8", errors="ignore")
        except requests.RequestException as e:
            tqdm.write(f"Fallo {url}: {e}")
        time.sleep(max(0.0, float(args.delay)))

    print(f"HTML en: {html_dir}")
    print(f"TXT en:  {txt_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
