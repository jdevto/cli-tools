#!/bin/bash

set -e

PYTHON_VERSION="${PYTHON_VERSION:-}"  # Optional: pin version (e.g., 3.12), otherwise uses latest
TMP_DIR="/tmp/python-install"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Decide how to run privileged commands
SUDO="sudo"
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
elif ! command -v sudo >/dev/null 2>&1; then
    echo "sudo not found and you are not root; cannot install packages."
    exit 1
fi

PACKAGE_MANAGER=""
PLATFORM=""

normalize_version() {
    local version="$1"
    # Convert 3.12.5 to 3.12, or keep 3.12 as is
    echo "$version" | cut -d. -f1,2
}

get_installed_python_version() {
    local python_cmd="${1:-python3}"
    if command -v "$python_cmd" >/dev/null 2>&1; then
        # python3 --version -> "Python 3.12.3", extract 3.12
        "$python_cmd" --version 2>&1 | awk '{print $2}' | cut -d. -f1,2 | head -1
    else
        echo "none"
    fi
}

get_latest_python_version() {
    # Get latest stable Python version (major.minor) from python.org
    curl -s "https://www.python.org/ftp/python/" \
        | grep -E 'href="[0-9]+\.[0-9]+\.[0-9]+/' \
        | sed -E 's/.*href="([0-9]+\.[0-9]+\.[0-9]+)\/".*/\1/' \
        | sort -V \
        | tail -1 \
        | cut -d. -f1,2
}

detect_package_manager() {
    if command -v dnf >/dev/null 2>&1; then
        PACKAGE_MANAGER="dnf"
    elif command -v yum >/dev/null 2>&1; then
        PACKAGE_MANAGER="yum"
    elif command -v apt >/dev/null 2>&1 || command -v apt-get >/dev/null 2>&1; then
        if command -v apt >/dev/null 2>&1; then
            PACKAGE_MANAGER="apt"
        else
            PACKAGE_MANAGER="apt-get"
        fi
    elif command -v brew >/dev/null 2>&1; then
        PACKAGE_MANAGER="brew"
    else
        echo "Unsupported package manager. Exiting."
        exit 1
    fi
}

detect_platform() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        PLATFORM="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        PLATFORM="darwin"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        PLATFORM="windows"
    else
        echo "Unsupported platform: $OSTYPE"
        exit 1
    fi
}

install_dependencies() {
    detect_package_manager
    echo "Detected package manager: $PACKAGE_MANAGER"

    local missing_packages=()

    if ! command -v curl >/dev/null 2>&1; then
        missing_packages+=("curl")
    fi

    if [ ${#missing_packages[@]} -eq 0 ]; then
        echo "All dependencies are already installed."
        return 0
    fi

    echo "Installing missing packages: ${missing_packages[*]}"

    case "$PACKAGE_MANAGER" in
        apt|apt-get)
            $SUDO $PACKAGE_MANAGER update
            $SUDO $PACKAGE_MANAGER install -y "${missing_packages[@]}"
            ;;
        dnf)
            $SUDO dnf install -y "${missing_packages[@]}"
            ;;
        yum)
            $SUDO yum install -y "${missing_packages[@]}"
            ;;
        brew)
            brew install "${missing_packages[@]}"
            ;;
        *)
            echo "Unsupported package manager. Exiting."
            exit 1
            ;;
    esac
}

install_python_linux_apt() {
    local version="$1"
    local major_minor
    major_minor=$(normalize_version "$version")

    echo "Installing Python ${version} on Debian/Ubuntu..."

    local system_version
    system_version=$(get_installed_python_version "python3")
    if [ "$system_version" != "none" ]; then
        local system_major_minor
        system_major_minor=$(normalize_version "$system_version")
        # If system Python is same or newer, use system repos
        if [ "$(printf '%s\n' "$system_major_minor" "$major_minor" | sort -V | head -1)" = "$major_minor" ]; then
            echo "Installing Python ${major_minor} from system repositories..."
            $SUDO $PACKAGE_MANAGER update
            $SUDO $PACKAGE_MANAGER install -y "python${major_minor}" "python${major_minor}-dev" "python${major_minor}-venv"
            return 0
        fi
    fi

    # For newer versions, use deadsnakes on Ubuntu only
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" && "$ID_LIKE" != *"ubuntu"* ]]; then
            echo "Deadsnakes PPA is Ubuntu only; cannot install Python ${major_minor} this way."
            echo "Consider using pyenv or building from source."
            exit 1
        fi
    fi

    echo "Adding deadsnakes PPA for Python ${major_minor}..."
    $SUDO $PACKAGE_MANAGER update
    $SUDO $PACKAGE_MANAGER install -y software-properties-common
    $SUDO add-apt-repository -y ppa:deadsnakes/ppa
    $SUDO $PACKAGE_MANAGER update
    $SUDO $PACKAGE_MANAGER install -y "python${major_minor}" "python${major_minor}-dev" "python${major_minor}-venv"
}

