#!/bin/bash

set -e

# BKG Ntrip Client (BNC) — GNSS real-time stream client
# Download from: https://igs.bkg.bund.de/ntrip/bnc
BNC_VERSION="${BNC_VERSION:-2.13.6}"
BNC_BASE_URL="https://igs.bkg.bund.de/root_ftp/NTRIP/software/BNC"
INSTALL_PREFIX="${BNC_PREFIX:-/usr/local}"
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

check_dependencies() {
    local missing_deps=()

    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
        missing_deps+=("curl or wget")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}"
        echo "Please install ${missing_deps[*]} and try again."
        exit 1
    fi
}

detect_linux_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            debian|ubuntu|linuxmint|pop)
                echo "debian12"
                ;;
            rhel|centos|rocky|alma|fedora)
                local major_ver
                major_ver=$(echo "${VERSION_ID}" | cut -d. -f1)
                if [ "$major_ver" -ge 9 ] 2>/dev/null; then
                    echo "rocky9"
                else
                    echo "el8"
                fi
                ;;
            opensuse*|sles|suse)
                echo "suse15"
                ;;
            *)
                # Default to debian12 as most broadly compatible
                echo "debian12"
                ;;
        esac
    else
        echo "debian12"
    fi
}

get_download_url() {
    # BNC provides shared Linux binaries (require Qt5)
    case "$PLATFORM" in
    linux)
        if [ "$ARCH" = "x86_64" ]; then
            local distro
            distro=$(detect_linux_distro)
            echo "${BNC_BASE_URL}/bnc-${BNC_VERSION}-${distro}.zip"
        elif [ "$ARCH" = "arm64" ]; then
            echo "${BNC_BASE_URL}/bnc-${BNC_VERSION}-raspi.zip"
        else
            echo "Error: BNC prebuilt binary not available for $ARCH. Build from source instead."
            echo "Source: https://igs.bkg.bund.de/ntrip/bnc"
            exit 1
        fi
        ;;
    darwin)
        echo "${BNC_BASE_URL}/BNC-2.13.1-macOS.zip"
        ;;
    *)
        echo "Unsupported platform: $PLATFORM"
        exit 1
        ;;
    esac
}

