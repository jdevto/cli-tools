# install_ag.sh

This script installs or uninstalls **ag** ([The Silver Searcher](https://github.com/ggreer/the_silver_searcher)), a fast, `ack`-like code search tool that respects `.gitignore`, using the distribution or Homebrew package manager.

The approach matches the package names documented in the [jajera dev container “ag” feature](https://github.com/jajera/features/blob/main/src/ag/README.md): Debian/Ubuntu use `silversearcher-ag`; RHEL/Fedora, Alpine, Arch, openSUSE, and Homebrew use `the_silver_searcher`.

## Usage

```bash
./install_ag.sh [install|uninstall]
```

- **install** (default): Installs `ag` if it is not already on `PATH`.
- **uninstall**: Removes the package when it was installed via a recognized package manager (see below).

## Example usage

```bash
./install_ag.sh
```

```bash
./install_ag.sh install
```

```bash
./install_ag.sh uninstall
```

## Running without cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_ag.sh) install
```

Non-interactive installs use `DEBIAN_FRONTEND=noninteractive` on Debian/Ubuntu where applicable.

## Verification

```bash
ag --version
```

```bash
ag --help
```

## Supported platforms

| Platform | Package manager | Package name |
|----------|-----------------|--------------|
| Debian / Ubuntu | `apt-get` / `apt` | `silversearcher-ag` |
| Fedora / RHEL (dnf) | `dnf` | `the_silver_searcher` |
| RHEL / CentOS (yum) | `yum` | `the_silver_searcher` |
| openSUSE | `zypper` | `the_silver_searcher` |
| Arch Linux | `pacman` | `the_silver_searcher` |
| Alpine | `apk` | `the_silver_searcher` |
| macOS | [Homebrew](https://brew.sh) | `the_silver_searcher` |

## Features

- **Idempotent install**: skips if `ag` is already on `PATH`.
- **Uninstall** removes the distro/Homebrew package when detected; if `ag` was installed from source or another method, the script prints a short message and does not force-remove binaries.

## Requirements

- `sudo` on Linux (and for Homebrew, a user-owned install does not use `sudo` for `brew` itself).
- One of the package managers listed above.

## Documentation

- [The Silver Searcher on GitHub](https://github.com/ggreer/the_silver_searcher)
- [ag man page](https://linux.die.net/man/1/ag)
