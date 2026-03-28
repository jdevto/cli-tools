#!/bin/bash

set -e

KUSTOMIZE_REPO_API="https://api.github.com/repos/kubernetes-sigs/kustomize/releases"
KUSTOMIZE_VERSION="${KUSTOMIZE_VERSION:-}" # Optional: pin semver e.g. 5.8.1 (without v); default: latest
INSTALL_PATH="/usr/local/bin/kustomize"
TMP_DIR=""

cleanup() {
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

detect_platform() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        PLATFORM_OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        PLATFORM_OS="darwin"
    else
        echo "Unsupported platform: $OSTYPE"
        exit 1
    fi
}

detect_architecture() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)        ARCH_SUFFIX="amd64" ;;
        aarch64|arm64) ARCH_SUFFIX="arm64" ;;
        *)
            echo "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
}

get_latest_tag() {
    curl -sSL "${KUSTOMIZE_REPO_API}/latest" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/'
}

# kustomize/v5.8.1 -> 5.8.1
semver_from_tag() {
    echo "$1" | sed 's#^kustomize/v##'
}

resolve_tag() {
    if [ -n "$KUSTOMIZE_VERSION" ]; then
        echo "kustomize/v${KUSTOMIZE_VERSION}"
    else
        get_latest_tag
    fi
}

get_installed_semver() {
    if command -v kustomize &>/dev/null; then
        # kustomize version --short typically prints v5.8.1
        local v
        v=$(kustomize version --short 2>/dev/null || true)
        if [ -z "$v" ]; then
            echo "unknown"
            return
        fi
        echo "$v" | sed -E 's/^kustomize\///' | sed -E 's/^v//' | tr -d '[:space:]'
    else
        echo "none"
    fi
}

check_dependencies() {
    local missing_deps=()
    for dep in curl tar; do
        if ! command -v "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

install_kustomize() {
    check_dependencies
    detect_platform
    detect_architecture

    local tag
    tag=$(resolve_tag)
    if [ -z "$tag" ] || [[ "$tag" != kustomize/v* ]]; then
        echo "Error: Could not resolve kustomize release tag (got: ${tag:-empty})."
        exit 1
    fi

    local semver
    semver=$(semver_from_tag "$tag")

    local installed
    installed=$(get_installed_semver)
    if [ "$installed" != "none" ] && [ "$installed" != "unknown" ] && [ "$installed" = "$semver" ]; then
        echo "kustomize is already installed and up-to-date (v${semver}). Skipping."
        exit 0
    fi

    local tarball="kustomize_v${semver}_${PLATFORM_OS}_${ARCH_SUFFIX}.tar.gz"
    local encoded_tag
    encoded_tag=$(printf '%s' "$tag" | sed 's#/#%2F#g')
    local url="https://github.com/kubernetes-sigs/kustomize/releases/download/${encoded_tag}/${tarball}"

    echo "Installing kustomize v${semver} for ${PLATFORM_OS}/${ARCH_SUFFIX}..."

    TMP_DIR=$(mktemp -d)
    if ! curl -fsSL -o "$TMP_DIR/$tarball" "$url"; then
        echo "Error: Failed to download kustomize from $url"
        exit 1
    fi

    tar -xzf "$TMP_DIR/$tarball" -C "$TMP_DIR"
    if [ ! -f "$TMP_DIR/kustomize" ]; then
        echo "Error: Expected binary kustomize not found in archive."
        exit 1
    fi

    chmod +x "$TMP_DIR/kustomize"
    sudo mv "$TMP_DIR/kustomize" "$INSTALL_PATH"

    if ! command -v kustomize &>/dev/null; then
        echo "Error: kustomize installation completed but binary not found in PATH."
        exit 1
    fi

    echo "kustomize v${semver} installed successfully at $INSTALL_PATH"
    kustomize version --short 2>/dev/null || kustomize version 2>/dev/null || true
}

uninstall_kustomize() {
    if [ ! -f "$INSTALL_PATH" ] && ! command -v kustomize &>/dev/null; then
        echo "kustomize is not installed. Nothing to uninstall."
        exit 0
    fi

    echo "Uninstalling kustomize..."
    if [ -f "$INSTALL_PATH" ]; then
        sudo rm -f "$INSTALL_PATH"
        echo "kustomize has been uninstalled."
    else
        echo "kustomize binary not found at $INSTALL_PATH (may be installed elsewhere)."
    fi
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    echo ""
    echo "Optional environment variables:"
    echo "  KUSTOMIZE_VERSION  - Pin semver (e.g. 5.8.1). Default: latest GitHub release."
    echo ""
    echo "Examples:"
    echo "  $0 install"
    echo "  $0 uninstall"
    echo "  KUSTOMIZE_VERSION=5.8.1 $0 install"
    exit 1
}

case "${1:-install}" in
    install)   install_kustomize ;;
    uninstall) uninstall_kustomize ;;
    *)         usage ;;
esac

if [ "${1:-install}" != "uninstall" ]; then
    echo ""
    echo "Run 'kustomize version' to verify."
fi
