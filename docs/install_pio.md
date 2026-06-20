# install_pio.sh

This script installs or uninstalls [PlatformIO Core](https://platformio.org/) on Linux and macOS using the official [`get-platformio.py`](https://github.com/platformio/platformio-core-installer) installer. PlatformIO is installed into an isolated virtual environment at `$HOME/.platformio/penv`, and the script adds `$HOME/.platformio/penv/bin` to your shell `PATH`.

## Usage

```bash
./install_pio.sh [install|uninstall]
```

- **install** (default): Installs PlatformIO Core (or skips if already installed).
- **uninstall**: Removes `$HOME/.platformio` and the managed PATH block from shell rc files.

## Example Usage

To install PlatformIO:

```bash
./install_pio.sh
```

Or explicitly:

```bash
./install_pio.sh install
```

Use a stable Python (recommended on systems with alpha/pre-release Python as default):

```bash
PLATFORMIO_PYTHON=python3.12 ./install_pio.sh install
```

Pin PlatformIO Core version:

```bash
PLATFORMIO_VERSION=6.1.19 ./install_pio.sh install
```

To uninstall:

```bash
./install_pio.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_pio.sh) install
```

Optional: set `PLATFORMIO_PYTHON` or `PLATFORMIO_VERSION` as needed.

## Verification

After installation, check the version:

```bash
pio --version
```

Or:

```bash
platformio --version
```

Build a project:

```bash
pio run -d firmware
pio test -d firmware -e native
```

## Supported Operating Systems

- **Linux** (glibc and musl)
- **macOS** (Intel and Apple Silicon)

Windows is not supported by this script; use the [official PlatformIO Windows installer](https://docs.platformio.org/page/installation.html).

## Features

- Uses official PlatformIO Core installer script
- Prefers stable Python (`python3.12`, `python3.11`, `python3.10`, `python3.9`, then `python3`)
- Warns when installer Python is pre-release (e.g. alpha)
- Idempotent: skips install when PlatformIO is already present
- Optional version pinning via `PLATFORMIO_VERSION`
- Adds managed PATH block to `~/.bashrc` and `~/.zshrc`
- Treats harmless post-install cleanup tracebacks as non-fatal when binary exists

## Optional environment variables

| Variable | Description |
| -------- | ----------- |
| `PLATFORMIO_CORE_DIR` | PlatformIO home directory (default: `$HOME/.platformio`) |
| `PLATFORMIO_VERSION` | Pin PlatformIO Core version (e.g. `6.1.19`) |
| `PLATFORMIO_PYTHON` | Force Python binary for installer (e.g. `python3.12`) |
| `PLATFORMIO_UPDATE_SHELL_RC` | Set to `false` to skip shell rc PATH updates |

## Prerequisites

- **curl** – required to download the installer
- **Python 3.9+** – required by PlatformIO Core installer (stable release recommended)

## Uninstallation

Uninstall removes:

- `$HOME/.platformio` (including `penv`, packages, and cached platforms)
- Managed PATH block from `~/.bashrc` / `~/.zshrc`

It does not remove PlatformIO project directories or `.pio` build folders inside projects.

## Troubleshooting

1. **`pio: command not found` after install**  
   Open a new shell or run `source ~/.bashrc` (or `source ~/.zshrc`).  
   Verify: `echo $PATH | grep .platformio/penv/bin`

2. **Installer traceback at end but install succeeded**  
   Some Python versions print a harmless multiprocessing temp-dir cleanup error.  
   If `${HOME}/.platformio/penv/bin/platformio` exists, installation succeeded.

3. **Installer fails on alpha/pre-release Python**  
   Install stable Python 3.11/3.12 and rerun with `PLATFORMIO_PYTHON=python3.12`.

4. **Permission errors writing to home directory**  
   Ensure `$HOME/.platformio` is writable by your user.

5. **Need to rebuild PlatformIO toolchains/platforms**  
   After reinstall, first project build may re-download ESP32/platform packages (normal).