install_python_linux_dnf() {
    local version="$1"
    local major_minor
    major_minor=$(normalize_version "$version")

    echo "Installing Python ${version} on RHEL/CentOS/Fedora..."

    # Try system repositories first
    if $SUDO $PACKAGE_MANAGER install -y "python${major_minor}" 2>/dev/null; then
        echo "Python ${major_minor} installed from system repositories."
        return 0
    fi

    # For older RHEL/CentOS, try EPEL if using yum
    if [ "$PACKAGE_MANAGER" = "yum" ]; then
        echo "Installing EPEL repository..."
        $SUDO yum install -y epel-release
        if $SUDO yum install -y "python${major_minor}" 2>/dev/null; then
            echo "Python ${major_minor} installed from EPEL."
            return 0
        fi
    fi

    echo "Warning: Python ${major_minor} not available in repositories."
    echo "Consider using pyenv for version management: https://github.com/pyenv/pyenv"
    exit 1
}

install_python_linux() {
    detect_package_manager

    if [ "$PACKAGE_MANAGER" = "apt" ] || [ "$PACKAGE_MANAGER" = "apt-get" ]; then
        install_python_linux_apt "$1"
    elif [ "$PACKAGE_MANAGER" = "dnf" ] || [ "$PACKAGE_MANAGER" = "yum" ]; then
        install_python_linux_dnf "$1"
    else
        echo "Unsupported package manager for Linux: $PACKAGE_MANAGER"
        exit 1
    fi
}

configure_pyenv_shell_integration() {
    local shell_rc

    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="${HOME}/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_rc="${HOME}/.bash_profile"
    else
        shell_rc="${HOME}/.profile"
    fi

    if ! grep -q 'PYENV_ROOT="$HOME/.pyenv"' "$shell_rc" 2>/dev/null; then
        {
            echo 'export PYENV_ROOT="$HOME/.pyenv"'
            echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"'
            echo 'eval "$(pyenv init -)"'
        } >> "$shell_rc"
    fi
}

install_python_darwin() {
    local version="$1"
    local major_minor
    major_minor=$(normalize_version "$version")

    echo "Installing Python ${version} on macOS..."

    if ! command -v brew >/dev/null 2>&1; then
        echo "Error: Homebrew is required for Python installation on macOS."
        echo "Install Homebrew: https://brew.sh"
        exit 1
    fi

    # Use pyenv via Homebrew for better version management
    if ! command -v pyenv >/dev/null 2>&1; then
        echo "Installing pyenv via Homebrew..."
        brew install pyenv
    fi

    configure_pyenv_shell_integration

    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"

    echo "Installing Python ${major_minor} via pyenv..."
    pyenv install -s "${major_minor}"
    pyenv global "${major_minor}" 2>/dev/null || true
}

install_python_windows() {
    echo "Windows Python installation is not fully automated."
    echo "Please install Python manually from: https://www.python.org/downloads/"
    echo ""
    echo "Or use pyenv-win: https://github.com/pyenv-win/pyenv-win"
    exit 1
}

