# notion-cp
Downloads notion markdown files into local folder.

## Overview
Simple tool to download a Notion page as Markdown using a Notion integration API key.

## Quick start
1. Create a virtualenv and install dependencies:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

2. Provide your Notion integration key via an environment variable (or a `.env` file):

```bash
export NOTION_API_KEY="secret"
# or create a .env file with:
# NOTION_API_KEY=secret
```

3. Run the downloader:

```bash
python scripts/notion_download.py -p https://www.notion.so/your-page-url
# or
python scripts/notion_download.py --page <page-id-or-url> -o saved_page.md
```

Output is written to `output/<page-title>.md` by default.

## Running tests

```bash
pytest -q
```

## Notes
- The script supports common block types (paragraphs, headings, lists, code, quotes, images) but is intentionally minimal; open an issue if you need richer conversion (tables, toggles, callouts).

