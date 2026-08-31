# install_kiro.sh

This script installs or uninstalls [Kiro](https://kiro.dev), an AI-powered development environment from AWS. It follows the steps in [Installing Kiro on Fedora / Red Hat](https://dev.to/jajera/installing-kiro-on-fedora-red-hat-2i9g): download the official IDE tarball from Kiro metadata, install under `~/.local`, create a desktop entry, and optionally install the [Kiro CLI](https://kiro.dev/docs/cli/).

## Usage

```bash
./install_kiro.sh [install|uninstall|install-cli]
```

- **install** (default): Installs the Kiro IDE.
- **install-cli**: Installs only the Kiro CLI (`kiro-cli` / `q`) via the official installer.
- **uninstall**: Removes the local IDE install, desktop entry, and local CLI binaries if present.

## Example Usage

Install the IDE:

```bash
./install_kiro.sh
```

Install IDE and CLI together:

```bash
KIRO_WITH_CLI=1 ./install_kiro.sh install
```

Install CLI only:

```bash
./install_kiro.sh install-cli
```

Uninstall:

```bash
./install_kiro.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_kiro.sh) install
```

Optional: `KIRO_WITH_CLI=1` to also install the CLI.

## Verification

```bash
test -x ~/.local/bin/kiro && echo "kiro binary OK"
test -f ~/.local/share/applications/kiro.desktop && echo "desktop entry OK"
```

Launch the IDE:

```bash
kiro
```

Or open **Kiro** from your application menu (Linux desktop entry).

Note: the IDE binary starts the GUI; it is not a CLI `--version` tool. For CLI tools, use `kiro-cli` after `install-cli`.

CLI (if installed):

```bash
kiro-cli --version
```

## Supported Operating Systems

- **Linux** (x64) — Fedora / RHEL-family and Debian/Ubuntu-family; primary path matches the [Fedora/Red Hat guide](https://dev.to/jajera/installing-kiro-on-fedora-red-hat-2i9g)
- **macOS** — Intel (`x64`) and Apple Silicon (`arm64`) via official zip builds

## Supported Architectures

- **x64** (amd64) — Linux and macOS
- **arm64** — macOS only for the IDE (Linux arm64 IDE metadata is not published; CLI may still install)

## Features

- Resolves the latest IDE URL from official stable metadata (`prod.download.desktop.kiro.dev`)
- Linux: extracts to `~/.local/share/kiro`, symlinks `~/.local/bin/kiro`, creates a `.desktop` entry
- macOS: installs `Kiro.app` under `~/Applications` and symlinks a launcher into `~/.local/bin`
- Optional CLI via `https://cli.kiro.dev/install`
- Ensures `~/.local/bin` is on PATH in `~/.bashrc` / `~/.zshrc` when missing
- Idempotent: skips IDE install if already present (use `KIRO_FORCE=1` to reinstall)
- **Never launches the IDE GUI** during install; version comes from `product.json`
- Uninstall removes local IDE files and common CLI binaries

## Optional environment variables

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `KIRO_WITH_CLI` | `0` | Set to `1` to install CLI during `install` |
| `KIRO_FORCE` | `0` | Set to `1` to reinstall even if IDE is already present |
| `KIRO_SHARE_DIR` | `~/.local/share/kiro` | Linux IDE install directory |
| `KIRO_BIN_DIR` | `~/.local/bin` | Directory for `kiro` / CLI symlinks |
| `KIRO_APPS_DIR` | `~/Applications` | macOS `.app` install directory |
| `KIRO_DESKTOP_DIR` | `~/.local/share/applications` | Linux desktop entry directory |

## Prerequisites

- **curl**, **jq**
- **tar** (Linux) or **unzip** (macOS)
- Package managers used only to install missing deps: `dnf` / `yum` / `apt-get` / `brew`

## Uninstallation

Removes:

- `~/.local/share/kiro` (Linux IDE tree)
- `~/Applications/Kiro.app` (macOS, if used)
- `~/.local/bin/kiro`, and `kiro-cli` / `q` if present under `~/.local/bin`
- `~/.local/share/applications/kiro.desktop`

Does not remove PATH lines added to shell profiles.

## Troubleshooting

1. **`kiro` not found after install**  
   Run `source ~/.bashrc` (or `~/.zshrc`) or open a new terminal. Confirm `~/.local/bin` is in `PATH`.

2. **Desktop entry missing from the menu**  
   Run `update-desktop-database ~/.local/share/applications` or log out and back in.

3. **jq / metadata errors**  
   Install `jq` (`sudo dnf install -y jq`). Metadata URL pattern:  
   `https://prod.download.desktop.kiro.dev/stable/metadata-<platform>-<arch>-stable.json`

4. **Linux arm64 IDE**  
   Official IDE metadata for Linux arm64 is not available; use `install-cli` or an x64 host for the desktop IDE.

## Additional Resources

- [Kiro](https://kiro.dev)
- [Installation docs](https://kiro.dev/docs/getting-started/installation/)
- [Downloads](https://kiro.dev/downloads/)
- [Installing Kiro on Fedora / Red Hat](https://dev.to/jajera/installing-kiro-on-fedora-red-hat-2i9g)
