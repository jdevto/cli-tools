#!/bin/bash

set -e

TMP_DIR="/tmp/sam-install"

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
ARCH=""

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
    else
        echo "Unsupported platform: $OSTYPE"
        exit 1
    fi
}

detect_architecture() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            ARCH_NAME="x86_64"
            ;;
        aarch64|arm64)
            ARCH_NAME="aarch64"
            ;;
        *)
            echo "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
}

get_installed_sam_version() {
    if command -v sam >/dev/null 2>&1; then
        sam --version 2>&1 | head -1 | awk '{print $NF}' || echo "unknown"
    else
        echo "none"
    fi
}

install_dependencies() {
    detect_package_manager
    echo "Detected package manager: $PACKAGE_MANAGER"

    local missing_packages=()

    if ! command -v curl >/dev/null 2>&1; then
        missing_packages+=("curl")
    fi

    if ! command -v unzip >/dev/null 2>&1; then
        missing_packages+=("unzip")
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

get_install_directory() {
    if [ "$(id -u)" -eq 0 ]; then
        echo "/usr/local/bin"
    else
        echo "$HOME/.local/bin"
    fi
}

setup_bash_completion() {
    local install_dir
    install_dir=$(get_install_directory)
    local completion_dir
    local bashrc_file

    if [ "$(id -u)" -eq 0 ]; then
        completion_dir="/etc/bash_completion.d"
        bashrc_file="/etc/bash.bashrc"
    else
        completion_dir="$HOME/.bash_completion.d"
        bashrc_file="$HOME/.bashrc"
    fi

    mkdir -p "$completion_dir"

    local completion_file="$completion_dir/sam"
    if command -v sam >/dev/null 2>&1; then
        sam completion bash >"$completion_file" 2>/dev/null || {
            echo "Warning: Could not generate bash completion for sam"
            return 1
        }
    elif [ -f "$install_dir/sam" ]; then
        "$install_dir/sam" completion bash >"$completion_file" 2>/dev/null || {
            echo "Warning: Could not generate bash completion for sam"
            return 1
        }
    else
        echo "Warning: sam binary not found for completion setup"
        return 1
    fi

    if [ -f "$completion_file" ]; then
        if [ "$(id -u)" -eq 0 ]; then
            if ! grep -q 'source /etc/bash_completion.d/sam' "$bashrc_file" 2>/dev/null; then
                echo 'source /etc/bash_completion.d/sam' >>"$bashrc_file"
            fi
        else
            local completion_line="source \$HOME/.bash_completion.d/sam"
            if ! grep -qxF "$completion_line" "$bashrc_file" 2>/dev/null; then
                echo "$completion_line" >>"$bashrc_file"
            fi
        fi
        echo "Bash completion configured in $bashrc_file"
    fi
}

install_sam_linux() {
    local install_dir
    install_dir=$(get_install_directory)

    echo "Installing AWS SAM CLI on Linux..."

    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"

    local sam_url="https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-${ARCH_NAME}.zip"
    echo "Downloading AWS SAM CLI from: $sam_url"

    if ! curl -fsSL -o sam-cli.zip "$sam_url"; then
        echo "Failed to download AWS SAM CLI from $sam_url"
        exit 1
    fi

    if [ ! -s sam-cli.zip ]; then
        echo "Downloaded file is empty"
        exit 1
    fi

    if ! unzip -t sam-cli.zip >/dev/null 2>&1; then
        echo "Downloaded file is not a valid zip file"
        exit 1
    fi

    echo "Extracting AWS SAM CLI..."
    unzip -q sam-cli.zip

    # Ensure install directory exists
    mkdir -p "$install_dir"

    # Install SAM CLI
    if [ -f "dist/sam" ]; then
        # Copy the entire dist directory to preserve bundled Python libraries
        cp -r dist "$install_dir/"
        chmod +x "$install_dir/dist/sam"
        # Create a symlink for easier access
        if [ -L "$install_dir/sam" ] || [ -f "$install_dir/sam" ]; then
            rm -f "$install_dir/sam"
        fi
        ln -sf "$install_dir/dist/sam" "$install_dir/sam"
    elif [ -f "sam" ]; then
        cp sam "$install_dir/"
        chmod +x "$install_dir/sam"
    else
        echo "Could not find sam binary in downloaded package"
        exit 1
    fi

    # Ensure install directory is in PATH
    if [ "$(id -u)" -ne 0 ]; then
        if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
            export PATH="$HOME/.local/bin:$PATH"
        fi
    fi

    cd /
}

install_sam_darwin() {
    local install_dir
    install_dir=$(get_install_directory)

    echo "Installing AWS SAM CLI on macOS..."

    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"

    local sam_url="https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-mac-${ARCH_NAME}.zip"
    echo "Downloading AWS SAM CLI from: $sam_url"

    if ! curl -fsSL -o sam-cli.zip "$sam_url"; then
        echo "Failed to download AWS SAM CLI from $sam_url"
        exit 1
    fi

    if [ ! -s sam-cli.zip ]; then
        echo "Downloaded file is empty"
        exit 1
    fi

    if ! unzip -t sam-cli.zip >/dev/null 2>&1; then
        echo "Downloaded file is not a valid zip file"
        exit 1
    fi

    echo "Extracting AWS SAM CLI..."
    unzip -q sam-cli.zip

    # Ensure install directory exists
    mkdir -p "$install_dir"

    # Install SAM CLI
    if [ -f "dist/sam" ]; then
        # Copy the entire dist directory to preserve bundled Python libraries
        cp -r dist "$install_dir/"
        chmod +x "$install_dir/dist/sam"
        # Create a symlink for easier access
        if [ -L "$install_dir/sam" ] || [ -f "$install_dir/sam" ]; then
            rm -f "$install_dir/sam"
        fi
        ln -sf "$install_dir/dist/sam" "$install_dir/sam"
    elif [ -f "sam" ]; then
        cp sam "$install_dir/"
        chmod +x "$install_dir/sam"
    else
        echo "Could not find sam binary in downloaded package"
        exit 1
    fi

    # Ensure install directory is in PATH
    if [ "$(id -u)" -ne 0 ]; then
        if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
            export PATH="$HOME/.local/bin:$PATH"
        fi
    fi

    cd /
}

install_sam() {
    detect_platform
    detect_architecture
    install_dependencies

    local installed_version
    installed_version=$(get_installed_sam_version)

    if [ "$installed_version" != "none" ]; then
        echo "AWS SAM CLI is already installed (version: $installed_version)."
        echo "Current version: $(sam --version 2>&1 | head -1)"
        echo "Skipping installation."
        exit 0
    fi

    echo "Installing AWS SAM CLI..."

    case "$PLATFORM" in
        linux)
            install_sam_linux
            ;;
        darwin)
            install_sam_darwin
            ;;
        *)
            echo "Unsupported platform: $PLATFORM"
            exit 1
            ;;
    esac

    # Verify installation
    local install_dir
    install_dir=$(get_install_directory)

    if command -v sam >/dev/null 2>&1; then
        echo "AWS SAM CLI installed successfully: $(sam --version 2>&1 | head -1)"
    elif [ -f "$install_dir/sam" ]; then
        echo "AWS SAM CLI installed successfully at $install_dir/sam"
        "$install_dir/sam" --version
    else
        echo "Warning: 'sam' command not found in PATH or at $install_dir"
        echo "You may need to add $install_dir to your PATH"
        exit 1
    fi

    # Setup bash completion
    setup_bash_completion || true
}

