# install_goaccess.sh

This script installs or uninstalls [GoAccess](https://goaccess.io) from the **official source** ([download page](https://goaccess.io/download)). It builds from the stable tarball at [tar.goaccess.io](https://tar.goaccess.io) so the version aligns with the official site. GoAccess is a real-time web log analyzer and interactive viewer; it requires only **ncurses** at runtime and supports UTF-8, GeoIP2, and parsing of compressed (e.g. `.gz`) logs when built with the optional dependencies.

## Usage

```bash
./install_goaccess.sh [install|uninstall]
```

- **install** (default): Installs GoAccess from source (default version **1.10.1**, aligned with the [download page](https://goaccess.io/download)).
- **uninstall**: Removes the GoAccess binary from the install prefix (default `/usr/local/bin`).

## Example Usage

To install the default stable version (1.10.1):

```bash
./install_goaccess.sh
```

Or explicitly:

```bash
./install_goaccess.sh install
```

To install a specific version:

```bash
GOACCESS_VERSION=1.10.1 ./install_goaccess.sh install
```

To uninstall:

```bash
./install_goaccess.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_goaccess.sh) install
```

Optional: set `GOACCESS_VERSION` or `GOACCESS_PREFIX` as needed.

## Verification

After installation, check the version:

```bash
goaccess --version
```

Generate a report from a log file:

```bash
goaccess access.log -o report.html --log-format=COMBINED
```

## Supported Operating Systems

- **Linux** – Debian/Ubuntu (apt), Fedora/RHEL/CentOS (dnf/yum), openSUSE (zypper), Arch (pacman). Build tools and ncurses (with UTF-8), GeoIP2 (libmaxminddb), and zlib are installed when available.
- **macOS** – Homebrew required; ncurses and optional libmaxminddb are used for the build.

## Supported Architectures

The script builds from source, so any architecture supported by your toolchain (e.g. x86_64, arm64) is supported.

## Features

- **Version aligned with [goaccess.io/download](https://goaccess.io/download)** – default **1.10.1** (stable).
- Build from official tarball: `https://tar.goaccess.io/goaccess-<version>.tar.gz`.
- Configure options used: `--enable-utf8`, `--enable-geoip=mmdb`, `--with-zlib` (per official instructions).
- Idempotent: skips install if the same version is already installed.
- Optional version and prefix: `GOACCESS_VERSION`, `GOACCESS_PREFIX`.

## Optional environment variables

| Variable | Description |
| -------- | ----------- |
| `GOACCESS_VERSION` | Version to install (default: **1.10.1**, matches [download page](https://goaccess.io/download)). |
| `GOACCESS_PREFIX` | Install prefix (default: `/usr/local`). Binary: `$GOACCESS_PREFIX/bin/goaccess`. |

## Prerequisites

- **curl** or **wget** – to download the tarball.
- **Build tools** – gcc, make, autoconf (installed automatically on supported Linux distros; on macOS, Xcode CLI or Homebrew).
- **ncurses** (with wide-char for UTF-8) – installed by the script on supported systems.
- Optional: **libmaxminddb** (GeoIP2), **zlib** – installed when available for full features.

## Uninstallation

Uninstall removes only the binary at `$GOACCESS_PREFIX/bin/goaccess` (default `/usr/local/bin/goaccess`). Man pages and other files under the prefix are not removed.

## Troubleshooting

1. **Configure fails (e.g. missing ncursesw)**  
   On Linux, ensure the script’s dependency install ran (e.g. `libncursesw6-dev` on Debian/Ubuntu). On macOS, ensure `brew install ncurses` succeeded and `PKG_CONFIG_PATH` can find ncurses.

2. **GeoIP or zlib disabled**  
   If `--enable-geoip=mmdb` or `--with-zlib` fails, the script falls back to a configure without GeoIP. Install `libmaxminddb-dev` (or equivalent) and zlib dev packages if you need those features.

3. **goaccess not found after install**  
   The binary is under `$GOACCESS_PREFIX/bin`. Ensure that directory is in your `PATH` (e.g. `/usr/local/bin`).

4. **Real-time HTML report**  
   If you use the real-time HTML output, ensure port **7890** is open; see the [official documentation](https://goaccess.io/download).
