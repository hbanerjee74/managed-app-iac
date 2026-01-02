import pytest

from scripts.notion_download import extract_page_id, slugify


def test_extract_from_url_with_dashes():
    url = "https://www.notion.so/Workspace/Page-Title-12345678-90ab-cdef-1234-567890abcdef"
    pid = extract_page_id(url)
    assert len(pid) == 32


def test_extract_from_compact():
    compact = "1234567890abcdef1234567890abcdef"
    assert extract_page_id(compact) == compact


def test_slugify_simple():
    assert slugify("Hello World!") == "hello-world"


def test_slugify_empty():
    assert slugify("   ") == "page"