uninstall_sam() {
    local install_dir
    install_dir=$(get_install_directory)

    echo "Uninstalling AWS SAM CLI..."

    if command -v sam >/dev/null 2>&1 || [ -f "$install_dir/sam" ]; then
        # Remove symlink
        if [ -L "$install_dir/sam" ]; then
            rm -f "$install_dir/sam"
        fi
        # Remove binary
        if [ -f "$install_dir/sam" ]; then
            rm -f "$install_dir/sam"
        fi
        # Remove dist directory if it exists
        if [ -d "$install_dir/dist" ]; then
            rm -rf "$install_dir/dist"
        fi

        # Remove bash completion
        local completion_dir
        local bashrc_file

        if [ "$(id -u)" -eq 0 ]; then
            completion_dir="/etc/bash_completion.d"
            bashrc_file="/etc/bash.bashrc"
        else
            completion_dir="$HOME/.bash_completion.d"
            bashrc_file="$HOME/.bashrc"
        fi

        if [ -f "$completion_dir/sam" ]; then
            rm -f "$completion_dir/sam"
        fi

        # Remove completion source line from bashrc
        if [ -f "$bashrc_file" ]; then
            if [ "$(id -u)" -eq 0 ]; then
                sed -i '/source \/etc\/bash_completion.d\/sam/d' "$bashrc_file" 2>/dev/null || true
            else
                sed -i '/source \$HOME\/.bash_completion.d\/sam/d' "$bashrc_file" 2>/dev/null || true
            fi
        fi

        echo "AWS SAM CLI has been uninstalled."
    else
        echo "AWS SAM CLI is not installed. Nothing to uninstall."
    fi
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    exit 1
}

if [ "$#" -eq 0 ]; then
    install_sam
elif [ "$1" == "install" ]; then
    install_sam
elif [ "$1" == "uninstall" ]; then
    uninstall_sam
else
    usage
fi

if [ "${1:-install}" != "uninstall" ]; then
    echo ""
    echo "AWS SAM CLI installation completed (or already satisfied)."
    echo "Run 'sam --version' to verify installation."
fi
