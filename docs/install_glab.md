# install_glab.sh

This script installs or uninstalls [GLab](https://gitlab.com/gitlab-org/cli), the official open source GitLab CLI, on **Linux** and **macOS**. It downloads the **prebuilt tarball** from the [GitLab releases page](https://gitlab.com/gitlab-org/cli/-/releases), consistent with the “download a binary” path described under [Other installation methods](https://gitlab.com/gitlab-org/cli/#other-installation-methods). Homebrew (`brew install glab`) remains the [officially supported package manager](https://gitlab.com/gitlab-org/cli/#homebrew) for macOS and Linux; this script is for environments where you want a fixed install path (`/usr/local/bin/glab`) without Homebrew.

## Usage

```bash
./install_glab.sh [install|uninstall]
```

- **install** (default): Installs the latest release (or the version set by `GLAB_VERSION`).
- **uninstall**: Removes the `glab` binary from `/usr/local/bin`.

## Example Usage

```bash
./install_glab.sh
./install_glab.sh install
GLAB_VERSION=1.90.0 ./install_glab.sh install
./install_glab.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_glab.sh) install
```

Optional: set `GLAB_VERSION` to pin a release (e.g. `GLAB_VERSION=1.90.0`).

## Verification

```bash
glab version
glab --help
```

Authenticate when ready:

```bash
glab auth login
```

## Supported operating systems and architectures

- **Linux** (`linux/amd64`, `linux/arm64`)
- **macOS** (`darwin/amd64`, `darwin/arm64`)

## Features

- Uses official release assets: `glab_<version>_<os>_<arch>.tar.gz` from [gitlab-org/cli releases](https://gitlab.com/gitlab-org/cli/-/releases).
- Resolves “latest” via the GitLab Releases API.
- Idempotent: skips install if the same version is already installed.
- Optional version pin: `GLAB_VERSION` (with or without a leading `v`).

## Optional environment variables

| Variable | Description |
| -------- | ----------- |
| `GLAB_VERSION` | Pin version (e.g. `1.90.0`). Default: latest from GitLab. |

## Prerequisites

- **curl** – required to download the release tarball.
- **sudo** – required to install under `/usr/local/bin`.

## Uninstallation

Removes only `/usr/local/bin/glab`. Configuration under `~/.config/glab` is not deleted.

## See also

- [GitLab CLI project](https://gitlab.com/gitlab-org/cli)
- [Other installation methods](https://gitlab.com/gitlab-org/cli/#other-installation-methods) (Homebrew, Snap, distro packages, etc.)
- [Releases / binaries](https://gitlab.com/gitlab-org/cli/-/releases)
