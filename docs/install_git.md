# install_git.sh

This script installs or uninstalls [Git](https://git-scm.com/), the distributed version control system, using the distribution or Homebrew package manager.

## Usage

```bash
./install_git.sh [install|uninstall]
```

- **install** (default): Installs `git` if it is not already on `PATH`.
- **uninstall**: Removes the package when it was installed via a recognized package manager (see below).

## Example usage

```bash
./install_git.sh
```

```bash
./install_git.sh install
```

```bash
./install_git.sh uninstall
```

## Running without cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_git.sh) install
```

Non-interactive installs use `DEBIAN_FRONTEND=noninteractive` on Debian/Ubuntu where applicable.

## Verification

```bash
git --version
```

```bash
git --help
```

## Supported platforms

| Platform | Package manager | Package name |
|----------|-----------------|--------------|
| Debian / Ubuntu | `apt-get` / `apt` | `git` |
| Fedora / RHEL (dnf) | `dnf` | `git` |
| RHEL / CentOS (yum) | `yum` | `git` |
| openSUSE | `zypper` | `git` |
| Arch Linux | `pacman` | `git` |
| Alpine | `apk` | `git` |
| macOS | [Homebrew](https://brew.sh) | `git` |

## Features

- **Idempotent install**: skips if `git` is already on `PATH`.
- **Uninstall** removes the distro/Homebrew package when detected; if `git` was installed from source or another method, the script prints a short message and does not force-remove binaries.

## Requirements

- `sudo` on Linux (Homebrew on macOS does not use `sudo` for `brew` itself).
- One of the package managers listed above.

## Documentation

- [Git official site](https://git-scm.com/)
- [Download for Linux](https://git-scm.com/download/linux)
- [Pro Git book](https://git-scm.com/book)
