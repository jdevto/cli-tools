#!/bin/bash

set -e

# Official installer: https://docs.platformio.org/en/latest/core/installation/methods/install-shell.html
PLATFORMIO_CORE_DIR="${PLATFORMIO_CORE_DIR:-$HOME/.platformio}"
PLATFORMIO_VERSION="${PLATFORMIO_VERSION:-}"  # Optional: pin core version via pip in penv
PLATFORMIO_UPDATE_SHELL_RC="${PLATFORMIO_UPDATE_SHELL_RC:-true}"
PLATFORMIO_PYTHON="${PLATFORMIO_PYTHON:-}"    # Optional: force python binary (e.g. python3.12)

INSTALLER_URL="https://raw.githubusercontent.com/platformio/platformio-core-installer/master/get-platformio.py"
PENV_BIN="${PLATFORMIO_CORE_DIR}/penv/bin"
MARK_BEGIN="# >>> install_pio.sh (PlatformIO Core) >>>"
MARK_END="# <<< install_pio.sh <<<"

TMP_DIR=""

cleanup() {
    if [[ -n "${TMP_DIR:-}" ]]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

usage() {
    cat <<'EOF'
Usage: install_pio.sh [install|uninstall]

Default: install.

Installs PlatformIO Core into an isolated Python virtual environment at
$HOME/.platformio/penv using the official get-platformio.py installer.

Adds $HOME/.platformio/penv/bin to PATH in ~/.bashrc and ~/.zshrc (when present).

Optional environment variables:
  PLATFORMIO_CORE_DIR        - PlatformIO home (default: $HOME/.platformio)
  PLATFORMIO_VERSION         - Pin PlatformIO Core version (e.g. 6.1.19)
  PLATFORMIO_PYTHON          - Python binary for installer (default: best stable python3)
  PLATFORMIO_UPDATE_SHELL_RC - If true/1/yes (default), append PATH block to shell rc files.
                               Set false/0/no to skip.

Examples:
  install_pio.sh
  install_pio.sh install
  PLATFORMIO_PYTHON=python3.12 install_pio.sh install
  PLATFORMIO_VERSION=6.1.19 install_pio.sh install
  install_pio.sh uninstall
EOF
    exit 1
}

detect_platform() {
    case "${OSTYPE:-}" in
    linux-gnu* | linux-musl*) PLATFORM="linux" ;;
    darwin*) PLATFORM="darwin" ;;
    msys* | cygwin* | win32) PLATFORM="windows" ;;
    *)
        echo "Error: Unsupported OS: ${OSTYPE:-unknown}"
        exit 1
        ;;
    esac
}

check_dependencies() {
    local missing=()
    command -v curl &>/dev/null || missing+=("curl")
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Error: Missing required tools: ${missing[*]}"
        exit 1
    fi
}

find_python() {
    if [ -n "$PLATFORMIO_PYTHON" ]; then
        if command -v "$PLATFORMIO_PYTHON" &>/dev/null; then
            echo "$PLATFORMIO_PYTHON"
            return 0
        fi
        echo "Error: PLATFORMIO_PYTHON=$PLATFORMIO_PYTHON not found in PATH."
        exit 1
    fi

    local candidate
    for candidate in python3.12 python3.11 python3.10 python3.9 python3; do
        if command -v "$candidate" &>/dev/null; then
            echo "$candidate"
            return 0
        fi
    done

    echo "Error: No suitable python3 found. Install Python 3.9+ or set PLATFORMIO_PYTHON."
    exit 1
}

warn_if_prerelease_python() {
    local py="$1"
    local version
    version=$("$py" -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')
    if "$py" -c 'import sys; raise SystemExit(1 if sys.version_info.releaselevel != "final" else 0)'; then
        :
    else
        echo "Warning: $py is pre-release ($version). PlatformIO recommends stable Python 3.9-3.12."
        echo "         Set PLATFORMIO_PYTHON=python3.12 (or similar) if you hit installer issues."
    fi
}

get_installed_version() {
    local raw=""
    if [ -x "${PENV_BIN}/platformio" ]; then
        raw=$("${PENV_BIN}/platformio" --version 2>/dev/null || true)
    elif command -v platformio &>/dev/null; then
        raw=$(platformio --version 2>/dev/null || true)
    elif command -v pio &>/dev/null; then
        raw=$(pio --version 2>/dev/null || true)
    else
        echo "none"
        return 0
    fi

    if [ -z "$raw" ]; then
        echo "unknown"
        return 0
    fi

    echo "$raw" | sed -E 's/.*version[[:space:]]+([0-9.]+).*/\1/'
}

prepend_path_in_shell_configs() {
    case "${PLATFORMIO_UPDATE_SHELL_RC:-true}" in
    false | False | FALSE | 0 | no | No | NO) return 0 ;;
    esac

    local line="export PATH=\"${PENV_BIN}:\$PATH\""
    local f
    for f in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ ! -f "$f" ]; then
            continue
        fi
        if grep -qF "$MARK_BEGIN" "$f" 2>/dev/null; then
            continue
        fi
        {
            echo ""
            echo "$MARK_BEGIN"
            echo "$line"
            echo "$MARK_END"
        } >>"$f"
        echo "Added PlatformIO PATH to $f (open a new shell or: source $f)"
    done
}

