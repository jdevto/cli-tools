# install_hey.sh

This script installs or removes **hey**, a small HTTP load generator ([rakyll/hey](https://github.com/rakyll/hey)), often used as an ApacheBench-style tool.

## Usage

```bash
./install_hey.sh [install|uninstall]
```

- **install** (default): Downloads a prebuilt binary where available, or uses `go install` on Linux/macOS arm64 when Go is installed.
- **uninstall**: Removes `hey` or `hey.exe` from `HEY_INSTALL_PREFIX` only (does not remove a Homebrew-installed `hey`).

## Example Usage

```bash
./install_hey.sh
```

```bash
./install_hey.sh install
```

Pin a version when using the **go install** path (arm64 Linux/macOS):

```bash
HEY_VERSION=0.1.5 ./install_hey.sh install
```

```bash
./install_hey.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_hey.sh) install
```

Ensure `HEY_INSTALL_PREFIX` is on your `PATH` if it is not already (default: `$HOME/.local/bin`).

## Verification

```bash
command -v hey
hey https://example.com/
```

(`hey` does not expose a dedicated `--version` flag; use `command -v` or a quick request as above.)

## Supported operating systems and architectures

- **Linux (x86_64)**: Prebuilt `hey_linux_amd64` from the [hey installation](https://github.com/rakyll/hey#installation) docs (Google Cloud Storage).
- **macOS (x86_64)**: Prebuilt `hey_darwin_amd64`.
- **Windows (x86_64)**: Prebuilt `hey_windows_amd64` installed as `hey.exe`.
- **Linux or macOS (arm64)**: `go install` when `go` is on your `PATH` (use `HEY_VERSION` or default latest Git tag).

On macOS arm64 you can also use Homebrew: `brew install hey` (see [upstream README](https://github.com/rakyll/hey#installation)).

## Features

- Idempotent: skips install if `hey` is already found on `PATH`
- Uses official GCS binaries documented in the [hey repository](https://github.com/rakyll/hey)
- Optional `go install` fallback on arm64 Linux/macOS
- Configurable install directory via `HEY_INSTALL_PREFIX`

## Optional environment variables

- **`HEY_INSTALL_PREFIX`**: Directory for the binary (default: `$HOME/.local/bin`).
- **`HEY_VERSION`**: Git tag for `go install` only (e.g. `0.1.5`). GCS URLs are not version-specific.

## Prerequisites

- **curl** (for prebuilt downloads)
- **go** (optional, only for arm64 Linux/macOS when prebuilt is unavailable)

## Additional resources

- **Repository**: [github.com/rakyll/hey](https://github.com/rakyll/hey)
