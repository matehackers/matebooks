#!/usr/bin/env python3
"""Export the MateBooks Turso catalog as a standalone HTML page."""

from __future__ import annotations

import argparse
import base64
import binascii
from datetime import datetime, timezone
import html
import json
import os
from pathlib import Path
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen


QUERY = """
SELECT isbn, title, authors, publisher, published_date, page_count,
       cover_url, cover_image_base64, description, categories, type
FROM books
ORDER BY LOWER(COALESCE(title, '')) ASC
""".strip()

STYLE = """
    :root {
      --ink: #243746;
      --muted: #6d7880;
      --paper: #f7f5f0;
      --card: rgba(255, 255, 255, .88);
      --line: #dedbd3;
      --blue: #42647b;
      --blue-soft: #e7eef2;
      --gold: #b47a36;
      --gold-soft: #f7ecdb;
      --shadow: 0 16px 38px rgba(54, 48, 36, .09);
    }

    * { box-sizing: border-box; }
    [hidden] { display: none !important; }

    body {
      min-width: 320px;
      margin: 0;
      color: var(--ink);
      background:
        radial-gradient(circle at 8% 0%, #e4eff0 0, transparent 27rem),
        radial-gradient(circle at 94% 10%, #f7e8cb 0, transparent 25rem),
        var(--paper);
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      line-height: 1.5;
    }

    .page { width: min(calc(100% - 32px), 1060px); margin: auto; padding: 54px 0 70px; }
    .masthead { display: flex; align-items: end; justify-content: space-between; gap: 28px; margin-bottom: 28px; }
    .eyebrow { margin: 0 0 9px; color: var(--gold); font-size: .72rem; font-weight: 800; letter-spacing: .18em; text-transform: uppercase; }
    h1, h2, p { margin-top: 0; }
    h1 { max-width: 700px; margin-bottom: 10px; color: var(--ink); font: 500 clamp(2.6rem, 7vw, 4.8rem)/.98 Georgia, "Times New Roman", serif; letter-spacing: -.055em; }
    .intro { max-width: 560px; margin: 0; color: var(--muted); }
    .stats { display: flex; flex: 0 0 auto; gap: 8px; }
    .stat { min-width: 78px; padding: 12px 13px; border: 1px solid var(--line); border-radius: 13px; background: rgba(255, 255, 255, .52); text-align: center; }
    .stat strong { display: block; color: var(--blue); font: 500 1.5rem/1 Georgia, "Times New Roman", serif; }
    .stat span { display: block; margin-top: 5px; color: var(--muted); font-size: .65rem; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; }

    .toolbar { position: sticky; top: 14px; z-index: 2; margin-bottom: 22px; padding: 16px 17px 13px; border: 1px solid rgba(255, 255, 255, .8); border-radius: 17px; background: rgba(255, 255, 255, .8); box-shadow: 0 10px 30px rgba(54, 48, 36, .08); backdrop-filter: blur(14px); }
    .toolbar label { display: block; margin-bottom: 8px; color: var(--blue); font-size: .74rem; font-weight: 800; letter-spacing: .12em; text-transform: uppercase; }
    .search-box { display: flex; align-items: center; gap: 10px; min-height: 52px; padding: 0 12px 0 16px; border: 1px solid var(--line); border-radius: 11px; background: #fff; }
    .search-box:focus-within { border-color: var(--blue); box-shadow: 0 0 0 4px rgba(66, 100, 123, .12); }
    .search-icon { color: var(--gold); font-size: 1.3rem; line-height: 1; }
    input { width: 100%; min-width: 0; border: 0; outline: 0; color: var(--ink); background: transparent; font: inherit; font-size: 1rem; }
    input::placeholder { color: #9aa1a5; }
    .clear-button { padding: 7px 10px; border: 0; border-radius: 8px; color: var(--blue); background: var(--blue-soft); cursor: pointer; font: inherit; font-size: .77rem; font-weight: 700; }
    .toolbar-footer { display: flex; justify-content: space-between; gap: 12px; padding: 9px 2px 0; color: var(--muted); font-size: .76rem; }
    #result-count { font-weight: 700; }

    .collection { display: grid; gap: 11px; }
    .collection-item { display: grid; grid-template-columns: 82px minmax(0, 1fr) auto; gap: 19px; align-items: center; min-height: 132px; padding: 13px 17px 13px 13px; border: 1px solid rgba(222, 219, 211, .86); border-radius: 15px; background: var(--card); box-shadow: var(--shadow); transition: transform .16s ease, box-shadow .16s ease, border-color .16s ease; }
    .collection-item:hover { border-color: #c6d5da; box-shadow: 0 21px 48px rgba(54, 48, 36, .13); transform: translateY(-2px); }
    .cover-frame { width: 82px; height: 112px; overflow: hidden; border-radius: 8px; background: #e8e6df; box-shadow: 0 5px 12px rgba(54, 48, 36, .13); }
    .cover-image { display: block; width: 100%; height: 100%; object-fit: cover; }
    .cover-placeholder { display: grid; place-items: center; width: 100%; height: 100%; color: #fff; background: linear-gradient(145deg, #557c8e, #2f5268); }
    .cover-placeholder.magazine { background: linear-gradient(145deg, #c58a49, #865329); }
    .cover-placeholder span { padding: 4px; border: 1px solid rgba(255, 255, 255, .55); font-size: .6rem; font-weight: 800; letter-spacing: .14em; writing-mode: vertical-rl; }
    .item-content { min-width: 0; }
    .type-badge { display: inline-block; margin-bottom: 6px; padding: 4px 8px; border-radius: 999px; color: var(--blue); background: var(--blue-soft); font-size: .65rem; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; }
    .type-badge.magazine { color: #925a1f; background: var(--gold-soft); }
    .collection-item h2 { margin-bottom: 4px; overflow: hidden; color: var(--ink); font: 500 clamp(1.2rem, 2.4vw, 1.6rem)/1.15 Georgia, "Times New Roman", serif; letter-spacing: -.025em; text-overflow: ellipsis; white-space: nowrap; }
    .item-authors { margin-bottom: 8px; overflow: hidden; color: var(--muted); font-size: .91rem; text-overflow: ellipsis; white-space: nowrap; }
    .item-meta { display: flex; flex-wrap: wrap; gap: 4px 13px; color: #69767d; font-size: .76rem; }
    .item-meta span + span::before { margin-right: 13px; color: #b5afa4; content: "/"; }
    .item-isbn { margin-top: 7px; color: #8b9294; font-size: .69rem; letter-spacing: .04em; }
    .item-description { display: -webkit-box; max-width: 680px; margin: 8px 0 0; overflow: hidden; color: #69767d; font-size: .79rem; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }
    .categories { display: flex; flex-wrap: wrap; gap: 5px; margin-top: 8px; }
    .category { padding: 3px 7px; border-radius: 5px; color: #68747a; background: #f0f1ed; font-size: .65rem; }
    .item-mark { align-self: start; color: #c6bcae; font: 1.4rem/1 Georgia, "Times New Roman", serif; }
    .empty-state { display: grid; gap: 5px; justify-items: center; padding: 52px 24px; border: 1px dashed #c9c5bc; border-radius: 15px; color: var(--muted); text-align: center; }
    .empty-state strong { color: var(--blue); font: 500 1.3rem Georgia, "Times New Roman", serif; }
    .footer { margin-top: 26px; color: #92928b; font-size: .7rem; text-align: center; }

    @media (max-width: 720px) {
      .page { width: min(calc(100% - 22px), 600px); padding-top: 34px; }
      .masthead { display: block; }
      .stats { margin-top: 21px; }
      .stat { flex: 1; }
      .collection-item { grid-template-columns: 67px minmax(0, 1fr); gap: 14px; padding-right: 12px; }
      .cover-frame { width: 67px; height: 96px; }
      .item-mark { display: none; }
      .item-description { display: none; }
    }

    @media (max-width: 420px) {
      .toolbar-footer { display: block; }
      .toolbar-footer .hint { display: block; margin-top: 4px; }
    }
"""