install_bnc() {
    if command -v bnc &>/dev/null; then
        echo "BNC is already installed. Skipping installation."
        echo "Location: $(command -v bnc)"
        exit 0
    fi

    if [ -f "${INSTALL_PREFIX}/bin/bnc" ]; then
        echo "BNC is already installed at ${INSTALL_PREFIX}/bin/bnc. Skipping."
        exit 0
    fi

    detect_platform
    detect_architecture
    check_dependencies

    local url
    url=$(get_download_url)

    echo "Installing BKG Ntrip Client (BNC) ${BNC_VERSION}..."
    echo "Downloading from: $url"

    TMP_DIR=$(mktemp -d)
    local archive="$TMP_DIR/bnc.zip"

    if command -v curl &>/dev/null; then
        curl -fL --progress-bar -o "$archive" "$url" || { echo "Error: Failed to download BNC from $url"; exit 1; }
    else
        wget --progress=bar:force -O "$archive" "$url" || { echo "Error: Failed to download BNC from $url"; exit 1; }
    fi

    # Install unzip if needed
    if ! command -v unzip &>/dev/null; then
        echo "Installing unzip..."
        if command -v apt &>/dev/null; then
            sudo apt-get update && sudo apt-get install -y unzip
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y unzip
        elif command -v yum &>/dev/null; then
            sudo yum install -y unzip
        elif command -v pacman &>/dev/null; then
            sudo pacman -Sy --noconfirm unzip
        elif command -v brew &>/dev/null; then
            brew install unzip
        else
            echo "Error: unzip is required. Please install it manually."
            exit 1
        fi
    fi

    unzip -o "$archive" -d "$TMP_DIR/bnc"

    # Find the bnc binary in extracted contents (binary name includes version, e.g. bnc-2.13.6)
    local bnc_bin
    bnc_bin=$(find "$TMP_DIR/bnc" -name "bnc-*" -type f -perm /111 2>/dev/null | grep -v '\.md\|\.txt\|\.bnc\|\.sh\|\.zip' | head -n 1)

    if [ -z "$bnc_bin" ]; then
        # Try matching the versioned binary without executable permission check
        bnc_bin=$(find "$TMP_DIR/bnc" -name "bnc-${BNC_VERSION}" -type f 2>/dev/null | head -n 1)
    fi

    if [ -z "$bnc_bin" ]; then
        # Last resort: look for any ELF binary
        bnc_bin=$(find "$TMP_DIR/bnc" -maxdepth 1 -type f 2>/dev/null | while read -r f; do
            if file "$f" 2>/dev/null | grep -q "ELF\|Mach-O\|executable"; then
                echo "$f"
                break
            fi
        done)
    fi

    if [ -z "$bnc_bin" ]; then
        echo "Error: Could not find BNC binary in downloaded archive."
        echo "Contents of archive:"
        find "$TMP_DIR/bnc" -type f | head -20
        exit 1
    fi

    # Install Qt5 shared libraries if needed (Linux shared builds require Qt5)
    if [ "$PLATFORM" = "linux" ]; then
        if ! ldconfig -p 2>/dev/null | grep -q libQt5Core; then
            echo "Installing Qt5 runtime dependencies..."
            if command -v apt &>/dev/null; then
                sudo apt-get update && sudo apt-get install -y libqt5core5a libqt5network5 libqt5gui5
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y qt5-qtbase qt5-qtbase-gui
            elif command -v yum &>/dev/null; then
                sudo yum install -y qt5-qtbase qt5-qtbase-gui
            elif command -v zypper &>/dev/null; then
                sudo zypper install -y libQt5Core5 libQt5Network5 libQt5Gui5
            elif command -v pacman &>/dev/null; then
                sudo pacman -Sy --noconfirm qt5-base
            else
                echo "Warning: Qt5 libraries may be required. Install them manually if BNC fails to run."
            fi
        fi
    fi

    echo "Installing BNC to ${INSTALL_PREFIX}/bin..."
    sudo install -m 755 "$bnc_bin" "${INSTALL_PREFIX}/bin/bnc"

    if ! command -v bnc &>/dev/null; then
        echo "BNC installed to ${INSTALL_PREFIX}/bin/bnc. Ensure ${INSTALL_PREFIX}/bin is in your PATH."
    else
        echo "BNC ${BNC_VERSION} installed successfully."
    fi
}

uninstall_bnc() {
    local bin_path="${INSTALL_PREFIX}/bin/bnc"
    if [ ! -f "$bin_path" ] && ! command -v bnc &>/dev/null; then
        echo "BNC is not installed. Nothing to uninstall."
        exit 0
    fi

    echo "Uninstalling BNC..."
    if [ -f "$bin_path" ]; then
        sudo rm -f "$bin_path"
        echo "Removed $bin_path"
    elif command -v bnc &>/dev/null; then
        local path
        path=$(command -v bnc)
        sudo rm -f "$path"
        echo "Removed $path"
    fi
    echo "BNC has been uninstalled."
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    echo ""
    echo "Optional environment variables:"
    echo "  BNC_VERSION   - BNC version (default: 2.13.6)"
    echo "  BNC_PREFIX    - Install prefix (default: /usr/local)"
    echo ""
    echo "Examples:"
    echo "  $0 install"
    echo "  $0 uninstall"
    echo "  BNC_VERSION=2.13.6 $0 install"
    exit 1
}

case "${1:-install}" in
    install) install_bnc ;;
    uninstall) uninstall_bnc ;;
    *) usage ;;
esac

if [ "${1:-install}" != "uninstall" ]; then
    echo ""
    echo "BNC installation completed successfully."
    echo "Run 'bnc --help' to verify installation."
fi
