# install_kustomize.sh

This script installs or uninstalls [Kustomize](https://github.com/kubernetes-sigs/kustomize), the Kubernetes native configuration management tool, on Linux and macOS. It downloads the official release tarball from GitHub (same **Binaries** path described in the [kubectl documentation for Kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/)) and installs the `kustomize` binary to `/usr/local/bin/kustomize`.

For other install methods (Homebrew, Docker, Go, Chocolatey), see the [official Kustomize installation page](https://kubectl.docs.kubernetes.io/installation/kustomize/).

## Usage

```bash
./install_kustomize.sh [install|uninstall]
```

- **install** (default): Installs the latest Kustomize release (or the version set by `KUSTOMIZE_VERSION`).
- **uninstall**: Removes the `kustomize` binary from `/usr/local/bin`.

## Example Usage

To install the latest Kustomize:

```bash
./install_kustomize.sh
```

Or explicitly:

```bash
./install_kustomize.sh install
```

To install a specific version:

```bash
KUSTOMIZE_VERSION=5.8.1 ./install_kustomize.sh install
```

To uninstall:

```bash
./install_kustomize.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_kustomize.sh) install
```

Optional: set `KUSTOMIZE_VERSION` to pin a semver (e.g. `KUSTOMIZE_VERSION=5.8.1`).

## Verification

After installation, check the version:

```bash
kustomize version
```

## Supported Operating Systems

- Linux (x86_64, arm64)
- macOS (Intel and Apple Silicon)

## Requirements

- `curl` and `tar`
- `sudo` (to install under `/usr/local/bin`)

## Optional environment variables

- **KUSTOMIZE_VERSION** — Pin a release (e.g. `5.8.1`). Default: latest release from [kubernetes-sigs/kustomize](https://github.com/kubernetes-sigs/kustomize/releases).

## Error handling

- If dependencies are missing, the script exits with an error listing them.
- If the download URL fails (wrong version or network), the script reports the failure and exits.
- If the archive does not contain a `kustomize` binary, the script exits with an error.
