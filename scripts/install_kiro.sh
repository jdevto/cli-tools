#!/bin/bash

set -e

# Kiro IDE + optional CLI — based on:
# https://dev.to/jajera/installing-kiro-on-fedora-red-hat-2i9g
# Official downloads: https://kiro.dev/downloads/
# CLI: https://cli.kiro.dev/install

KIRO_WITH_CLI="${KIRO_WITH_CLI:-0}"
KIRO_SHARE_DIR="${KIRO_SHARE_DIR:-$HOME/.local/share/kiro}"
KIRO_BIN_DIR="${KIRO_BIN_DIR:-$HOME/.local/bin}"
KIRO_DESKTOP_DIR="${KIRO_DESKTOP_DIR:-$HOME/.local/share/applications}"
KIRO_APPS_DIR="${KIRO_APPS_DIR:-$HOME/Applications}"
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
        echo "Supported: Linux (x64) and macOS (Intel + Apple Silicon)."
        exit 1
    fi
}

detect_architecture() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64) ARCH="x64" ;;
        aarch64 | arm64) ARCH="arm64" ;;
        *)
            echo "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

ensure_local_bin_path() {
    mkdir -p "$KIRO_BIN_DIR"
    if [[ ":$PATH:" != *":$KIRO_BIN_DIR:"* ]]; then
        export PATH="$KIRO_BIN_DIR:$PATH"
    fi
    for profile in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$profile" ] && ! grep -qF '.local/bin' "$profile" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$profile"
        fi
    done
}

