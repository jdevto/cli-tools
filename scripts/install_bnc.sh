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

is_amazon_linux_2023() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        [ "$ID" = "amzn" ] && [ "$VERSION_ID" = "2023" ]
    else
        return 1
    fi
}

detect_linux_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            debian|ubuntu|linuxmint|pop)
                echo "debian12"
                ;;
            amzn)
                if [ "$VERSION_ID" = "2023" ]; then
                    echo "rocky9"
                else
                    echo "el8"
                fi
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
                echo "debian12"
                ;;
        esac
    else
        echo "debian12"
    fi
}

bnc_missing_qt_libs() {
    local bnc_bin="$1"
    if [ ! -f "$bnc_bin" ]; then
        return 1
    fi
    ldd "$bnc_bin" 2>/dev/null | grep -q 'libQt5.*not found'
}

install_qt5_from_rocky9_repos() {
    local repo_file="/etc/yum.repos.d/bnc-qt5-rocky.repo"
    echo "Installing Qt5 runtime from Rocky Linux 9 repositories (required on Amazon Linux 2023)..."
    sudo tee "$repo_file" >/dev/null <<'EOF'
[bnc-qt5-rocky-baseos]
name=Rocky Linux 9 BaseOS (BNC Qt5 deps)
baseurl=https://download.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/
enabled=1
gpgcheck=0

[bnc-qt5-rocky-appstream]
name=Rocky Linux 9 AppStream (BNC Qt5 deps)
baseurl=https://download.rockylinux.org/pub/rocky/9/AppStream/x86_64/os/
enabled=1
gpgcheck=0
EOF
    sudo dnf install -y \
        --disablerepo="*" \
        --enablerepo=bnc-qt5-rocky-baseos,bnc-qt5-rocky-appstream \
        --exclude="*.i686" \
        qt5-qtbase qt5-qtsvg qt5-qtbase-gui
    sudo ldconfig
}

install_qt5_runtime() {
    local bnc_bin="$1"

    if ! bnc_missing_qt_libs "$bnc_bin"; then
        return 0
    fi

    echo "Installing Qt5 runtime dependencies for BNC..."

    if command -v apt-get &>/dev/null; then
        sudo apt-get update
        sudo apt-get install -y libqt5core5a libqt5network5 libqt5gui5 libqt5widgets5 libqt5svg5 2>/dev/null || \
        sudo apt-get install -y libqt5core5t64 libqt5network5t64 libqt5gui5t64 libqt5widgets5t64 libqt5svg5t64 2>/dev/null || \
        sudo apt-get install -y qtbase5-dev 2>/dev/null
    elif command -v dnf &>/dev/null || command -v yum &>/dev/null; then
        local pkg_mgr="dnf"
        command -v dnf &>/dev/null || pkg_mgr="yum"
        if is_amazon_linux_2023; then
            install_qt5_from_rocky9_repos
        elif ! sudo "$pkg_mgr" install -y qt5-qtbase qt5-qtsvg qt5-qtbase-gui; then
            echo "Standard Qt5 packages unavailable; trying Rocky Linux 9 repositories..."
            install_qt5_from_rocky9_repos
        fi
        sudo ldconfig
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y libQt5Core5 libQt5Network5 libQt5Gui5 libQt5Widgets5 libQt5Svg5 2>/dev/null || \
        sudo zypper install -y libqt5-qtbase libqt5-qtsvg 2>/dev/null
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm qt5-base qt5-svg
    elif command -v apk &>/dev/null; then
        sudo apk add qt5-qtbase qt5-qtsvg
    else
        echo "Error: Could not install Qt5 runtime libraries automatically."
        echo "Install Qt5 manually, then re-run this script."
        exit 1
    fi

    if bnc_missing_qt_libs "$bnc_bin"; then
        echo "Error: Qt5 libraries are still missing after installation."
        ldd "$bnc_bin" 2>/dev/null | grep 'not found' || true
        exit 1
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
    if command -v bnc &>/dev/null && bnc --help &>/dev/null; then
        echo "BNC is already installed. Skipping installation."
        echo "Location: $(command -v bnc)"
        exit 0
    fi

    if [ -f "${INSTALL_PREFIX}/bin/bnc" ] && "${INSTALL_PREFIX}/bin/bnc" --help &>/dev/null; then
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
        curl -fsSL -o "$archive" "$url" || { echo "Error: Failed to download BNC from $url"; exit 1; }
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

    # Find the bnc binary (named bnc-<version> in the archive)
    local bnc_bin
    bnc_bin="$TMP_DIR/bnc/bnc-${BNC_VERSION}"

    if [ ! -f "$bnc_bin" ]; then
        # Fallback: search for any file starting with bnc- that is not a doc/config
        bnc_bin=$(find "$TMP_DIR/bnc" -maxdepth 1 -type f -name "bnc-*" ! -name "*.md" ! -name "*.txt" ! -name "*.zip" 2>/dev/null | head -n 1)
    fi

    if [ -z "$bnc_bin" ] || [ ! -f "$bnc_bin" ]; then
        echo "Error: Could not find BNC binary in downloaded archive."
        echo "Contents of archive:"
        find "$TMP_DIR/bnc" -maxdepth 1 -type f | head -20
        exit 1
    fi

    if [ "$PLATFORM" = "linux" ]; then
        install_qt5_runtime "$bnc_bin"
    fi

    echo "Installing BNC to ${INSTALL_PREFIX}/bin..."
    sudo install -m 755 "$bnc_bin" "${INSTALL_PREFIX}/bin/bnc"

    if ! bnc --help &>/dev/null; then
        echo "Error: BNC installed but failed to run. Check missing libraries with:"
        echo "  ldd ${INSTALL_PREFIX}/bin/bnc"
        exit 1
    fi

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