install_python() {
    detect_platform
    install_dependencies

    # Determine version to install
    if [ -z "$PYTHON_VERSION" ]; then
        PYTHON_VERSION=$(get_latest_python_version)
        if [ -z "$PYTHON_VERSION" ]; then
            echo "Failed to detect latest Python version from python.org" >&2
            exit 1
        fi
        echo "Latest Python version (major.minor): ${PYTHON_VERSION}"
    else
        echo "Using specified Python version: ${PYTHON_VERSION}"
    fi

    local major_minor
    major_minor=$(normalize_version "$PYTHON_VERSION")
    local installed_version
    installed_version=$(get_installed_python_version "python3")

    # Check if requested version is already installed
    if [ "$installed_version" != "none" ]; then
        local installed_major_minor
        installed_major_minor=$(normalize_version "$installed_version")
        if [ "$installed_major_minor" = "$major_minor" ]; then
            echo "Python ${major_minor} is already installed (version ${installed_version})."
            echo "Current version: $(python3 --version 2>&1)"
            exit 0
        else
            echo "Python ${installed_major_minor} is installed, but ${major_minor} is requested."
        fi
    fi

    echo "Installing Python ${PYTHON_VERSION}..."

    case "$PLATFORM" in
        linux)
            install_python_linux "$PYTHON_VERSION"
            ;;
        darwin)
            install_python_darwin "$PYTHON_VERSION"
            ;;
        windows)
            install_python_windows
            ;;
        *)
            echo "Unsupported platform: $PLATFORM"
            exit 1
            ;;
    esac

    # Verify installation
    local verify_cmd="python3"
    if [ "$PLATFORM" = "darwin" ] && command -v pyenv >/dev/null 2>&1; then
        verify_cmd="python"
    fi

    if command -v "$verify_cmd" >/dev/null 2>&1; then
        echo "Python installed successfully: $($verify_cmd --version 2>&1)"
    else
        echo "Warning: Python installation completed but binary not found in PATH"
        echo "You may need to restart your shell or add Python to PATH manually"
    fi
}

uninstall_python() {
    detect_platform
    detect_package_manager

    local installed_version
    installed_version=$(get_installed_python_version "python3")

    if [ "$installed_version" = "none" ]; then
        echo "Python is not installed. Skipping uninstallation."
        exit 0
    fi

    echo "Uninstalling Python ${installed_version}..."

    case "$PLATFORM" in
        linux)
            local major_minor
            major_minor=$(normalize_version "$installed_version")
            echo "Warning: removing Python packages can affect system tools on non-container systems."
            case "$PACKAGE_MANAGER" in
                apt|apt-get)
                    $SUDO $PACKAGE_MANAGER remove -y "python${major_minor}" "python${major_minor}-dev" "python${major_minor}-venv" 2>/dev/null || true
                    ;;
                dnf|yum)
                    $SUDO $PACKAGE_MANAGER remove -y "python${major_minor}" 2>/dev/null || true
                    ;;
            esac
            ;;
        darwin)
            local major_minor
            major_minor=$(normalize_version "$installed_version")
            if command -v pyenv >/dev/null 2>&1; then
                echo "Note: Python may be installed via pyenv. Use 'pyenv uninstall ${installed_version}' to remove."
            else
                echo "Note: Python may be installed via Homebrew. Use 'brew uninstall python@${major_minor}' to remove."
            fi
            ;;
        windows)
            echo "Please uninstall Python manually from Windows Settings or Control Panel."
            ;;
    esac

    echo "Python uninstallation completed."
    echo "Note: system Python (python3) may still be available if it is a system dependency."
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    echo ""
    echo "Optional environment variables:"
    echo "  PYTHON_VERSION       - Pin specific version (e.g., 3.12 or 3.12.5) or leave empty for latest"
    echo ""
    echo "Examples:"
    echo "  $0 install                          # Install latest Python"
    echo "  PYTHON_VERSION=3.12 $0 install      # Install Python 3.12"
    echo "  PYTHON_VERSION=3.11.5 $0 install    # Install Python 3.11.5"
    echo "  $0 uninstall                        # Uninstall Python"
    exit 1
}

if [ "$#" -eq 0 ]; then
    install_python
elif [ "$1" = "install" ]; then
    install_python
elif [ "$1" = "uninstall" ]; then
    uninstall_python
else
    usage
fi

if [ "${1:-install}" != "uninstall" ]; then
    echo ""
    echo "Python installation completed (or already satisfied)."
    echo "Run 'python3 --version' to verify installation."
fi
