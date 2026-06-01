# install_minikube.sh

This script installs or uninstalls [minikube](https://minikube.sigs.k8s.io/) on Linux and macOS. It downloads the official binary from [Google Cloud Storage releases](https://storage.googleapis.com/minikube/releases/) and installs it to `/usr/local/bin/minikube`, following the [minikube start](https://minikube.sigs.k8s.io/docs/start/) installation steps.

This script installs the **binary only**. It does not run `minikube start`, configure drivers, or create a cluster.

## Usage

```bash
./install_minikube.sh [install|uninstall]
```

- **install** (default): Installs the latest minikube release (or the version set by `MINIKUBE_VERSION`).
- **uninstall**: Removes the minikube binary from `/usr/local/bin`.

## Example Usage

To install the latest minikube:

```bash
./install_minikube.sh
```

Or explicitly:

```bash
./install_minikube.sh install
```

To install a specific version:

```bash
MINIKUBE_VERSION=v1.38.1 ./install_minikube.sh install
```

To uninstall:

```bash
./install_minikube.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_minikube.sh) install
```

Optional: set `MINIKUBE_VERSION` to pin a version (e.g. `MINIKUBE_VERSION=v1.38.1`).

## Verification

After installation, check the version:

```bash
minikube version
```

Start a cluster (requires a supported driver such as Docker, and a non-root user):

```bash
minikube start --driver=docker
```

## Supported Operating Systems

- **Linux** (any distribution with `curl`)
- **macOS** (Intel and Apple Silicon)

## Supported Architectures

- **x86_64** (amd64)
- **aarch64 / arm64** (including Apple Silicon)

## Features

- Idempotent: skips install if the same version is already installed
- Optional version pinning via `MINIKUBE_VERSION`
- Detects platform (`linux` / `darwin`) and architecture (`amd64` / `arm64`)
- Downloads from official `storage.googleapis.com/minikube/releases` URLs
- Installs with `install -m 0755` to `/usr/local/bin/minikube` (uses `sudo`)
- Cleans up temporary files on exit

## Optional environment variables

| Variable           | Description                                                |
| ------------------ | ---------------------------------------------------------- |
| `MINIKUBE_VERSION` | Pin version (e.g. `v1.38.1` or `1.38.1`). Omit for latest. |

## Prerequisites

- **curl** – required for downloading the release binary
- **Driver** – not installed by this script; required at runtime (e.g. [Docker](https://minikube.sigs.k8s.io/docs/drivers/docker/) for `minikube start --driver=docker`)
- **kubectl** – not installed by this script; optional but commonly used with minikube

## Uninstallation

Uninstall removes `/usr/local/bin/minikube` only. It does not remove clusters, the `~/.minikube` directory, or any driver (Docker, etc.).

## Troubleshooting

1. **minikube not found after install**  
   Ensure `/usr/local/bin` is in your `PATH`. Run `minikube version` in a new shell.

2. **Download fails**  
   Check network access to `storage.googleapis.com` and that the release exists for your platform/arch (e.g. `minikube-linux-amd64`).

3. **Permission denied**  
   The script uses `sudo` to write to `/usr/local/bin`. Ensure you have sudo rights.

4. **`minikube start` fails**  
   Install and start a supported driver (e.g. Docker), ensure your user is in the `docker` group where applicable, and do not run minikube as root. See [minikube docs](https://minikube.sigs.k8s.io/docs/).

5. **Wrong or old version after install**  
   Pin explicitly with `MINIKUBE_VERSION=vX.Y.Z` or uninstall and reinstall.