SCRIPT = """
    const searchInput = document.querySelector('#search');
    const clearButton = document.querySelector('#clear-search');
    const resultCount = document.querySelector('#result-count');
    const emptyLibrary = document.querySelector('#empty-library');
    const noResults = document.querySelector('#no-results');
    const items = Array.from(document.querySelectorAll('.collection-item'));

    const normalize = (value) => value.toLocaleLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
    const updateResults = () => {
      const query = normalize(searchInput.value.trim());
      let visible = 0;

      items.forEach((item) => {
        const matches = !query || normalize(item.dataset.search || '').includes(query);
        item.hidden = !matches;
        if (matches) visible += 1;
      });

      resultCount.textContent = query
        ? `${visible} matching ${visible === 1 ? 'item' : 'items'}`
        : `${visible} ${visible === 1 ? 'item' : 'items'}`;
      clearButton.hidden = searchInput.value.length === 0;
      if (emptyLibrary) emptyLibrary.hidden = Boolean(query);
      noResults.hidden = !query || visible !== 0;
    };

    items.forEach((item) => {
      const image = item.querySelector('.cover-image');
      if (!image) return;
      image.addEventListener('error', () => {
        image.hidden = true;
        if (image.nextElementSibling) image.nextElementSibling.hidden = false;
      });
    });

    searchInput.addEventListener('input', updateResults);
    clearButton.addEventListener('click', () => {
      searchInput.value = '';
      searchInput.focus();
      updateResults();
    });
    document.addEventListener('keydown', (event) => {
      if (event.key === '/' && document.activeElement !== searchInput) {
        event.preventDefault();
        searchInput.focus();
      }
    });
    updateResults();
"""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a searchable HTML collection from the MateBooks database."
    )
    parser.add_argument("--output", type=Path, default=Path("collection.html"))
    parser.add_argument("--db-url", help="Turso URL (defaults to TURSO_DB_URL)")
    parser.add_argument("--auth-token", help="Turso token (defaults to TURSO_AUTH_TOKEN)")
    parser.add_argument("--env-file", type=Path, default=Path(".env"))
    parser.add_argument("--title", default="MateBooks Collection")
    parser.add_argument("--timeout", type=float, default=30.0)
    return parser.parse_args()


