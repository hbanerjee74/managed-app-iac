from typing import Dict, List
from .api import fetch_blocks


def block_to_markdown(block: Dict, client=None, indent: int = 0) -> str:
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
    # fallback: raw JSON snippet
    return f"{indent_str}```json\n{block}\n```\n\n"


def convert_blocks_to_markdown(blocks: List[Dict], client=None) -> str:
    md = ""
    for b in blocks:
        md += block_to_markdown(b, client=client)
    return md
