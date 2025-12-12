#!/bin/bash

set -e

PYTHON_VERSION="${PYTHON_VERSION:-}"  # Optional: pin version (e.g., 3.12), otherwise uses latest
PYTHON_SET_ALIASES="${PYTHON_SET_ALIASES:-true}"  # Set aliases for python and python3 (default: true)
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

python_exists() {
    local python_cmd="${1:-python3}"
    command -v "$python_cmd" >/dev/null 2>&1
}

get_installed_python_version() {
    local python_cmd="${1:-python3}"
    if python_exists "$python_cmd"; then
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

get_shell_rc_file() {
    # Detect shell more reliably by checking $SHELL environment variable and common files
    local detected_shell="${SHELL:-}"

    # Check if zsh
    if [[ "$detected_shell" == *"zsh"* ]] || [ -n "$ZSH_VERSION" ]; then
        echo "${HOME}/.zshrc"
        return 0
    fi

    # For bash, prefer .bashrc (used by interactive shells)
    # But also check if .bash_profile exists and doesn't source .bashrc
    if [[ "$detected_shell" == *"bash"* ]] || [ -n "$BASH_VERSION" ] || [ -z "$detected_shell" ]; then
        # Always use .bashrc for bash - it's what interactive shells use
        echo "${HOME}/.bashrc"
        return 0
    fi

    # Fallback to .profile
    echo "${HOME}/.profile"
}

configure_pyenv_shell_integration() {
    local shell_rc
    shell_rc=$(get_shell_rc_file)

    if ! grep -q 'PYENV_ROOT="$HOME/.pyenv"' "$shell_rc" 2>/dev/null; then
        {
            echo 'export PYENV_ROOT="$HOME/.pyenv"'
            echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"'
            echo 'eval "$(pyenv init -)"'
        } >> "$shell_rc"
    fi
}

find_latest_python_binary() {
    local platform="$1"
    local target_version="$2"

    if [ "$platform" = "linux" ]; then
        # On Linux, find the highest versioned python3.x binary
        local latest_binary=""
        local latest_major_minor=""

        # Check common locations for versioned binaries
        # Try versions from 3.20 down to 3.0
        local target_major_minor=""
        if [ -n "$target_version" ]; then
            target_major_minor=$(normalize_version "$target_version")
        fi

        # Check for versioned binaries (python3.20 down to python3.0)
        for major in {20..0}; do
            local test_binary="python3.${major}"
            if python_exists "$test_binary"; then
                local ver
                ver=$(get_installed_python_version "$test_binary")
                if [ "$ver" != "none" ]; then
                    local ver_major_minor
                    ver_major_minor=$(normalize_version "$ver")

                    if [ -z "$target_major_minor" ]; then
                        # No target version, use latest found
                        if [ -z "$latest_binary" ] || [ "$(printf '%s\n' "$ver_major_minor" "$latest_major_minor" | sort -V | tail -1)" = "$ver_major_minor" ]; then
                            latest_binary="$test_binary"
                            latest_major_minor="$ver_major_minor"
                        fi
                    else
                        # Target version specified, use matching version
                        if [ "$ver_major_minor" = "$target_major_minor" ]; then
                            latest_binary="$test_binary"
                            latest_major_minor="$ver_major_minor"
                            break
                        fi
                    fi
                fi
            fi
        done

        if [ -n "$latest_binary" ]; then
            echo "$latest_binary"
            return 0
        fi

        # Fallback to python3 if no versioned binary found
        if python_exists "python3"; then
            echo "python3"
            return 0
        fi
    elif [ "$platform" = "darwin" ]; then
        # On macOS with pyenv, use python
        if command -v pyenv >/dev/null 2>&1 && python_exists "python"; then
            echo "python"
            return 0
        fi
        # Fallback to python3
        if python_exists "python3"; then
            echo "python3"
            return 0
        fi
    else
        # Fallback to python3
        if python_exists "python3"; then
            echo "python3"
            return 0
        fi
    fi

    return 1
}

check_aliases_are_correct() {
    local target_binary="$1"
    local shell_rc
    shell_rc=$(get_shell_rc_file)

    # Check primary shell rc file
    if [ -f "$shell_rc" ]; then
        # Check if our marker comment exists
        if grep -q "^# Python aliases (configured by install_python.sh)$" "$shell_rc" 2>/dev/null; then
            # Check if both aliases point to the target binary
            local python_alias
            python_alias=$(grep "^alias python=" "$shell_rc" 2>/dev/null | head -1 | sed "s/^alias python='\(.*\)'$/\1/")
            local python3_alias
            python3_alias=$(grep "^alias python3=" "$shell_rc" 2>/dev/null | head -1 | sed "s/^alias python3='\(.*\)'$/\1/")

            if [ "$python_alias" = "$target_binary" ] && [ "$python3_alias" = "$target_binary" ]; then
                # Also check .profile if it's a bash setup
                if [[ "$shell_rc" == *".bashrc"* ]] && [ -f "${HOME}/.profile" ]; then
                    if grep -q "^# Python aliases (configured by install_python.sh)$" "${HOME}/.profile" 2>/dev/null; then
                        return 0  # Aliases are already correct in both files
                    fi
                else
                    return 0  # Aliases are already correct
                fi
            fi
        fi
    fi

    return 1  # Aliases need to be created or updated
}

configure_python_aliases() {
    if [ "$PYTHON_SET_ALIASES" != "true" ] && [ "$PYTHON_SET_ALIASES" != "1" ] && [ "$PYTHON_SET_ALIASES" != "yes" ]; then
        return 0
    fi

    local target_binary
    target_binary=$(find_latest_python_binary "$PLATFORM" "$PYTHON_VERSION")

    if [ -z "$target_binary" ]; then
        echo "Warning: Could not find Python binary to create aliases"
        return 1
    fi

    # Convert to absolute path to ensure aliases work in all contexts
    # This is critical for aliases to work in new shells
    local abs_binary
    abs_binary=$(command -v "$target_binary" 2>/dev/null)
    if [ -z "$abs_binary" ]; then
        abs_binary=$(which "$target_binary" 2>/dev/null)
    fi
    if [ -n "$abs_binary" ]; then
        target_binary="$abs_binary"
    fi

    # Check if aliases are already correctly configured
    if check_aliases_are_correct "$target_binary"; then
        echo "Python aliases are already correctly configured: python and python3 -> $target_binary"
        return 0
    fi

    local shell_rc
    shell_rc=$(get_shell_rc_file)

    # Ensure the directory exists
    mkdir -p "$(dirname "$shell_rc")"

    echo "Configuring Python aliases in $shell_rc..."

    # Remove existing python/python3 aliases if they exist (including our marker comment)
    if [ -f "$shell_rc" ]; then
        # Create a temporary file without the old aliases
        local temp_file
        temp_file=$(mktemp)
        # Remove our marker comment, alias lines, and the blank line before our block
        awk '
            /^# Python aliases \(configured by install_python.sh\)$/ { skip=1; next }
            skip && /^alias python[3]*=/ { next }
            skip && /^$/ { skip=0; next }
            skip { skip=0 }
            /^alias python[3]*=/ { next }
            { print }
        ' "$shell_rc" > "$temp_file" 2>/dev/null || cp "$shell_rc" "$temp_file"
        mv "$temp_file" "$shell_rc"
    fi

    # Add new aliases
    {
        echo ""
        echo "# Python aliases (configured by install_python.sh)"
        echo "alias python='$target_binary'"
        echo "alias python3='$target_binary'"
    } >> "$shell_rc"

    # For bash, ensure aliases work in both interactive and login shells
    if [[ "$shell_rc" == *".bashrc"* ]]; then
        local bash_profile="${HOME}/.bash_profile"
        local bash_login="${HOME}/.bash_login"
        local profile="${HOME}/.profile"

        # Ensure .bash_profile sources .bashrc if it exists
        if [ -f "$bash_profile" ]; then
            if ! grep -qE '\.bashrc|source.*bashrc' "$bash_profile" 2>/dev/null; then
                echo "Ensuring $bash_profile sources $shell_rc..."
                {
                    echo ""
                    echo "# Source .bashrc if it exists (for Python aliases)"
                    echo "if [ -f ~/.bashrc ]; then"
                    echo "    . ~/.bashrc"
                    echo "fi"
                } >> "$bash_profile"
            fi
        fi

        # Also add to .profile as a fallback (used by some login shells)
        if [ -f "$profile" ] && [ "$profile" != "$shell_rc" ]; then
            if ! grep -q "^# Python aliases (configured by install_python.sh)$" "$profile" 2>/dev/null; then
                echo "Adding aliases to $profile as fallback..."
                {
                    echo ""
                    echo "# Python aliases (configured by install_python.sh)"
                    echo "alias python='$target_binary'"
                    echo "alias python3='$target_binary'"
                } >> "$profile"
            fi
        fi
    fi

    echo "Aliases configured: python and python3 -> $target_binary"
    echo "Aliases added to: $shell_rc"
    if [[ "$shell_rc" == *".bashrc"* ]] && [ -f "${HOME}/.profile" ]; then
        echo "Aliases also added to: ${HOME}/.profile (fallback)"
    fi
    echo "Note: Restart your shell or run 'source $shell_rc' for aliases to take effect"
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

    # Check if requested version is already installed
    local python_already_installed=0
    # On Linux, check for versioned binary (python3.x) first
    local versioned_binary="python${major_minor}"
    if [ "$PLATFORM" = "linux" ] && python_exists "$versioned_binary"; then
        local installed_version
        installed_version=$(get_installed_python_version "$versioned_binary")
        local installed_major_minor
        installed_major_minor=$(normalize_version "$installed_version")
        if [ "$installed_major_minor" = "$major_minor" ]; then
            echo "Python ${major_minor} is already installed (version ${installed_version})."
            echo "Current version: $($versioned_binary --version 2>&1)"
            python_already_installed=1
        fi
    fi

    # Fallback check for python3 (for macOS or when versioned binary doesn't exist)
    if [ "$python_already_installed" -eq 0 ]; then
        local installed_version
        installed_version=$(get_installed_python_version "python3")
        if [ "$installed_version" != "none" ]; then
            local installed_major_minor
            installed_major_minor=$(normalize_version "$installed_version")
            if [ "$installed_major_minor" = "$major_minor" ]; then
                echo "Python ${major_minor} is already installed (version ${installed_version})."
                echo "Current version: $(python3 --version 2>&1)"
                python_already_installed=1
            else
                echo "Python ${installed_major_minor} is installed, but ${major_minor} is requested."
            fi
        fi
    fi

    # Configure aliases even if Python is already installed (idempotent)
    if [ "$python_already_installed" -eq 1 ]; then
        configure_python_aliases
        exit 0
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
    # On Linux, check for versioned binary first (python3.x)
    local verify_cmd="python3"
    if [ "$PLATFORM" = "linux" ]; then
        local versioned_binary="python${major_minor}"
        if python_exists "$versioned_binary"; then
            verify_cmd="$versioned_binary"
        fi
    elif [ "$PLATFORM" = "darwin" ] && command -v pyenv >/dev/null 2>&1; then
        verify_cmd="python"
    fi

    if python_exists "$verify_cmd"; then
        echo "Python installed successfully: $($verify_cmd --version 2>&1)"
        if [ "$PLATFORM" = "linux" ] && [ "$verify_cmd" != "python3" ]; then
            echo "Note: Use '$verify_cmd' to access Python ${major_minor} (python3 still points to system Python)"
        fi

        # Configure aliases if enabled
        configure_python_aliases
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
    echo "  PYTHON_SET_ALIASES   - Set aliases for python and python3 (default: true)"
    echo "                         Set to 'false', '0', or 'no' to disable"
    echo ""
    echo "Examples:"
    echo "  $0 install                                    # Install latest Python"
    echo "  PYTHON_VERSION=3.12 $0 install              # Install Python 3.12"
    echo "  PYTHON_VERSION=3.11.5 $0 install            # Install Python 3.11.5"
    echo "  PYTHON_SET_ALIASES=false $0 install         # Install without setting aliases"
    echo "  $0 uninstall                                 # Uninstall Python"
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