def load_env_file(path: Path) -> None:
    """Load simple KEY=value entries without overriding shell variables."""
    if not path.is_file():
        return
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise RuntimeError(f"Could not read env file {path}: {error}") from error

    for line in lines:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].lstrip()
        if "=" not in line:
            continue
        key, value = (part.strip() for part in line.split("=", 1))
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            continue
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
            value = value[1:-1]
        os.environ.setdefault(key, value)


def decode_cell(cell: object) -> object:
    if not isinstance(cell, dict):
        return cell
    return None if cell.get("type") == "null" else cell.get("value")


def database_error(error: object) -> str:
    if not isinstance(error, dict):
        return str(error)
    message = error.get("message", "Unknown database error")
    code = error.get("code")
    return f"{message} (code: {code})" if code else str(message)


def query_books(db_url: str, auth_token: str, timeout: float) -> list[dict[str, object]]:
    body = {"requests": [{"type": "execute", "stmt": {"sql": QUERY}}]}
    request = Request(
        f"{db_url.rstrip('/')}/v2/pipeline",
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {auth_token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urlopen(request, timeout=timeout) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except HTTPError as error:
        details = error.read().decode("utf-8", "replace")
        raise RuntimeError(f"Turso request failed ({error.code}): {details}") from error
    except URLError as error:
        raise RuntimeError(f"Could not connect to Turso: {error.reason}") from error
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError(f"Could not read the Turso response: {error}") from error

    results = payload.get("results") if isinstance(payload, dict) else None
    if not isinstance(results, list) or not results:
        return []
    first = results[0]
    if not isinstance(first, dict):
        raise RuntimeError("Turso returned an invalid pipeline response")
    if first.get("type") == "error":
        raise RuntimeError(f"Turso error: {database_error(first.get('error'))}")

    response_data = first.get("response")
    result = response_data.get("result") if isinstance(response_data, dict) else None
    if not isinstance(result, dict):
        raise RuntimeError("Turso returned no query result")
    if result.get("error") is not None:
        raise RuntimeError(f"Turso SQL error: {database_error(result['error'])}")

    columns = [
        str(column.get("name", "")) if isinstance(column, dict) else str(column)
        for column in result.get("cols") or []
    ]
    rows = []
    for row in result.get("rows") or []:
        if isinstance(row, dict):
            rows.append({str(key): decode_cell(value) for key, value in row.items()})
        elif isinstance(row, list):
            rows.append({
                columns[index]: decode_cell(cell)
                for index, cell in enumerate(row)
                if index < len(columns) and columns[index]
            })
    return rows


def value(raw: object) -> str:
    if raw is None:
        return ""
    return raw.decode("utf-8", "replace") if isinstance(raw, bytes) else str(raw)


def values(raw: object) -> list[str]:
    return [part.strip() for part in value(raw).split(",") if part.strip()]


def cover_url(raw: object) -> str | None:
    candidate = value(raw).strip()
    parsed = urlparse(candidate)
    return candidate if parsed.scheme.lower() in {"http", "https"} and parsed.netloc else None


def cover_data(raw: object) -> str | None:
    encoded = value(raw).strip()
    if not encoded:
        return None
    if encoded.startswith("data:image/"):
        return encoded
    compact = "".join(encoded.split())
    try:
        image = base64.b64decode(compact, validate=True)
    except (binascii.Error, ValueError):
        return None
    if not image:
        return None
    if image.startswith(b"\x89PNG"):
        mime = "image/png"
    elif image.startswith(b"\xff\xd8\xff"):
        mime = "image/jpeg"
    elif image.startswith((b"GIF87a", b"GIF89a")):
        mime = "image/gif"
    elif image[:4] == b"RIFF" and image[8:12] == b"WEBP":
        mime = "image/webp"
    else:
        mime = "image/jpeg"
    return f"data:{mime};base64,{compact}"


def render_cover(item: dict[str, object], title: str, kind: str) -> str:
    source = cover_data(item.get("cover_image_base64")) or cover_url(item.get("cover_url"))
    label = "MAG" if kind == "magazine" else "BOOK"
    fallback = f'<div class="cover-placeholder {kind}" hidden><span>{label}</span></div>'
    if source is None:
        return f'<div class="cover-frame"><div class="cover-placeholder {kind}"><span>{label}</span></div></div>'
    return (
        '<div class="cover-frame">'
        f'<img class="cover-image" src="{html.escape(source, quote=True)}" '
        f'alt="{html.escape(f"Cover of {title}", quote=True)}" loading="lazy">'
        f"{fallback}</div>"
    )


def render_item(item: dict[str, object]) -> str:
    title = value(item.get("title")).strip() or "Untitled"
    authors = values(item.get("authors"))
    author_text = ", ".join(authors) or "Unknown author"
    kind = "magazine" if value(item.get("type")).lower() == "magazine" else "book"
    kind_label = "Magazine" if kind == "magazine" else "Book"
    search_text = html.escape(" ".join([title, *authors]).casefold(), quote=True)

    metadata = [
        value(item.get("publisher")).strip(),
        value(item.get("published_date")).strip(),
    ]
    pages = value(item.get("page_count")).strip()
    if pages:
        metadata.append(f"{pages} pages")
    metadata_html = "".join(f"<span>{html.escape(entry)}</span>" for entry in metadata if entry)

    isbn = value(item.get("isbn")).strip()
    isbn_html = f'<div class="item-isbn">ISBN/ISSN {html.escape(isbn)}</div>' if isbn else ""
    description = value(item.get("description")).strip()
    description_html = f'<p class="item-description">{html.escape(description)}</p>' if description else ""
    categories_html = "".join(
        f'<span class="category">{html.escape(category)}</span>' for category in values(item.get("categories"))
    )

    return f"""      <article class="collection-item" data-search="{search_text}">
        {render_cover(item, title, kind)}
        <div class="item-content">
          <span class="type-badge {kind}">{kind_label}</span>
          <h2>{html.escape(title)}</h2>
          <p class="item-authors">{html.escape(author_text)}</p>
          <div class="item-meta">{metadata_html}</div>
          {isbn_html}
          {description_html}
          <div class="categories">{categories_html}</div>
        </div>
        <div class="item-mark" aria-hidden="true">+</div>
      </article>"""


def build_html(items: list[dict[str, object]], page_title: str) -> str:
    total = len(items)
    magazines = sum(1 for item in items if value(item.get("type")).lower() == "magazine")
    books = total - magazines
    noun = "item" if total == 1 else "items"
    empty = (
        '<div class="empty-state" id="empty-library">'
        "<strong>Your collection is empty.</strong>"
        "<span>Add a book or magazine in MateBooks, then run this export again.</span>"
        "</div>"
        if not items
        else ""
    )
    entries = "\n".join(render_item(item) for item in items)
    generated = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    title = html.escape(page_title, quote=True)

    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light">
  <title>{title}</title>
  <style>
{STYLE}
  </style>
</head>
<body>
  <main class="page">
    <header class="masthead">
      <div>
        <p class="eyebrow">A personal shelf</p>
        <h1>{title}</h1>
        <p class="intro">A quiet index of the books and magazines in your collection. Search by title or author to find your next read.</p>
      </div>
      <div class="stats" aria-label="Collection totals">
        <div class="stat"><strong>{total}</strong><span>Total</span></div>
        <div class="stat"><strong>{books}</strong><span>Books</span></div>
        <div class="stat"><strong>{magazines}</strong><span>Magazines</span></div>
      </div>
    </header>

    <section class="toolbar" aria-label="Collection search">
      <label for="search">Find in your shelf</label>
      <div class="search-box">
        <span class="search-icon" aria-hidden="true">/</span>
        <input id="search" type="search" placeholder="Search title or author..." autocomplete="off" spellcheck="false">
        <button class="clear-button" id="clear-search" type="button" hidden>Clear</button>
      </div>
      <div class="toolbar-footer">
        <span id="result-count" aria-live="polite">{total} {noun}</span>
        <span class="hint">Press / to focus search</span>
      </div>
    </section>

    <section class="collection" aria-label="Books and magazines">
{entries}
    </section>
    {empty}
    <div class="empty-state" id="no-results" hidden>
      <strong>No matches found.</strong>
      <span>Try a different title or author.</span>
    </div>
    <p class="footer">Generated {generated} from your MateBooks library.</p>
  </main>
  <script>
{SCRIPT}
  </script>
</body>
</html>
"""


def main() -> int:
    args = parse_args()
    try:
        load_env_file(args.env_file)
    except RuntimeError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1

    db_url = (args.db_url or os.getenv("TURSO_DB_URL", "")).strip()
    auth_token = args.auth_token or os.getenv("TURSO_AUTH_TOKEN", "")
    if not db_url or not auth_token:
        print(
            "Error: set TURSO_DB_URL and TURSO_AUTH_TOKEN in the environment or .env, "
            "or pass --db-url and --auth-token.",
            file=sys.stderr,
        )
        return 2
    if urlparse(db_url).scheme.lower() not in {"http", "https"}:
        print("Error: TURSO_DB_URL must start with http:// or https://.", file=sys.stderr)
        return 2

    try:
        items = query_books(db_url, auth_token, args.timeout)
        document = build_html(items, args.title.strip() or "MateBooks Collection")
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(document, encoding="utf-8")
    except (OSError, RuntimeError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1

    print(f"Generated {args.output} with {len(items)} items.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
