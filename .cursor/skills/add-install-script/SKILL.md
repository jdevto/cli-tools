---
name: add-install-script
description: Add a new install/uninstall or similar CLI script to cli-tools: create script in scripts/, doc in docs/, and README entry. Use when the user wants to add a new tool script.
---

# Add install script to cli-tools

Use this skill when adding a new script (install/uninstall or similar) to the repo. You will create three things: the script, its doc, and README updates.

## Workflow

1. **Script name** — Use a **verb prefix**, lowercase with underscores. Examples: `install_<tool>.sh`, `get_<thing>.py`, `sync_<thing>.sh`, `manage_<thing>.sh`, `setup_<thing>.sh`. Confirm with the user or infer from the tool (e.g. `install_foo.sh`, `get_twitch_schedule.py`, `manage_bar.sh`).

2. **Create the script** in `scripts/<name>.sh`:
   - Follow the **shell-scripts** rule (`.cursor/rules/shell-scripts.mdc`): `#!/bin/bash`, `set -e`, `cleanup` + `trap cleanup EXIT`, `usage()` with Usage/Examples/env vars.
   - For install scripts: idempotent install (skip if already installed), platform/arch detection if downloading binaries.
   - Use [scripts/install_uv.sh](scripts/install_uv.sh) as a template (structure, usage, install/uninstall, optional env var).

3. **Create the doc** in `docs/<name>.md`:
   - Follow the **docs-and-markdown** rule: H1 = script name, then Usage, Example Usage, Verification, Supported OS/arch, Features, optional env vars.
   - Use [docs/install_uv.md](docs/install_uv.md) as a template (sections and fenced code with `bash`).

4. **Update README**:
   - **Table of contents**: add one line `- [<name>.sh](docs/<name>.md)` in the same order/style as existing entries.
   - **Overview**: add one bullet with script name, link to doc, and a one-line description.

## Checklist

- [ ] Script in `scripts/` with correct shebang, set -e, cleanup trap, usage()
- [ ] Doc in `docs/` with H1, Usage, Example Usage, Verification, Supported OS/arch, Features
- [ ] README TOC line and Overview bullet added
- [ ] All fenced code blocks use a language (e.g. `bash`)

## Reference

- Shell conventions: [.cursor/rules/shell-scripts.mdc](../../rules/shell-scripts.mdc)
- Doc conventions: [.cursor/rules/docs-and-markdown.mdc](../../rules/docs-and-markdown.mdc)
- Script template: [scripts/install_uv.sh](../../../scripts/install_uv.sh)
- Doc template: [docs/install_uv.md](../../../docs/install_uv.md)
