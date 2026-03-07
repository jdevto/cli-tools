# cli-tools — Agent instructions

This repository is a collection of command-line scripts: install/uninstall tools (e.g. UV, Terraform, kubectl), manage/sync/setup utilities (Kafka, GitHub repos, MSK IAM), and one Python CLI for Bitwarden Secrets Manager. Each script has a single documentation file in `docs/`, and the README provides a table of contents and an overview linking to each doc.

- **Scripts** live in `scripts/` (Bash `.sh` and one Python script). Follow `.cursor/rules/` when editing: use **shell-scripts** for `scripts/**/*.sh` and **python-cli** for `scripts/**/*.py`.
- **Docs** live in `docs/` (one `.md` per script). Follow the **docs-and-markdown** rule for `docs/**/*.md` and `README.md`.
- When **adding a new script**, use the project skill **add-install-script**: it creates the script in `scripts/`, the doc in `docs/`, and updates the README (TOC + overview).
- **MCP** is optional for this repo. Project-level config is `.cursor/mcp.json`; user-level is `~/.cursor/mcp.json`. You can leave project MCP empty.
