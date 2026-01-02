# Copilot / AI Agent Instructions for notion-cp

Short, focused guidance to help an AI contribute productively to this repository.

## Project snapshot
- Purpose: "Downloads notion markdown files into local folder." (from `README.md`).
- Current files discovered: `README.md`, `LICENSE` (Unlicense). No source code, scripts, or CI workflows were found at scan time.

## Immediate priorities for an AI trying to help
1. Look for missing or overlooked code files: search the repo for `*.py`, `*.js`, `pyproject.toml`, `package.json`, `src/`, or `scripts/`.
2. If no runtime code is present, open an issue or ask maintainers: "Where is the sync script / package? Please point me to the entrypoint or add it so I can run and test changes." Include suggested commands to run once the entrypoint is known.
3. Check for secrets and config: search for `.env`, `secrets`, API keys, or hard-coded tokens. If any are present, flag them and suggest moving to environment variables and adding `.gitignore` entries.

## How to explore (explicit steps)
- Run a repo-wide search for `notion` and `token`/`api_key` to find integration points.
- Inspect `git log --stat` and open recent PRs to see active areas if available.
- Look for CI files under `.github/workflows/` to discover test/build commands.

## Conventions & patterns to follow (repository-specific)
- There are currently no discoverable language or packaging conventions; prefer to follow the repo's existing structure if/when source files appear.
- If you add tooling, document exact commands in `README.md` (examples: how to install deps, run sync, and where output markdown lands).

## Tests & CI
- No tests or CI were found. For any change that adds functionality, include a small reproducible test and update `README.md` with the test/run steps.
- Suggest adding a GitHub Actions workflow that runs linters and tests on push/PR.

## Security & privacy notes 🔒
- This project syncs Notion content; treat any Notion tokens or exported data as sensitive.
- Do not commit secrets. If you find a token exposed, create an urgent issue and propose a remediation (rotate token, remove commit, add `.gitignore`).

## PR & change guidance ✅
- Provide a short, focused description of what you changed and why.
- If adding features that interact with Notion, include a short example command and a note about required env vars.
- Include tests where possible and update `README.md` with usage and install steps.

## Questions for maintainers (to surface in PRs/issues)
- Where is the entrypoint / source code for the sync process?
- Which Notion API integration/token names do you use (env var names)?
- Are there deployment targets or schedules (cron/CI) that we should follow?

---

If you'd like, I can:
- Open a PR that adds this file (done) plus a template issue asking for the missing entrypoint, or
- Draft a starter `pyproject.toml` / `requirements.txt` and a minimal `sync.py` scaffold for you to fill in.

Please review and tell me which sections need more detail or any project-specific commands I should add. — GitHub Copilot