install_dependencies() {
    local missing=()
    command -v curl &>/dev/null || missing+=("curl")
    command -v jq &>/dev/null || missing+=("jq")
    if [ "$PLATFORM" = "linux" ]; then
        command -v tar &>/dev/null || missing+=("tar")
    else
        command -v unzip &>/dev/null || missing+=("unzip")
    fi

    if [ ${#missing[@]} -eq 0 ]; then
        return 0
    fi

    echo "Installing missing dependencies: ${missing[*]}"
    if command -v dnf &>/dev/null; then
        sudo dnf install -y "${missing[@]}"
    elif command -v yum &>/dev/null; then
        sudo yum install -y "${missing[@]}"
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update
        sudo apt-get install -y "${missing[@]}"
    elif command -v brew &>/dev/null; then
        brew install "${missing[@]}"
    else
        echo "Error: install ${missing[*]} manually and re-run."
        exit 1
    fi
}

metadata_url() {
    echo "https://prod.download.desktop.kiro.dev/stable/metadata-${PLATFORM}-${ARCH}-stable.json"
}

get_ide_download_url() {
    local meta_url
    meta_url=$(metadata_url)
    local url
    if [ "$PLATFORM" = "linux" ]; then
        url=$(curl -fsSL "$meta_url" | jq -r '.releases[].updateTo.url | select(endswith(".tar.gz"))' | head -1)
    else
        url=$(curl -fsSL "$meta_url" | jq -r '.releases[].updateTo.url | select(endswith(".zip"))' | head -1)
    fi
    if [ -z "$url" ] || [ "$url" = "null" ]; then
        echo "Error: Could not find Kiro IDE download URL for ${PLATFORM}/${ARCH}."
        echo "Metadata: $meta_url"
        exit 1
    fi
    echo "$url"
}

get_installed_ide_version() {
    local product_json="$KIRO_SHARE_DIR/resources/app/product.json"
    if [ -f "$product_json" ]; then
        jq -r '.version // empty' "$product_json" 2>/dev/null || echo "unknown"
    elif [ -x "$KIRO_SHARE_DIR/kiro" ] || [ -x "$KIRO_BIN_DIR/kiro" ]; then
        echo "installed"
    else
        echo "none"
    fi
}

create_linux_desktop_entry() {
    mkdir -p "$KIRO_DESKTOP_DIR"
    local icon="$KIRO_SHARE_DIR/resources/app/resources/linux/code.png"
    cat >"$KIRO_DESKTOP_DIR/kiro.desktop" <<EOF
[Desktop Entry]
Name=Kiro
Exec=$KIRO_SHARE_DIR/kiro %u
Icon=$icon
Terminal=false
Type=Application
Categories=Development;TextEditor;
EOF
    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database "$KIRO_DESKTOP_DIR" 2>/dev/null || true
    fi
}

install_ide_linux() {
    if [ "$ARCH" != "x64" ]; then
        echo "Error: Kiro IDE Linux builds are currently x64-only (detected: $ARCH)."
        echo "You can still install the CLI with: $0 install-cli"
        exit 1
    fi

    local url archive
    url=$(get_ide_download_url)
    archive="$TMP_DIR/kiro.tar.gz"

    echo "Downloading Kiro IDE from official metadata..."
    echo "URL: $url"
    curl -fsSL -o "$archive" "$url"

    echo "Installing to $KIRO_SHARE_DIR..."
    rm -rf "$KIRO_SHARE_DIR"
    mkdir -p "$KIRO_SHARE_DIR"
    tar -xf "$archive" -C "$KIRO_SHARE_DIR" --strip-components=1

    if [ ! -x "$KIRO_SHARE_DIR/kiro" ]; then
        echo "Error: Expected binary not found at $KIRO_SHARE_DIR/kiro"
        exit 1
    fi

    ensure_local_bin_path
    ln -sf "$KIRO_SHARE_DIR/kiro" "$KIRO_BIN_DIR/kiro"
    create_linux_desktop_entry
}

install_ide_darwin() {
    local url archive app_src
    url=$(get_ide_download_url)
    archive="$TMP_DIR/kiro.zip"

    echo "Downloading Kiro IDE from official metadata..."
    echo "URL: $url"
    curl -fsSL -o "$archive" "$url"

    echo "Extracting..."
    unzip -qo "$archive" -d "$TMP_DIR/extract"
    app_src=$(find "$TMP_DIR/extract" -maxdepth 2 -type d -name "Kiro.app" | head -1)
    if [ -z "$app_src" ]; then
        echo "Error: Kiro.app not found in download archive."
        find "$TMP_DIR/extract" -maxdepth 3 -type d | head -20
        exit 1
    fi

    mkdir -p "$KIRO_APPS_DIR"
    rm -rf "$KIRO_APPS_DIR/Kiro.app"
    mv "$app_src" "$KIRO_APPS_DIR/Kiro.app"

    ensure_local_bin_path
    local launcher=""
    if [ -x "$KIRO_APPS_DIR/Kiro.app/Contents/Resources/app/bin/code" ]; then
        launcher="$KIRO_APPS_DIR/Kiro.app/Contents/Resources/app/bin/code"
    elif [ -x "$KIRO_APPS_DIR/Kiro.app/Contents/MacOS/Kiro" ]; then
        launcher="$KIRO_APPS_DIR/Kiro.app/Contents/MacOS/Kiro"
    elif [ -x "$KIRO_APPS_DIR/Kiro.app/Contents/MacOS/Electron" ]; then
        launcher="$KIRO_APPS_DIR/Kiro.app/Contents/MacOS/Electron"
    fi
    if [ -n "$launcher" ]; then
        ln -sf "$launcher" "$KIRO_BIN_DIR/kiro"
    fi

    echo "Installed app: $KIRO_APPS_DIR/Kiro.app"
}

install_ide() {
    detect_platform
    detect_architecture
    install_dependencies
    TMP_DIR=$(mktemp -d)

    local installed_version
    installed_version=$(get_installed_ide_version)
    if [ "$installed_version" != "none" ] && [ "${KIRO_FORCE:-0}" != "1" ] && [ "${KIRO_FORCE:-0}" != "true" ]; then
        echo "Kiro IDE is already installed ($installed_version). Skipping."
        echo "Set KIRO_FORCE=1 to reinstall. Launch with: kiro"
        if [ "$KIRO_WITH_CLI" = "1" ] || [ "$KIRO_WITH_CLI" = "true" ]; then
            install_cli
        fi
        return 0
    fi

    if [ "$installed_version" != "none" ]; then
        echo "Reinstalling Kiro IDE (was $installed_version)..."
    fi

    case "$PLATFORM" in
        linux) install_ide_linux ;;
        darwin) install_ide_darwin ;;
    esac

    ensure_local_bin_path
    if [ -x "$KIRO_BIN_DIR/kiro" ] || [ -x "$KIRO_SHARE_DIR/kiro" ]; then
        echo "Kiro IDE installed successfully ($(get_installed_ide_version))."
        echo "Launch with: kiro   (or from the application menu)"
        echo "Note: the installer never starts the IDE GUI."
    else
        echo "Kiro IDE files installed. Open a new shell or run: export PATH=\"$KIRO_BIN_DIR:\$PATH\""
    fi

    if [ "$KIRO_WITH_CLI" = "1" ] || [ "$KIRO_WITH_CLI" = "true" ]; then
        install_cli
    fi
}