remove_path_from_shell_configs() {
    local f
    for f in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ ! -f "$f" ]; then
            continue
        fi
        if ! grep -qF "$MARK_BEGIN" "$f" 2>/dev/null; then
            continue
        fi
        local tmp
        tmp=$(mktemp)
        awk -v begin="$MARK_BEGIN" -v end="$MARK_END" '
            $0 == begin { skip=1; next }
            $0 == end { skip=0; next }
            !skip { print }
        ' "$f" >"$tmp" && mv "$tmp" "$f"
        echo "Removed PlatformIO PATH block from $f"
    done
}

run_official_installer() {
    local py="$1"
    TMP_DIR=$(mktemp -d)
    local installer="${TMP_DIR}/get-platformio.py"

    echo "Downloading PlatformIO installer..."
    curl -fsSL -o "$installer" "$INSTALLER_URL"

    echo "Running PlatformIO installer with $py..."
    # Installer may print a harmless multiprocessing cleanup traceback on some Python versions.
    set +e
    "$py" "$installer"
    local installer_status=$?
    set -e

    if [ ! -x "${PENV_BIN}/platformio" ]; then
        echo "Error: PlatformIO installer did not create ${PENV_BIN}/platformio (exit ${installer_status})."
        exit 1
    fi

    if [ "$installer_status" -ne 0 ]; then
        echo "Note: Installer exited ${installer_status} but PlatformIO binary is present; continuing."
    fi
}

pin_platformio_version() {
    if [ -z "$PLATFORMIO_VERSION" ]; then
        return 0
    fi

    if [ ! -x "${PENV_BIN}/pip" ]; then
        echo "Error: pip not found in ${PENV_BIN}; cannot pin PLATFORMIO_VERSION."
        exit 1
    fi

    echo "Pinning PlatformIO Core to ${PLATFORMIO_VERSION}..."
    "${PENV_BIN}/pip" install --disable-pip-version-check "platformio==${PLATFORMIO_VERSION}"
}

install_pio() {
    detect_platform
    check_dependencies

    if [ "$PLATFORM" = "windows" ]; then
        echo "Error: Windows is not supported by this script."
        echo "Use the official PowerShell installer: https://docs.platformio.org/page/installation.html"
        exit 1
    fi

    local py
    py=$(find_python)
    warn_if_prerelease_python "$py"

    local installed
    installed=$(get_installed_version)
    if [ "$installed" != "none" ] && [ "$installed" != "unknown" ]; then
        if [ -z "$PLATFORMIO_VERSION" ] || [ "$installed" = "$PLATFORMIO_VERSION" ]; then
            echo "PlatformIO is already installed (v${installed}). Skipping core install."
            prepend_path_in_shell_configs
            export PATH="${PENV_BIN}:$PATH"
            echo "Run 'pio --version' or 'platformio --version' to verify."
            exit 0
        fi
        echo "PlatformIO v${installed} installed; upgrading/pinning to ${PLATFORMIO_VERSION}..."
        pin_platformio_version
        prepend_path_in_shell_configs
        export PATH="${PENV_BIN}:$PATH"
        echo "PlatformIO v$(get_installed_version) ready at ${PENV_BIN}"
        exit 0
    fi

    mkdir -p "$PLATFORMIO_CORE_DIR"
    run_official_installer "$py"
    pin_platformio_version
    prepend_path_in_shell_configs

    export PATH="${PENV_BIN}:$PATH"
    if ! command -v platformio &>/dev/null && ! command -v pio &>/dev/null; then
        echo "Error: PlatformIO installed but not found in PATH."
        echo "Add to PATH: export PATH=\"${PENV_BIN}:\$PATH\""
        exit 1
    fi

    echo "PlatformIO Core installed successfully at ${PENV_BIN}"
    platformio --version 2>/dev/null || pio --version
}

uninstall_pio() {
    if [ ! -d "$PLATFORMIO_CORE_DIR" ] && ! command -v platformio &>/dev/null && ! command -v pio &>/dev/null; then
        echo "PlatformIO is not installed. Nothing to uninstall."
        remove_path_from_shell_configs
        exit 0
    fi

    echo "Uninstalling PlatformIO from ${PLATFORMIO_CORE_DIR}..."
    rm -rf "$PLATFORMIO_CORE_DIR"
    remove_path_from_shell_configs
    echo "PlatformIO has been uninstalled."
    echo "Note: Open a new shell or remove any manual PATH entries if you added them separately."
}

case "${1:-install}" in
install) install_pio ;;
uninstall) uninstall_pio ;;
*) usage ;;
esac

if [ "${1:-install}" != "uninstall" ]; then
    echo ""
    echo "Run 'pio --version' to verify."
    echo "Build firmware from a PlatformIO project directory, e.g.: pio run -d firmware"
fi
