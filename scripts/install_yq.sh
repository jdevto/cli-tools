#!/bin/bash

set -e

YQ_REPO_API="https://api.github.com/repos/mikefarah/yq/releases"
YQ_VERSION="${YQ_VERSION:-}" # Optional: pin semver e.g. 4.52.5 or v4.52.5; default: latest
INSTALL_PATH="/usr/local/bin/yq"
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
    curl -sSL "${YQ_REPO_API}/latest" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/'
}

# v4.52.5 -> 4.52.5
semver_from_tag() {
    echo "$1" | sed 's/^v//'
}

resolve_tag() {
    if [ -n "$YQ_VERSION" ]; then
        local v
        v=$(echo "$YQ_VERSION" | sed 's/^v//')
        echo "v${v}"
    else
        get_latest_tag
    fi
}

get_installed_semver() {
    if ! command -v yq &>/dev/null; then
        echo "none"
        return
    fi
    local line
    line=$(yq --version 2>/dev/null || true)
    if [ -z "$line" ]; then
        echo "unknown"
        return
    fi
    # Distinguish mikefarah/yq from other implementations (e.g. Python yq).
    if [[ "$line" != *"mikefarah"* ]] && [[ "$line" != *"github.com/mikefarah/yq"* ]]; then
        echo "unknown"
        return
    fi
    echo "$line" | sed -E 's/.*version v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/'
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

install_yq() {
    check_dependencies
    detect_platform
    detect_architecture

    local tag
    tag=$(resolve_tag)
    if [ -z "$tag" ] || [[ "$tag" != v* ]]; then
        echo "Error: Could not resolve yq release tag (got: ${tag:-empty})."
        exit 1
    fi

    local semver
    semver=$(semver_from_tag "$tag")

    local installed
    installed=$(get_installed_semver)
    if [ "$installed" != "none" ] && [ "$installed" != "unknown" ] && [ "$installed" = "$semver" ]; then
        echo "yq (mikefarah/yq) is already installed and up-to-date (v${semver}). Skipping."
        exit 0
    fi

    local binary_name="yq_${PLATFORM_OS}_${ARCH_SUFFIX}"
    local encoded_tag
    encoded_tag=$(printf '%s' "$tag" | sed 's#/#%2F#g')
    local url="https://github.com/mikefarah/yq/releases/download/${encoded_tag}/${binary_name}"

    echo "Installing yq v${semver} for ${PLATFORM_OS}/${ARCH_SUFFIX} from mikefarah/yq..."

    TMP_DIR=$(mktemp -d)
    if ! curl -fsSL -o "$TMP_DIR/yq" "$url"; then
        echo "Error: Failed to download yq from $url"
        exit 1
    fi

    chmod +x "$TMP_DIR/yq"
    sudo mv "$TMP_DIR/yq" "$INSTALL_PATH"

    if ! command -v yq &>/dev/null; then
        echo "Error: yq installation completed but binary not found in PATH."
        exit 1
    fi

    echo "yq v${semver} installed successfully at $INSTALL_PATH"
    yq --version 2>/dev/null || true
}

uninstall_yq() {
    if [ ! -f "$INSTALL_PATH" ] && ! command -v yq &>/dev/null; then
        echo "yq is not installed. Nothing to uninstall."
        exit 0
    fi

    echo "Uninstalling yq..."
    if [ -f "$INSTALL_PATH" ]; then
        sudo rm -f "$INSTALL_PATH"
        echo "yq has been uninstalled from $INSTALL_PATH."
    else
        echo "yq binary not found at $INSTALL_PATH (may be installed elsewhere)."
    fi
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    echo ""
    echo "Installs mikefarah/yq (YAML/JSON/XML processor) from GitHub releases — not the unrelated Python yq package."
    echo ""
    echo "Optional environment variables:"
    echo "  YQ_VERSION  - Pin semver (e.g. 4.52.5 or v4.52.5). Default: latest GitHub release."
    echo ""
    echo "Examples:"
    echo "  $0 install"
    echo "  $0 uninstall"
    echo "  YQ_VERSION=4.52.5 $0 install"
    exit 1
}

case "${1:-install}" in
    install)   install_yq ;;
    uninstall) uninstall_yq ;;
    *)         usage ;;
esac

if [ "${1:-install}" != "uninstall" ]; then
    echo ""
    echo "Run 'yq --version' to verify."
fi
