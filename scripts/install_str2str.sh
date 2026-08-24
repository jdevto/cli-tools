#!/bin/bash

set -e

# RTKLIB str2str — NTRIP stream relay tool
# Build from source: https://github.com/tomojitakasu/RTKLIB
RTKLIB_VERSION="${RTKLIB_VERSION:-2.4.3-b34}"
RTKLIB_REPO="https://github.com/tomojitakasu/RTKLIB.git"
INSTALL_PREFIX="${STR2STR_PREFIX:-/usr/local}"
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

detect_architecture() {
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        ARCH="x86_64"
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        ARCH="arm64"
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi
}

install_build_deps_linux() {
    if command -v apt &>/dev/null; then
        sudo apt-get update
        sudo apt-get install -y build-essential git
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y gcc make git
    elif command -v yum &>/dev/null; then
        sudo yum install -y gcc make git
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm base-devel git
    else
        echo "Unsupported package manager. Install gcc, make, and git manually."
        exit 1
    fi
}

install_build_deps_darwin() {
    if ! command -v brew &>/dev/null; then
        echo "Homebrew is required on macOS. Install from https://brew.sh"
        exit 1
    fi
    # Xcode command line tools provide gcc/make
    xcode-select --install 2>/dev/null || true
    command -v git &>/dev/null || brew install git
}

check_dependencies() {
    local missing_deps=()

    if ! command -v git &>/dev/null; then
        missing_deps+=("git")
    fi

    if ! command -v make &>/dev/null; then
        missing_deps+=("make")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Missing build dependencies: ${missing_deps[*]}"
        echo "Attempting to install..."
        return 1
    fi
    return 0
}

install_str2str() {
    if command -v str2str &>/dev/null; then
        echo "str2str is already installed. Skipping installation."
        echo "Location: $(command -v str2str)"
        exit 0
    fi

    detect_platform
    detect_architecture

    echo "Installing str2str from RTKLIB (${RTKLIB_VERSION})..."

    if ! check_dependencies; then
        if [ "$PLATFORM" = "linux" ]; then
            install_build_deps_linux
        else
            install_build_deps_darwin
        fi
    fi

    TMP_DIR=$(mktemp -d)

    echo "Cloning RTKLIB..."
    git clone --depth 1 --branch "v${RTKLIB_VERSION}" "$RTKLIB_REPO" "$TMP_DIR/RTKLIB" 2>/dev/null || \
    git clone --depth 1 "$RTKLIB_REPO" "$TMP_DIR/RTKLIB"

    local str2str_dir="$TMP_DIR/RTKLIB/app/str2str/gcc"

    if [ ! -d "$str2str_dir" ]; then
        # Try alternative path for newer RTKLIB layouts
        str2str_dir="$TMP_DIR/RTKLIB/app/consapp/str2str/gcc"
    fi

    if [ ! -d "$str2str_dir" ]; then
        echo "Error: Cannot find str2str source directory in RTKLIB"
        exit 1
    fi

    echo "Building str2str..."
    cd "$str2str_dir"
    make -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)"

    echo "Installing str2str to ${INSTALL_PREFIX}/bin..."
    sudo install -m 755 str2str "${INSTALL_PREFIX}/bin/str2str"

    if ! command -v str2str &>/dev/null; then
        echo "str2str installed to ${INSTALL_PREFIX}/bin/str2str. Ensure ${INSTALL_PREFIX}/bin is in your PATH."
    else
        echo "str2str installed successfully."
    fi
}

uninstall_str2str() {
    local bin_path="${INSTALL_PREFIX}/bin/str2str"
    if [ ! -f "$bin_path" ] && ! command -v str2str &>/dev/null; then
        echo "str2str is not installed. Nothing to uninstall."
        exit 0
    fi

    echo "Uninstalling str2str..."
    if [ -f "$bin_path" ]; then
        sudo rm -f "$bin_path"
        echo "Removed $bin_path"
    elif command -v str2str &>/dev/null; then
        local path
        path=$(command -v str2str)
        sudo rm -f "$path"
        echo "Removed $path"
    fi
    echo "str2str has been uninstalled."
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    echo ""
    echo "Optional environment variables:"
    echo "  RTKLIB_VERSION   - RTKLIB version/tag (default: 2.4.3-b34)"
    echo "  STR2STR_PREFIX   - Install prefix (default: /usr/local)"
    echo ""
    echo "Examples:"
    echo "  $0 install"
    echo "  $0 uninstall"
    echo "  RTKLIB_VERSION=2.4.3-b34 $0 install"
    exit 1
}

case "${1:-install}" in
    install) install_str2str ;;
    uninstall) uninstall_str2str ;;
    *) usage ;;
esac

if [ "${1:-install}" != "uninstall" ]; then
    echo ""
    echo "str2str installation completed successfully."
    echo "Run 'str2str -h' to verify installation."
fi
