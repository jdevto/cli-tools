#!/bin/bash

set -e

# Official release notes and GCS binaries: https://github.com/rakyll/hey#installation
HEY_INSTALL_PREFIX="${HEY_INSTALL_PREFIX:-$HOME/.local/bin}"
# Optional: pin a tag for go install only (e.g. 0.1.5 or v0.1.5). GCS builds are unversioned URLs (current published binary).
HEY_VERSION="${HEY_VERSION:-}"

TMP_DIR=""

cleanup() {
    if [[ -n "${TMP_DIR:-}" ]] && [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

usage() {
    cat <<'EOF'
Usage: install_hey.sh [install|uninstall]

Default: install.

Installs hey (HTTP load generator) from https://github.com/rakyll/hey
Prebuilt binaries (Google Cloud Storage): Linux amd64, macOS amd64, Windows amd64.
On Linux or macOS arm64, installs via "go install" when Go is on PATH (uses HEY_VERSION or latest Git tag).

Optional environment variables:
  HEY_INSTALL_PREFIX  - Directory for the binary (default: $HOME/.local/bin)
  HEY_VERSION         - Git tag for go install only, e.g. 0.1.5 or v0.1.5 (default: latest)

Examples:
  install_hey.sh
  install_hey.sh install
  HEY_VERSION=0.1.5 install_hey.sh install
  install_hey.sh uninstall
EOF
    exit 1
}

check_curl() {
    if ! command -v curl &>/dev/null; then
        echo "Error: curl is required."
        exit 1
    fi
}

get_latest_hey_tag() {
    curl -sSL "https://api.github.com/repos/rakyll/hey/releases/latest" \
        | grep '"tag_name"' | head -1 \
        | sed -E 's/.*"([^"]+)".*/\1/'
}

normalize_version() {
    local v="$1"
    v="${v#v}"
    echo "$v"
}

hey_go_module_ref() {
    local tag
    if [[ -n "${HEY_VERSION}" ]]; then
        tag=$(version_tag_from_input "${HEY_VERSION}")
    else
        tag=$(get_latest_hey_tag)
    fi
    if [[ -z "$tag" ]]; then
        echo ""
        return
    fi
    if [[ "$tag" != v* ]]; then
        tag="v${tag}"
    fi
    echo "github.com/rakyll/hey@${tag}"
}

version_tag_from_input() {
    local v
    v=$(normalize_version "$1")
    echo "v${v}"
}

install_via_go() {
    if ! command -v go &>/dev/null; then
        return 1
    fi
    local ref
    ref=$(hey_go_module_ref)
    if [[ -z "$ref" ]]; then
        echo "Error: Could not resolve hey module ref for go install."
        exit 1
    fi
    mkdir -p "$HEY_INSTALL_PREFIX"
    echo "Installing hey via go install ${ref} ..."
    GOBIN="$(cd "$HEY_INSTALL_PREFIX" && pwd)" GO111MODULE=on go install "${ref}"
    if [[ ! -f "$HEY_INSTALL_PREFIX/hey" ]]; then
        echo "Error: go install did not produce $HEY_INSTALL_PREFIX/hey"
        exit 1
    fi
    chmod +x "$HEY_INSTALL_PREFIX/hey" 2>/dev/null || true
    return 0
}

detect_os_arch() {
    case "${OSTYPE:-}" in
    linux-gnu* | linux-musl*)
        OS="linux"
        ;;
    darwin*)
        OS="darwin"
        ;;
    msys* | cygwin* | win32)
        OS="windows"
        ;;
    *)
        echo "Error: Unsupported OS: ${OSTYPE:-unknown}"
        exit 1
        ;;
    esac

    local m
    m=$(uname -m)
    case "$m" in
    x86_64 | amd64) ARCH="amd64" ;;
    aarch64 | arm64) ARCH="arm64" ;;
    *)
        echo "Error: Unsupported architecture: $m"
        exit 1
        ;;
    esac
}

gcs_url_for() {
    case "${OS}-${ARCH}" in
    linux-amd64) echo "https://storage.googleapis.com/hey-releases/hey_linux_amd64" ;;
    darwin-amd64) echo "https://storage.googleapis.com/hey-releases/hey_darwin_amd64" ;;
    windows-amd64) echo "https://storage.googleapis.com/hey-releases/hey_windows_amd64" ;;
    *) echo "" ;;
    esac
}

install_via_gcs() {
    local url
    url=$(gcs_url_for)
    if [[ -z "$url" ]]; then
        return 1
    fi
    mkdir -p "$HEY_INSTALL_PREFIX"
    TMP_DIR=$(mktemp -d)
    local out="$TMP_DIR/hey.bin"
    echo "Downloading hey from GCS (${OS}/${ARCH})..."
    if ! curl -fsSL -o "$out" "$url"; then
        echo "Error: Failed to download from $url"
        exit 1
    fi
    chmod +x "$out"
    if [[ "$OS" == "windows" ]]; then
        mv "$out" "$HEY_INSTALL_PREFIX/hey.exe"
        echo "Installed hey to $HEY_INSTALL_PREFIX/hey.exe"
    else
        mv "$out" "$HEY_INSTALL_PREFIX/hey"
        echo "Installed hey to $HEY_INSTALL_PREFIX/hey"
    fi
    rm -rf "$TMP_DIR"
    TMP_DIR=""
    return 0
}

install_hey() {
    if command -v hey &>/dev/null; then
        echo "hey is already on PATH. Skipping install."
        echo "Location: $(command -v hey)"
        exit 0
    fi

    check_curl
    detect_os_arch

    if install_via_gcs; then
        :
    elif [[ "$ARCH" == "arm64" ]] && ([[ "$OS" == "linux" ]] || [[ "$OS" == "darwin" ]]); then
        if ! install_via_go; then
            echo "Error: No prebuilt hey for ${OS}/${ARCH}. Install Go and re-run, or use Homebrew on macOS: brew install hey"
            echo "See: https://github.com/rakyll/hey#installation"
            exit 1
        fi
    else
        echo "Error: No prebuilt hey for ${OS}/${ARCH}."
        echo "Install Go and re-run for go install, or see https://github.com/rakyll/hey#installation"
        exit 1
    fi

    if ! command -v hey &>/dev/null && [[ "$OS" != "windows" ]]; then
        echo "Note: Add $HEY_INSTALL_PREFIX to PATH if hey is not found."
    fi
}

uninstall_hey() {
    local removed=false
    if [[ -f "$HEY_INSTALL_PREFIX/hey" ]]; then
        rm -f "$HEY_INSTALL_PREFIX/hey"
        removed=true
    fi
    if [[ -f "$HEY_INSTALL_PREFIX/hey.exe" ]]; then
        rm -f "$HEY_INSTALL_PREFIX/hey.exe"
        removed=true
    fi
    if [[ "$removed" == true ]]; then
        echo "Removed hey from $HEY_INSTALL_PREFIX"
    else
        echo "No hey binary found at $HEY_INSTALL_PREFIX (hey or hey.exe)."
    fi
}

case "${1:-install}" in
install) install_hey ;;
uninstall) uninstall_hey ;;
-h | --help | help) usage ;;
*) usage ;;
esac
