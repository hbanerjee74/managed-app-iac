"""Simple Notion page downloader: fetch page blocks and write Markdown.

Usage:
  - Install deps: pip install -r requirements.txt
  - Set env: NOTION_API_KEY (or create a .env file)
  - Run: python scripts/notion_download.py -p <notion_page_url_or_id>

This script retrieves the page object and its child blocks (with pagination) and
converts them to a minimal Markdown representation. Images remain as external URLs.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path
from typing import Dict, List

try:
    from notion_client import Client
except Exception:  # pragma: no cover - import error handled at runtime
    Client = None  # type: ignore

try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

NOTION_API_KEY_ENV = "NOTION_API_KEY"
PAGE_ID_RE = re.compile(r"([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})")
PAGE_ID_RE_COMPACT = re.compile(r"([0-9a-fA-F]{32})")


def extract_page_id(url_or_id: str) -> str:
    """Extract a Notion page id from a URL or return it if already an id.

    Returns the compact 32-hex char id (no dashes).
    """
    m = PAGE_ID_RE.search(url_or_id)
    if m:
        return m.group(1).replace("-", "")
    m2 = PAGE_ID_RE_COMPACT.search(url_or_id)
    if m2:
        return m2.group(1)
    cleaned = url_or_id.strip().replace("/", "").replace("-", "")
    if len(cleaned) == 32 and all(c in "0123456789abcdefABCDEF" for c in cleaned):
        return cleaned
    raise ValueError("Could not extract a Notion page id from the input")


def slugify(s: str) -> str:
    s = s.strip().lower()
    s = re.sub(r"[^a-z0-9\-\_]+", "-", s)
    s = re.sub(r"-+", "-", s)
    return s.strip("-")[:200] or "page"


def get_page_title(page: Dict) -> str:
    props = page.get("properties", {}) if page else {}
    for k, v in props.items():
        if v.get("type") == "title":
            rich = v.get("title", [])
            if rich:
                txt = "".join([t.get("plain_text", "") for t in rich])
                if txt:
                    return txt
    return page.get("id", "page")


def fetch_blocks(client: Client, block_id: str) -> List[Dict]:
    """Fetch all child blocks for a block id, handling pagination."""
    blocks: List[Dict] = []
    cursor = None
    while True:
        page = client.blocks.children.list(block_id=block_id, start_cursor=cursor, page_size=100)
        blocks.extend(page.get("results", []))
        cursor = page.get("next_cursor")
        if not page.get("has_more"):
            break
    return blocks


def block_to_markdown(block: Dict, client: Client = None, indent: int = 0) -> str:
    t = block.get("type")
    indent_str = "  " * indent
    if t == "paragraph":
        text = "".join([r.get("plain_text", "") for r in block["paragraph"].get("rich_text", [])])
        return f"{indent_str}{text}\n\n"
    if t in ("heading_1", "heading_2", "heading_3"):
        level = {"heading_1": "#", "heading_2": "##", "heading_3": "###"}[t]
        text = "".join([r.get("plain_text", "") for r in block[t].get("rich_text", [])])
        return f"{level} {text}\n\n"
    if t in ("bulleted_list_item", "numbered_list_item"):
        marker = "-" if t == "bulleted_list_item" else "1."  # simple numbered
        text = "".join([r.get("plain_text", "") for r in block[t].get("rich_text", [])])
        md = f"{indent_str}{marker} {text}\n"
        # children
        if block.get("has_children") and client:
            children = fetch_blocks(client, block.get("id"))
            for c in children:
                md += block_to_markdown(c, client=client, indent=indent + 1)
        return md
    if t == "code":
        lang = block["code"].get("language", "")
        code = "".join([r.get("plain_text", "") for r in block["code"].get("rich_text", [])])
        return f"```{lang}\n{code}\n```\n\n"
    if t == "quote":
        text = "".join([r.get("plain_text", "") for r in block["quote"].get("rich_text", [])])
        return f"> {text}\n\n"
    if t == "image":
        src = block["image"].get("file", {}).get("url") or block["image"].get("external", {}).get("url")
        caption = "".join([r.get("plain_text", "") for r in block["image"].get("caption", [])])
        return f"![{caption}]({src})\n\n"
    # fallback: show raw JSON snippet
    return f"{indent_str}```json\n{block}\n```\n\n"


def convert_blocks_to_markdown(blocks: List[Dict], client: Client = None) -> str:
    md = ""
    for b in blocks:
        md += block_to_markdown(b, client=client)
    return md


def main(argv=None):
    parser = argparse.ArgumentParser(description="Download a Notion page as Markdown")
    parser.add_argument("-p", "--page", required=True, help="Notion page URL or page id")
    parser.add_argument("-o", "--output", help="Output file path (optional)")
    args = parser.parse_args(argv)

    api_key = os.getenv(NOTION_API_KEY_ENV)
    if not api_key:
        print(f"Error: set ${NOTION_API_KEY_ENV} (or put it in .env)")
        sys.exit(2)

    if Client is None:
        print("Error: `notion-client` package is required. Install with `pip install notion-client`")
        sys.exit(2)

    try:
        page_id = extract_page_id(args.page)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(2)

    client = Client(auth=api_key)

    page = client.pages.retrieve(page_id)
    title = get_page_title(page)

    blocks = fetch_blocks(client, page_id)
    md = f"# {title}\n\n" + convert_blocks_to_markdown(blocks, client=client)

    out_path = Path(args.output) if args.output else Path("output") / f"{slugify(title) or page_id}.md"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(md, encoding="utf-8")

    print(f"Saved Markdown to {out_path}")


if __name__ == "__main__":
    main()
