# install_docker.sh

This script installs or uninstalls [Docker Engine](https://docs.docker.com/engine/) on Linux using official package sources. It does **not** use the [get.docker.com](https://get.docker.com/) convenience script (recommended for testing only).

It does not install minikube, Kubernetes, or [Docker Desktop](https://docs.docker.com/desktop/) (macOS/Windows).

## Usage

```bash
./install_docker.sh [install|uninstall]
```

- **install** (default): Installs Docker Engine and starts the `docker` service.
- **uninstall**: Removes Docker packages. Data under `/var/lib/docker` is kept unless `DOCKER_REMOVE_DATA=1`.

## Example Usage

Install on Amazon Linux 2023 (e.g. EC2):

```bash
DOCKER_USER=ec2-user ./install_docker.sh install
```

Install on Ubuntu:

```bash
./install_docker.sh install
```

Install on Fedora:

```bash
./install_docker.sh install
```

Skip the hello-world verification:

```bash
DOCKER_SKIP_VERIFY=1 ./install_docker.sh install
```

Uninstall and remove image/container data:

```bash
DOCKER_REMOVE_DATA=1 ./install_docker.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_docker.sh) install
```

With a user for the docker group:

```bash
DOCKER_USER=ec2-user bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_docker.sh) install
```

## Verification

After installation:

```bash
docker --version
sudo systemctl status docker
```

If you did not set `DOCKER_SKIP_VERIFY=1`, the script runs:

```bash
sudo docker run --rm hello-world
```

After adding `DOCKER_USER`, use a new login session or `newgrp docker` before running Docker without `sudo`.

## Supported Operating Systems (v1)

| OS | Install method | Reference |
| --- | --- | --- |
| **Amazon Linux 2023** | `dnf install docker` (distro package) | Suited for EC2 / minikube docker driver |
| **Ubuntu** | [Docker apt repository](https://docs.docker.com/engine/install/ubuntu/) | `docker-ce` + plugins |
| **Fedora** | [Docker dnf repository](https://docs.docker.com/engine/install/fedora/) | `docker-ce` + plugins |

**Not supported in v1:** Debian, RHEL/CentOS Stream, Amazon Linux 2, macOS (use Docker Desktop).

## Features

- Idempotent: skips install if `docker` is already in `PATH`
- Starts and enables `docker` via systemd where available
- Optional `DOCKER_USER` for [Linux postinstall](https://docs.docker.com/engine/install/linux-postinstall/) group membership
- Optional hello-world verification
- Uninstall follows Docker docs; optional data removal via `DOCKER_REMOVE_DATA`

## Optional environment variables

| Variable | Description |
| --- | --- |
| `DOCKER_USER` | User to add to the `docker` group (e.g. `ec2-user`). Requires re-login or `newgrp docker`. |
| `DOCKER_SKIP_VERIFY` | Set to `1` to skip `docker run hello-world`. |
| `DOCKER_REMOVE_DATA` | Set to `1` on **uninstall** to delete `/var/lib/docker` and `/var/lib/containerd`. |
| `DOCKER_INSTALL_METHOD` | `distro` (AL2023 only) or `ce` (Ubuntu/Fedora). Default: auto per OS. |

## Packages installed (Ubuntu / Fedora)

- `docker-ce`
- `docker-ce-cli`
- `containerd.io`
- `docker-buildx-plugin`
- `docker-compose-plugin`

## Prerequisites

- **sudo** access
- **curl** (Ubuntu/Fedora apt/dnf setup)
- Linux amd64/arm64 as supported by Docker for your distribution

## Use with minikube

This script installs only the Docker Engine. For a local Kubernetes lab:

1. Run this script (e.g. `DOCKER_USER=ec2-user ./install_docker.sh install`)
2. Install minikube: [install_minikube.sh](install_minikube.md)
3. Start a cluster: `minikube start --driver=docker` (as a non-root user)

## Troubleshooting

1. **Permission denied on `docker run`**  
   Add your user with `DOCKER_USER=youruser` and re-login, or use `sudo docker` until the group applies.

2. **Docker service fails to start on Fedora**  
   See [Docker Fedora notes](https://docs.docker.com/engine/install/fedora/) (e.g. `iptables-nft`).

3. **hello-world fails behind a proxy**  
   Set `DOCKER_SKIP_VERIFY=1` and verify manually when network allows.

4. **Amazon Linux 2023 vs docker-ce**  
   v1 uses the Amazon `docker` package by default for compatibility with common EC2/minikube setups. `DOCKER_INSTALL_METHOD=ce` is not supported on AL2023 in v1.

5. **macOS**  
   Install [Docker Desktop](https://docs.docker.com/desktop/setup/install/mac-install/) instead of this script.
