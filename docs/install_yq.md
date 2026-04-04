# install_yq.sh

This script installs or uninstalls [yq](https://github.com/mikefarah/yq) (the Go-based YAML, JSON, and XML processor) on Linux and macOS. It downloads the official release binary from GitHub and installs it to `/usr/local/bin/yq`.

This is **not** the unrelated [Python `yq` wrapper](https://pypi.org/project/yq/) around `jq`; the install script only targets **mikefarah/yq**.

## Usage

```bash
./install_yq.sh [install|uninstall]
```

- **install** (default): Installs the latest yq release (or the version set by `YQ_VERSION`).
- **uninstall**: Removes the `yq` binary from `/usr/local/bin`.

## Example usage

Install the latest release:

```bash
./install_yq.sh
```

Or explicitly:

```bash
./install_yq.sh install
```

Pin a version:

```bash
YQ_VERSION=4.52.5 ./install_yq.sh install
```

Uninstall:

```bash
./install_yq.sh uninstall
```

## Running without cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_yq.sh) install
```

Optional: set `YQ_VERSION` to pin a semver (for example `YQ_VERSION=4.52.5`).

## Verification

After installation:

```bash
yq --version
```

You should see a line mentioning `mikefarah/yq` and a version number.

## Supported operating systems

- Linux (x86_64, arm64)
- macOS (Intel and Apple Silicon)

## Supported architectures

- `x86_64` / `amd64`
- `aarch64` / `arm64`

## Features

- Idempotent **install**: skips download if mikefarah/yq is already installed at the requested version.
- Optional **version pin** via `YQ_VERSION`.
- **Uninstall** removes the binary from `/usr/local/bin`.

## Requirements

- `curl`
- `sudo` (to install under `/usr/local/bin`)

## Optional environment variables

- **YQ_VERSION** — Pin a release (for example `4.52.5` or `v4.52.5`). Default: latest release from [mikefarah/yq releases](https://github.com/mikefarah/yq/releases).

## Error handling

- Missing dependencies are reported and the script exits with an error.
- Failed downloads (bad version or network) are reported with the URL attempted.
- If another `yq` on `PATH` is not mikefarah/yq, the version check treats it as unknown and the script will still download and install to `/usr/local/bin` (ensure `PATH` prefers `/usr/local/bin` if you rely on this binary).
