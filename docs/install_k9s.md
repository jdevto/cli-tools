# install_k9s.sh

This script installs or uninstalls [k9s](https://github.com/derailed/k9s), a terminal UI to manage Kubernetes clusters, on Linux and macOS. It downloads the official binary from GitHub releases and installs it to `/usr/local/bin/k9s`.

## Usage

```bash
./install_k9s.sh [install|uninstall]
```

- **install** (default): Installs the latest k9s version (or the version set by `K9S_VERSION`).
- **uninstall**: Removes the k9s binary from `/usr/local/bin`.

## Example Usage

To install the latest k9s:

```bash
./install_k9s.sh
```

Or explicitly:

```bash
./install_k9s.sh install
```

To install a specific version:

```bash
K9S_VERSION=0.50.18 ./install_k9s.sh install
```

To uninstall:

```bash
./install_k9s.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_k9s.sh) install
```

Optional: set `K9S_VERSION` to pin a version (e.g. `K9S_VERSION=0.50.18`).

## Verification

After installation, check the version:

```bash
k9s version
```

Run k9s (requires a configured `kubectl` and cluster access):

```bash
k9s
```

## Supported Operating Systems

- **Linux** (any distribution with `curl` and `tar`)
- **macOS** (Intel and Apple Silicon)

## Supported Architectures

- **x86_64** (amd64)
- **aarch64 / arm64** (including Apple Silicon)

## Features

- Idempotent: skips install if the same version is already installed
- Optional version pinning via `K9S_VERSION`
- Detects platform (Linux/Darwin) and architecture (amd64/arm64)
- Installs to `/usr/local/bin/k9s` (uses `sudo` for copy)
- Cleans up temporary files on exit

## Optional environment variables

| Variable      | Description                                      |
| ------------- | ------------------------------------------------ |
| `K9S_VERSION` | Pin version (e.g. `0.50.18`). Omit for latest.   |

## Prerequisites

- **curl** – required for downloading the release tarball
- **kubectl** – not installed by this script; required at runtime to use k9s with a cluster

## Uninstallation

Uninstall removes `/usr/local/bin/k9s` only. It does not remove kubectl or any k9s config under `~/.config/k9s` or `~/.k9s`.

## Troubleshooting

1. **k9s not found after install**  
   Ensure `/usr/local/bin` is in your `PATH`. Run `k9s version` in a new shell.

2. **Download fails**  
   Check network access to `github.com` and that the release and asset exist for your platform/arch (e.g. `k9s_Linux_amd64.tar.gz`).

3. **Permission denied**  
   The script uses `sudo` to write to `/usr/local/bin`. Ensure you have sudo rights.

4. **k9s runs but shows no clusters**  
   Configure `kubectl` (e.g. `kubectl config use-context ...` or set `KUBECONFIG`) so k9s can connect to your cluster.