install_cli() {
    echo "Installing Kiro CLI via official installer..."
    curl -fsSL https://cli.kiro.dev/install | bash
    ensure_local_bin_path
    if command -v kiro-cli &>/dev/null; then
        echo "Kiro CLI installed: $(command -v kiro-cli)"
        timeout 5 kiro-cli --version 2>/dev/null || true
    else
        echo "CLI install finished. Ensure $KIRO_BIN_DIR is in PATH, then run: kiro-cli --version"
    fi
}

uninstall_kiro() {
    echo "Uninstalling Kiro..."

    if [ -f "$KIRO_DESKTOP_DIR/kiro.desktop" ]; then
        rm -f "$KIRO_DESKTOP_DIR/kiro.desktop"
        echo "Removed desktop entry"
    fi

    if [ -L "$KIRO_BIN_DIR/kiro" ] || [ -f "$KIRO_BIN_DIR/kiro" ]; then
        rm -f "$KIRO_BIN_DIR/kiro"
        echo "Removed $KIRO_BIN_DIR/kiro"
    fi

    if [ -d "$KIRO_SHARE_DIR" ]; then
        rm -rf "$KIRO_SHARE_DIR"
        echo "Removed $KIRO_SHARE_DIR"
    fi

    if [ -d "$KIRO_APPS_DIR/Kiro.app" ]; then
        rm -rf "$KIRO_APPS_DIR/Kiro.app"
        echo "Removed $KIRO_APPS_DIR/Kiro.app"
    fi

    for cli_bin in kiro-cli q; do
        if [ -L "$KIRO_BIN_DIR/$cli_bin" ] || [ -f "$KIRO_BIN_DIR/$cli_bin" ]; then
            rm -f "$KIRO_BIN_DIR/$cli_bin"
            echo "Removed $KIRO_BIN_DIR/$cli_bin"
        fi
    done

    echo "Kiro has been uninstalled."
    echo "Note: shell PATH entries in ~/.bashrc / ~/.zshrc were left in place."
}

usage() {
    echo "Usage: $0 [install|uninstall|install-cli]"
    echo ""
    echo "Commands:"
    echo "  install       Install Kiro IDE (default)"
    echo "  install-cli   Install Kiro CLI only (kiro-cli / q)"
    echo "  uninstall     Remove Kiro IDE (and local CLI binaries if present)"
    echo ""
    echo "Optional environment variables:"
    echo "  KIRO_WITH_CLI=1     Also install CLI during 'install'"
    echo "  KIRO_FORCE=1        Reinstall IDE even if already present"
    echo "  KIRO_SHARE_DIR      IDE install dir (default: ~/.local/share/kiro)"
    echo "  KIRO_BIN_DIR        Symlink dir (default: ~/.local/bin)"
    echo "  KIRO_APPS_DIR       macOS .app dir (default: ~/Applications)"
    echo ""
    echo "Examples:"
    echo "  $0 install"
    echo "  KIRO_WITH_CLI=1 $0 install"
    echo "  KIRO_FORCE=1 $0 install"
    echo "  $0 install-cli"
    echo "  $0 uninstall"
    exit 1
}

case "${1:-install}" in
    install) install_ide ;;
    install-cli) install_cli ;;
    uninstall) uninstall_kiro ;;
    *) usage ;;
esac

if [ "${1:-install}" != "uninstall" ]; then
    echo ""
    echo "Done. See https://kiro.dev/docs/getting-started/installation/"
    echo "Guide this script follows: https://dev.to/jajera/installing-kiro-on-fedora-red-hat-2i9g"
fi
