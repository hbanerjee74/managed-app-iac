from typing import Dict, List


def fetch_page(client, page_id: str) -> Dict:
    """Retrieve a Notion page object."""
    return client.pages.retrieve(page_id)


def fetch_blocks(client, block_id: str) -> List[Dict]:
    """Fetch all child blocks for a block id, handling pagination."""
    blocks = []
    cursor = None
    while True:
        page = client.blocks.children.list(block_id=block_id, start_cursor=cursor, page_size=100)
        blocks.extend(page.get("results", []))
        cursor = page.get("next_cursor")
        if not page.get("has_more"):
            break
    return blocks
