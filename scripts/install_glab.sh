#!/bin/bash

set -e

# Official releases: https://gitlab.com/gitlab-org/cli/-/releases
# Other methods: https://gitlab.com/gitlab-org/cli/#other-installation-methods
GLAB_API_LATEST="https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases/permalink/latest"
GLAB_VERSION="${GLAB_VERSION:-}"   # Optional: pin version (e.g. 1.90.0), otherwise latest
INSTALL_PATH="/usr/local/bin/glab"
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
    case "$ARCH" in
        x86_64)   ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *)
            echo "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
}

normalize_version() {
    local v="$1"
    v="${v#v}"
    echo "$v"
}

version_tag() {
    local v
    v=$(normalize_version "$1")
    echo "v${v}"
}

get_latest_version() {
    curl -sSL "$GLAB_API_LATEST" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"v([^"]+)".*/\1/'
}

get_installed_version() {
    if command -v glab &>/dev/null; then
        glab version 2>/dev/null | head -1 | sed -n 's/.*\([0-9][0-9.]*\).*/\1/p' || echo "unknown"
    else
        echo "none"
    fi
}

check_dependencies() {
    if ! command -v curl &>/dev/null; then
        echo "Error: curl is required."
        exit 1
    fi
}

install_glab() {
    check_dependencies
    detect_platform
    detect_architecture

    local version
    version="${GLAB_VERSION:-$(get_latest_version)}"
    version=$(normalize_version "$version")
    if [ -z "$version" ]; then
        echo "Error: Could not determine glab version."
        exit 1
    fi

    local installed_version
    installed_version=$(get_installed_version)
    if [ "$installed_version" != "none" ] && [ "$installed_version" != "unknown" ] && [ "$installed_version" = "$version" ]; then
        echo "glab $version is already installed. Skipping."
        exit 0
    fi

    local tag
    tag=$(version_tag "$version")
    local asset="glab_${version}_${PLATFORM}_${ARCH}.tar.gz"
    local url="https://gitlab.com/gitlab-org/cli/-/releases/${tag}/downloads/${asset}"

    echo "Installing glab ${version} for ${PLATFORM}/${ARCH} from GitLab releases..."

    TMP_DIR=$(mktemp -d)
    if ! curl -sSL -f -o "$TMP_DIR/$asset" "$url"; then
        echo "Error: Failed to download $url"
        echo "See https://gitlab.com/gitlab-org/cli/-/releases for available assets."
        exit 1
    fi

    tar -xzf "$TMP_DIR/$asset" -C "$TMP_DIR"
    sudo mv "$TMP_DIR/bin/glab" "$INSTALL_PATH"
    sudo chmod +x "$INSTALL_PATH"

    if ! command -v glab &>/dev/null; then
        echo "Error: glab installed to $INSTALL_PATH but not found in PATH."
        exit 1
    fi

    echo "glab ${version} installed successfully at $INSTALL_PATH"
    glab version 2>/dev/null || true
}

uninstall_glab() {
    if [ ! -f "$INSTALL_PATH" ] && ! command -v glab &>/dev/null; then
        echo "glab is not installed. Nothing to uninstall."
        exit 0
    fi

    echo "Uninstalling glab..."
    if [ -f "$INSTALL_PATH" ]; then
        sudo rm -f "$INSTALL_PATH"
        echo "glab has been uninstalled."
    else
        echo "glab binary not found at $INSTALL_PATH (may be installed elsewhere)."
    fi
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    echo ""
    echo "Installs the official prebuilt binary from GitLab releases (see"
    echo "https://gitlab.com/gitlab-org/cli/#other-installation-methods)."
    echo ""
    echo "Optional environment variables:"
    echo "  GLAB_VERSION  - Pin version (e.g. 1.90.0). Default: latest release."
    echo ""
    echo "Examples:"
    echo "  $0 install"
    echo "  $0 uninstall"
    echo "  GLAB_VERSION=1.90.0 $0 install"
    exit 1
}

case "${1:-install}" in
    install) install_glab ;;
    uninstall) uninstall_glab ;;
    *) usage ;;
esac

if [ "${1:-install}" != "uninstall" ]; then
    echo ""
    echo "Run 'glab version' to verify. Authenticate with 'glab auth login'."
fi
