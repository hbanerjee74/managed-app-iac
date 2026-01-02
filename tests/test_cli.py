import json
from pathlib import Path

import pytest

from scripts import notion_download


class DummyPage:
    def __init__(self, title):
        self._title = title

    def get(self, key, default=None):
        if key == "properties":
            return {"Title": {"type": "title", "title": [{"plain_text": self._title}]}}
        return default


def test_cli_writes_markdown(tmp_path, monkeypatch):
    fake_title = "My Page"
    fake_id = "1234567890abcdef1234567890abcdef"
    fake_page = {"id": fake_id, "properties": {"T": {"type": "title", "title": [{"plain_text": fake_title}]}}}
    fake_blocks = [{"type": "paragraph", "paragraph": {"rich_text": [{"plain_text": "content"}]}}]

    monkeypatch.setattr(notion_download.api, "fetch_page", lambda client, pid: fake_page)
    monkeypatch.setattr(notion_download.api, "fetch_blocks", lambda client, pid: fake_blocks)
    monkeypatch.setenv("NOTION_API_KEY", "fake")

    out = tmp_path / "out.md"
    notion_download.main(["-p", fake_id, "-o", str(out)])

    assert out.exists()
    content = out.read_text(encoding="utf-8")
    assert "# My Page" in content
    assert "content" in content
