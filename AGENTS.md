# Repository Guidelines

## Project Structure & Module Organization
- `scripts/notion_download.py` is the CLI entry point that orchestrates API fetch + Markdown conversion.
- Core conversion and helpers live in `scripts/n2m/` (e.g., `api.py`, `convert.py`, `utils.py`).
- Tests are under `tests/` and follow `test_*.py` naming.
- Tooling and deps: `Makefile` defines workflows and `requirements.txt` pins Python packages.
- Default exports land in `output/` as `<page-title>.md` unless `-o/OUT` is provided.

## Build, Test, and Development Commands
Use the Makefile for repeatable local workflows:

```bash
make setup   # create .venv, upgrade pip, install deps
make install # install deps to current Python
make test    # run pytest -q (uses .venv if present)
make export PAGE=<page-url-or-id> [OUT=path]
```

Direct CLI usage:

```bash
python3 scripts/notion_download.py -p <page-url-or-id> -o output/page.md
pytest -q
```

## Coding Style & Naming Conventions
- Python uses 4-space indentation; prefer clear, minimal stdlib-style code.
- Use `snake_case` for functions/variables and `PascalCase` for classes.
- Keep modules small and focused; add new Notion block handling in `scripts/n2m/`.
- Tests should be `test_<feature>.py` with `test_<behavior>()` functions.

## Testing Guidelines
- Framework: `pytest` (declared in `requirements.txt`).
- Run the full suite with `make test` or `pytest -q`.
- Add/adjust tests in `tests/` when you change conversion or API logic.

## Commit & Pull Request Guidelines
- Recent commits use short, sentence-style messages (e.g., “Updated …”, “added …”).
  Follow that tone and keep commits scoped to a single change.
- PRs should include a concise summary, test results (e.g., `make test`), and
  sample output or screenshots if behavior changes affect exported Markdown.

## Security & Configuration Tips
- Provide `NOTION_API_KEY` via environment or a local `.env`; never commit secrets.
- Avoid sharing real Notion content in sample outputs or tests.
