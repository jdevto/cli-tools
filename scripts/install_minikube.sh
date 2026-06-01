#!/bin/bash

set -e

MINIKUBE_RELEASES_URL="https://storage.googleapis.com/minikube/releases"
MINIKUBE_GITHUB_API="https://api.github.com/repos/kubernetes/minikube/releases/latest"
MINIKUBE_VERSION="${MINIKUBE_VERSION:-}"   # Optional: pin version (e.g. v1.38.1 or 1.38.1)
INSTALL_PATH="/usr/local/bin/minikube"
TMP_BIN=""

cleanup() {
    if [ -n "$TMP_BIN" ] && [ -f "$TMP_BIN" ]; then
        rm -f "$TMP_BIN"
    fi
}
trap cleanup EXIT

detect_platform() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS_NAME="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS_NAME="darwin"
    else
        echo "Unsupported platform: $OSTYPE"
        exit 1
    fi
}

detect_architecture() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *)
            echo "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
}

normalize_version() {
    local version="$1"
    version="${version#v}"
    echo "$version"
}

get_release_path() {
    if [ -n "$MINIKUBE_VERSION" ]; then
        local version
        version=$(normalize_version "$MINIKUBE_VERSION")
        echo "v${version}"
    else
        echo "latest"
    fi
}

get_latest_version() {
    curl -sSL "$MINIKUBE_GITHUB_API" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/'
}

get_installed_version() {
    if command -v minikube &>/dev/null; then
        minikube version --short 2>/dev/null | sed -E 's/^v?([0-9.]+).*/\1/' || echo "unknown"
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
        echo "Install curl using your package manager, then re-run this script."
        exit 1
    fi
}

get_download_url() {
    local release_path binary_name
    release_path=$(get_release_path)
    binary_name="minikube-${OS_NAME}-${ARCH}"
    echo "${MINIKUBE_RELEASES_URL}/${release_path}/${binary_name}"
}

get_target_version() {
    if [ -n "$MINIKUBE_VERSION" ]; then
        normalize_version "$MINIKUBE_VERSION"
    else
        get_latest_version
    fi
}

install_minikube() {
    check_dependencies
    detect_platform
    detect_architecture

    local target_version
    target_version=$(get_target_version)
    if [ -z "$target_version" ]; then
        echo "Error: Could not determine minikube version."
        exit 1
    fi

    local installed_version
    installed_version=$(get_installed_version)
    if [ "$installed_version" != "none" ] && [ "$installed_version" != "unknown" ] && [ "$installed_version" = "$target_version" ]; then
        echo "minikube is already installed and up-to-date (v${target_version}). Skipping."
        exit 0
    fi

    local url
    url=$(get_download_url)
    TMP_BIN=$(mktemp)

    echo "Installing minikube v${target_version} for ${OS_NAME}/${ARCH}..."
    echo "Downloading from ${url}"

    if ! curl -fsSL -o "$TMP_BIN" "$url"; then
        echo "Error: Failed to download minikube from ${url}"
        exit 1
    fi

    chmod +x "$TMP_BIN"
    sudo install -o root -g root -m 0755 "$TMP_BIN" "$INSTALL_PATH"

    if ! command -v minikube &>/dev/null; then
        echo "Error: minikube installation completed but binary not found in PATH."
        exit 1
    fi

    echo "minikube v${target_version} installed successfully at ${INSTALL_PATH}"
    minikube version --short 2>/dev/null || true
}

uninstall_minikube() {
    if [ ! -f "$INSTALL_PATH" ] && ! command -v minikube &>/dev/null; then
        echo "minikube is not installed. Nothing to uninstall."
        exit 0
    fi

    echo "Uninstalling minikube..."
    if [ -f "$INSTALL_PATH" ]; then
        sudo rm -f "$INSTALL_PATH"
        echo "minikube has been uninstalled."
    else
        echo "minikube binary not found at ${INSTALL_PATH} (may be installed elsewhere)."
    fi
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    echo ""
    echo "Installs the minikube binary only (does not start a cluster)."
    echo "See https://minikube.sigs.k8s.io/docs/start/"
    echo ""
    echo "Optional environment variables:"
    echo "  MINIKUBE_VERSION  - Pin version (e.g. v1.38.1 or 1.38.1). Default: latest release."
    echo ""
    echo "Examples:"
    echo "  $0 install"
    echo "  $0 uninstall"
    echo "  MINIKUBE_VERSION=v1.38.1 $0 install"
    exit 1
}

case "${1:-install}" in
    install) install_minikube ;;
    uninstall) uninstall_minikube ;;
    *) usage ;;
esac

if [ "${1:-install}" != "uninstall" ]; then
    echo ""
    echo "Run 'minikube version' to verify."
    echo "Start a cluster with a driver (e.g. Docker): minikube start --driver=docker"
    echo "Do not run minikube as root; use a normal user account."
fi
