setup:
	python3 -m venv .venv || true
	. .venv/bin/activate && python -m pip install --upgrade pip
	. .venv/bin/activate && python -m pip install -r requirements.txt

install:
	python3 -m pip install --upgrade pip
	python3 -m pip install -r requirements.txt

test:
	@if [ -f .venv/bin/activate ]; then \
		. .venv/bin/activate && pytest -q; \
	else \
		command -v pytest >/dev/null 2>&1 || { echo "pytest not found. Run `make setup` (recommended) or `make install` to install dependencies."; exit 1; }; \
		python3 -m pytest -q; \
	fi

export:
	@echo "Usage: make export PAGE=<notion_page_url_or_id> [OUT=path]"
	python3 scripts/notion_download.py -p $(PAGE) -o $(OUT)
