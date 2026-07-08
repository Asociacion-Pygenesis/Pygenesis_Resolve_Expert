"""
Descarga Q&A de Stack Exchange (Video Production, Stack Overflow) para el dataset Resolve.

Salida: data/raw/stackoverflow/resolve_qa.json
Formato compatible con process_dataset.py → load_stackoverflow().

Config: config/stackexchange.json (copia desde stackexchange.example.json).
API key opcional: https://stackapps.com/apps/oauth/register

Uso:
  python scripts/scrape_stackoverflow.py
  python scripts/scrape_stackoverflow.py --dry-run
  python scripts/scrape_stackoverflow.py --max-pages 2
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from html import unescape
from pathlib import Path
from typing import Any

import requests
from tqdm import tqdm

from _training_paths import load_json_config, training_root

API_BASE = "https://api.stackexchange.com/2.3"
SITE_URLS = {
    "stackoverflow": "https://stackoverflow.com",
    "video": "https://video.stackexchange.com",
}


def html_to_text(html: str) -> str:
    if not html:
        return ""
    try:
        from bs4 import BeautifulSoup

        text = BeautifulSoup(html, "html.parser").get_text("\n")
    except ImportError:
        text = re.sub(r"<[^>]+>", " ", html)
    text = unescape(text)
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def _api_get(path: str, params: dict[str, Any], timeout: int = 30) -> dict:
    r = requests.get(f"{API_BASE}/{path}", params=params, timeout=timeout)
    r.raise_for_status()
    data = r.json()
    backoff = data.get("backoff")
    if backoff:
        time.sleep(float(backoff))
    return data


def _matches_keywords(text: str, keywords: list[str]) -> bool:
    if not keywords:
        return True
    low = text.lower()
    return any(k.lower() in low for k in keywords)


def fetch_questions(
    site: str,
    tagged: str,
    *,
    api_key: str,
    pagesize: int,
    max_pages: int,
    page_start: int = 1,
) -> list[dict]:
    items: list[dict] = []
    page = page_start
    while True:
        params: dict[str, Any] = {
            "site": site,
            "tagged": tagged,
            "order": "desc",
            "sort": "votes",
            "pagesize": pagesize,
            "page": page,
            "filter": "withbody",
        }
        if api_key:
            params["key"] = api_key
        data = _api_get("questions", params)
        batch = data.get("items") or []
        if not batch:
            break
        items.extend(batch)
        if not data.get("has_more"):
            break
        if max_pages > 0 and page >= max_pages:
            break
        page += 1
    return items


def fetch_answers_batch(
    site: str,
    question_ids: list[int],
    *,
    api_key: str,
) -> dict[int, list[dict]]:
    out: dict[int, list[dict]] = {qid: [] for qid in question_ids}
    for i in range(0, len(question_ids), 100):
        chunk = question_ids[i : i + 100]
        params: dict[str, Any] = {
            "site": site,
            "order": "desc",
            "sort": "votes",
            "filter": "withbody",
            "pagesize": 100,
        }
        if api_key:
            params["key"] = api_key
        ids = ";".join(str(x) for x in chunk)
        data = _api_get(f"questions/{ids}/answers", params)
        for ans in data.get("items") or []:
            qid = ans.get("question_id")
            if qid in out:
                out[qid].append(ans)
    return out


def pick_answer(answers: list[dict], min_score: int) -> dict | None:
    if not answers:
        return None
    accepted = [a for a in answers if a.get("is_accepted")]
    if accepted:
        best = max(accepted, key=lambda a: a.get("score", 0))
        if best.get("score", 0) >= min_score:
            return best
    ranked = sorted(answers, key=lambda a: a.get("score", 0), reverse=True)
    if ranked and ranked[0].get("score", 0) >= min_score:
        return ranked[0]
    return None


def question_link(site: str, question_id: int) -> str:
    base = SITE_URLS.get(site, f"https://{site}.stackexchange.com")
    return f"{base}/questions/{question_id}"


def scrape_source(
    source: dict,
    *,
    api_key: str,
    pagesize: int,
    max_pages: int,
    min_question_score: int,
    min_answer_score: int,
    sleep_seconds: float,
    seen_ids: set[int],
) -> list[dict]:
    site = source["site"]
    tagged = source.get("tagged") or source.get("tag")
    if not tagged:
        raise ValueError(f"Fuente sin tag: {source}")
    keywords = source.get("keywords") or []

    questions = fetch_questions(
        site,
        tagged,
        api_key=api_key,
        pagesize=pagesize,
        max_pages=max_pages,
    )
    new_questions = [q for q in questions if q.get("question_id") not in seen_ids]
    if not new_questions:
        return []

    qids = [int(q["question_id"]) for q in new_questions]
    answers_by_q = fetch_answers_batch(site, qids, api_key=api_key)
    if sleep_seconds > 0:
        time.sleep(sleep_seconds)

    pairs: list[dict] = []
    for q in new_questions:
        qid = int(q["question_id"])
        seen_ids.add(qid)
        if q.get("score", 0) < min_question_score:
            continue

        title = html_to_text(q.get("title", ""))
        body = html_to_text(q.get("body", ""))
        combined = f"{title}\n\n{body}".strip()
        if not _matches_keywords(combined, keywords):
            continue

        answer = pick_answer(answers_by_q.get(qid, []), min_answer_score)
        if not answer:
            continue

        answer_text = html_to_text(answer.get("body", ""))
        if len(combined) < 20 or len(answer_text) < 50:
            continue

        pairs.append(
            {
                "question_id": qid,
                "site": site,
                "link": question_link(site, qid),
                "tags": q.get("tags") or [],
                "question_score": q.get("score", 0),
                "answer_score": answer.get("score", 0),
                "is_accepted": bool(answer.get("is_accepted")),
                "question": combined,
                "answer": answer_text,
            }
        )
    return pairs


def save_pairs(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(rows, indent=2, ensure_ascii=False), encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description="Scrape Stack Exchange Q&A para DaVinci Resolve")
    ap.add_argument("--dry-run", action="store_true", help="Solo muestra recuentos estimados")
    ap.add_argument("--max-pages", type=int, default=0, help="0 = todas las páginas por fuente")
    ap.add_argument("--append", action="store_true", help="Añadir a resolve_qa.json existente")
    args = ap.parse_args()

    root = training_root()
    try:
        cfg = load_json_config("stackexchange.json")
    except FileNotFoundError:
        print(
            "Falta config/stackexchange.json — copia config/stackexchange.example.json",
            file=sys.stderr,
        )
        return 1

    api_key = (cfg.get("api_key") or "").strip()
    sources = cfg.get("sources") or []
    if not sources:
        print("No hay sources en stackexchange.json", file=sys.stderr)
        return 1

    pagesize = int(cfg.get("pagesize", 100))
    max_pages = args.max_pages or int(cfg.get("max_pages", 0))
    min_q = int(cfg.get("min_question_score", 0))
    min_a = int(cfg.get("min_answer_score", 1))
    sleep_seconds = float(cfg.get("sleep_seconds", 0.35))
    out_rel = cfg.get("output", "data/raw/stackoverflow/resolve_qa.json")
    out_path = (root / out_rel).resolve()

    if args.dry_run:
        print(f"Fuentes configuradas: {len(sources)}")
        for src in sources:
            tag = src.get("tagged", "?")
            site = src.get("site", "?")
            kw = src.get("keywords") or []
            extra = f" (filtro: {kw})" if kw else ""
            print(f"  - {site} / {tag}{extra}")
        print(f"Salida: {out_path}")
        print("Ejecuta sin --dry-run para descargar.")
        return 0

    rows: list[dict] = []
    if args.append and out_path.is_file():
        rows = json.loads(out_path.read_text(encoding="utf-8"))

    seen_ids = {int(r["question_id"]) for r in rows if "question_id" in r}
    added = 0

    for src in sources:
        label = f"{src.get('site')}/{src.get('tagged')}"
        try:
            pairs = scrape_source(
                src,
                api_key=api_key,
                pagesize=pagesize,
                max_pages=max_pages,
                min_question_score=min_q,
                min_answer_score=min_a,
                sleep_seconds=sleep_seconds,
                seen_ids=seen_ids,
            )
        except requests.RequestException as e:
            print(f"Error en {label}: {e}", file=sys.stderr)
            continue
        rows.extend(pairs)
        added += len(pairs)
        save_pairs(out_path, rows)
        print(f"{label}: +{len(pairs)} pares (total {len(rows)})")
        if sleep_seconds > 0:
            time.sleep(sleep_seconds)

    print(f"Guardado {len(rows)} pares en {out_path} (+{added} nuevos)")
    if not api_key:
        print("Tip: añade api_key en stackexchange.json para más cuota diaria (stackapps.com).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
