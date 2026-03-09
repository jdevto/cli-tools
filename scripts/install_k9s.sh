#!/bin/bash

set -e

K9S_REPO="https://api.github.com/repos/derailed/k9s/releases"
K9S_VERSION="${K9S_VERSION:-}"   # Optional: pin version (e.g. 0.50.18), otherwise latest
INSTALL_PATH="/usr/local/bin/k9s"
TMP_DIR=""

cleanup() {
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

detect_platform() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        PLATFORM="Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        PLATFORM="Darwin"
    else
        echo "Unsupported platform: $OSTYPE"
        exit 1
    fi
}

detect_architecture() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)   ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *)
            echo "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
}

get_latest_version() {
    curl -sSL "$K9S_REPO/latest" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/'
}

get_installed_version() {
    if command -v k9s &>/dev/null; then
        k9s version --short 2>/dev/null | sed -n '1s/.*v\([0-9.]*\).*/\1/p' || echo "unknown"
    else
        echo "none"
    fi
}

check_dependencies() {
    local missing_deps=()
    for dep in curl; do
        if ! command -v "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

install_k9s() {
    check_dependencies
    detect_platform
    detect_architecture

    local version="${K9S_VERSION:-$(get_latest_version)}"
    if [ -z "$version" ]; then
        echo "Error: Could not determine k9s version."
        exit 1
    fi

    local installed_version
    installed_version=$(get_installed_version)
    if [ "$installed_version" != "none" ] && [ "$installed_version" != "unknown" ] && [ "$installed_version" = "$version" ]; then
        echo "k9s is already installed and up-to-date (v$version). Skipping."
        exit 0
    fi

    local asset="k9s_${PLATFORM}_${ARCH}.tar.gz"
    local url="https://github.com/derailed/k9s/releases/download/v${version}/${asset}"

    echo "Installing k9s v${version} for ${PLATFORM}/${ARCH}..."

    TMP_DIR=$(mktemp -d)
    if ! curl -sSL -o "$TMP_DIR/$asset" "$url"; then
        echo "Error: Failed to download k9s from $url"
        exit 1
    fi

    tar -xzf "$TMP_DIR/$asset" -C "$TMP_DIR"
    sudo mv "$TMP_DIR/k9s" "$INSTALL_PATH"
    sudo chmod +x "$INSTALL_PATH"

    if ! command -v k9s &>/dev/null; then
        echo "Error: k9s installation completed but binary not found in PATH."
        exit 1
    fi

    echo "k9s v${version} installed successfully at $INSTALL_PATH"
    k9s version --short 2>/dev/null || true
}

uninstall_k9s() {
    if [ ! -f "$INSTALL_PATH" ] && ! command -v k9s &>/dev/null; then
        echo "k9s is not installed. Nothing to uninstall."
        exit 0
    fi

    echo "Uninstalling k9s..."
    if [ -f "$INSTALL_PATH" ]; then
        sudo rm -f "$INSTALL_PATH"
        echo "k9s has been uninstalled."
    else
        echo "k9s binary not found at $INSTALL_PATH (may be installed elsewhere)."
    fi
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    echo ""
    echo "Optional environment variables:"
    echo "  K9S_VERSION  - Pin version (e.g. 0.50.18). Default: latest release."
    echo ""
    echo "Examples:"
    echo "  $0 install"
    echo "  $0 uninstall"
    echo "  K9S_VERSION=0.50.18 $0 install"
    exit 1
}

case "${1:-install}" in
    install) install_k9s ;;
    uninstall) uninstall_k9s ;;
    *) usage ;;
esac

if [ "${1:-install}" != "uninstall" ]; then
    echo ""
    echo "Run 'k9s version' to verify. Ensure kubectl is configured for cluster access."
fi
