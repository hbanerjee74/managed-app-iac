import re
from typing import Dict

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
