#!/bin/bash

set -e

# Align with https://goaccess.io/download stable version
GOACCESS_BASE_URL="https://tar.goaccess.io"
GOACCESS_VERSION="${GOACCESS_VERSION:-1.10.1}"
INSTALL_PREFIX="${GOACCESS_PREFIX:-/usr/local}"
TMP_DIR=""

cleanup() {
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

detect_platform() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        PLATFORM="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        PLATFORM="darwin"
    else
        echo "Unsupported platform: $OSTYPE"
        exit 1
    fi
}

get_installed_version() {
    if command -v goaccess &>/dev/null; then
        goaccess --version 2>/dev/null | sed -n '1s/.* \([0-9.]*\).*/\1/p' || echo "unknown"
    else
        echo "none"
    fi
}

install_build_deps_linux() {
    if command -v apt &>/dev/null; then
        sudo apt-get update
        sudo apt-get install -y build-essential wget libncursesw6-dev libmaxminddb-dev zlib1g-dev
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y gcc make autoconf wget ncurses-devel libmaxminddb-devel zlib-devel
    elif command -v yum &>/dev/null; then
        sudo yum install -y gcc make autoconf wget ncurses-devel libmaxminddb-devel zlib-devel
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y patterns-devel-C-C++ wget ncurses-devel libmaxminddb-devel zlib-devel
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm base-devel wget ncurses libmaxminddb zlib
    else
        echo "Unsupported Linux package manager. Install build-essential, ncurses (ncursesw), wget, and optionally libmaxminddb and zlib."
        exit 1
    fi
}

install_build_deps_darwin() {
    if ! command -v brew &>/dev/null; then
        echo "Homebrew is required on macOS. Install from https://brew.sh"
        exit 1
    fi
    brew install ncurses pkg-config
    # Optional: GeoIP and zlib (often present)
    brew list libmaxminddb &>/dev/null || brew install libmaxminddb 2>/dev/null || true
    brew list zlib &>/dev/null || true
}

check_dependencies() {
    for dep in curl wget; do
        if command -v "$dep" &>/dev/null; then
            return 0
        fi
    done
    echo "Error: Need curl or wget to download the tarball."
    exit 1
}

install_goaccess() {
    detect_platform
    check_dependencies

    local installed_version
    installed_version=$(get_installed_version)
    if [ "$installed_version" != "none" ] && [ "$installed_version" != "unknown" ] && [ "$installed_version" = "$GOACCESS_VERSION" ]; then
        echo "GoAccess $GOACCESS_VERSION is already installed. Skipping."
        exit 0
    fi

    local tarball="goaccess-${GOACCESS_VERSION}.tar.gz"
    local url="${GOACCESS_BASE_URL}/${tarball}"

    echo "Installing GoAccess ${GOACCESS_VERSION} from official source (https://goaccess.io/download)..."

    if [ "$PLATFORM" = "linux" ]; then
        install_build_deps_linux
    else
        install_build_deps_darwin
    fi

    TMP_DIR=$(mktemp -d)
    if command -v wget &>/dev/null; then
        wget -q -O "$TMP_DIR/$tarball" "$url" || { echo "Error: Failed to download $url"; exit 1; }
    else
        curl -sSL -o "$TMP_DIR/$tarball" "$url" || { echo "Error: Failed to download $url"; exit 1; }
    fi

    tar -xzf "$TMP_DIR/$tarball" -C "$TMP_DIR"
    local srcdir="$TMP_DIR/goaccess-${GOACCESS_VERSION}"
    cd "$srcdir"

    # Configure: UTF-8, GeoIP2 (mmdb), zlib for compressed logs (per download page)
    if [ "$PLATFORM" = "darwin" ]; then
        export PKG_CONFIG_PATH="${HOMEBREW_PREFIX:-/usr/local}/opt/ncurses/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
        ./configure --enable-utf8 --enable-geoip=mmdb --with-zlib --prefix="$INSTALL_PREFIX" || \
        ./configure --enable-utf8 --with-zlib --prefix="$INSTALL_PREFIX"
    else
        ./configure --enable-utf8 --enable-geoip=mmdb --with-zlib --prefix="$INSTALL_PREFIX" || \
        ./configure --enable-utf8 --with-zlib --prefix="$INSTALL_PREFIX"
    fi
    make -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)"
    sudo make install

    if ! command -v goaccess &>/dev/null; then
        echo "GoAccess installed to ${INSTALL_PREFIX}/bin/goaccess. Ensure ${INSTALL_PREFIX}/bin is in your PATH."
    else
        echo "GoAccess ${GOACCESS_VERSION} installed successfully."
        goaccess --version 2>/dev/null || true
    fi
}

uninstall_goaccess() {
    local bin_path="${INSTALL_PREFIX}/bin/goaccess"
    if [ ! -f "$bin_path" ] && ! command -v goaccess &>/dev/null; then
        echo "GoAccess is not installed. Nothing to uninstall."
        exit 0
    fi

    echo "Uninstalling GoAccess..."
    if [ -f "$bin_path" ]; then
        sudo rm -f "$bin_path"
        echo "Removed $bin_path"
    fi
    echo "GoAccess has been uninstalled. (Man pages and other prefix files may remain.)"
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    echo ""
    echo "Optional environment variables:"
    echo "  GOACCESS_VERSION  - Version to install (default: 1.10.1, aligned with https://goaccess.io/download)"
    echo "  GOACCESS_PREFIX   - Install prefix (default: /usr/local)"
    echo ""
    echo "Examples:"
    echo "  $0 install"
    echo "  $0 uninstall"
    echo "  GOACCESS_VERSION=1.10.1 $0 install"
    exit 1
}

case "${1:-install}" in
    install) install_goaccess ;;
    uninstall) uninstall_goaccess ;;
    *) usage ;;
esac

if [ "${1:-install}" != "uninstall" ]; then
    echo ""
    echo "Run 'goaccess --version' to verify. See https://goaccess.io for usage."
fi
