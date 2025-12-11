#!/bin/bash

set -e

UV_VERSION="${UV_VERSION:-}"  # Optional: pin version, otherwise uses latest

cleanup() {
    # No temporary files to clean up (install scripts are piped directly)
    :
}
trap cleanup EXIT

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

    if ! command -v curl &>/dev/null; then
        missing_deps+=("curl")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}"
        echo "Please install ${missing_deps[*]} and try again."
        exit 1
    fi
}

install_uv() {
    if command -v uv &>/dev/null; then
        echo "UV is already installed. Skipping installation."
        echo "Current version: $(uv --version 2>&1 | head -n 1 || echo 'unknown')"
        exit 0
    fi

    detect_platform
    detect_architecture
    check_dependencies

    echo "Installing UV (Python package manager)..."

    case "$PLATFORM" in
    linux | darwin)
        echo "Installing UV for $PLATFORM ($ARCH)..."
        if curl -LsSf https://astral.sh/uv/install.sh | sh; then
            # Add to PATH if not already there
            if [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
                export PATH="$HOME/.cargo/bin:$PATH"
                # Add to shell profile for persistence
                if [ -f "$HOME/.bashrc" ] && ! grep -q '\.cargo/bin' "$HOME/.bashrc"; then
                    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
                fi
                if [ -f "$HOME/.zshrc" ] && ! grep -q '\.cargo/bin' "$HOME/.zshrc"; then
                    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.zshrc"
                fi
            fi
            echo "UV installed successfully"
        else
            echo "Error: Failed to install UV via install script"
            echo "Trying fallback method: pip install..."
            if command -v pip3 &>/dev/null || command -v python3 &>/dev/null; then
                if python3 -m pip install uv 2>/dev/null || pip3 install uv 2>/dev/null; then
                    echo "UV installed successfully via pip"
                else
                    echo "Error: Failed to install UV via pip"
                    exit 1
                fi
            else
                echo "Error: Could not find pip or python3 for fallback installation"
                exit 1
            fi
        fi
        ;;
    windows)
        echo "Installing UV for Windows..."
        if powershell -c "irm https://astral.sh/uv/install.ps1 | iex"; then
            echo "UV installed successfully"
        else
            echo "Error: Failed to install UV via PowerShell script"
            echo "Trying fallback method: pip install..."
            if command -v pip &>/dev/null || command -v python &>/dev/null; then
                if python -m pip install uv 2>/dev/null || pip install uv 2>/dev/null; then
                    echo "UV installed successfully via pip"
                else
                    echo "Error: Failed to install UV via pip"
                    exit 1
                fi
            else
                echo "Error: Could not find pip or python for fallback installation"
                exit 1
            fi
        fi
        ;;
    *)
        echo "Unsupported platform: $PLATFORM"
        exit 1
        ;;
    esac

    # Verify UV is installed
    if ! command -v uv &>/dev/null; then
        # Try common installation paths
        if [ -f "$HOME/.cargo/bin/uv" ]; then
            export PATH="$HOME/.cargo/bin:$PATH"
        elif [ -f "$HOME/.local/bin/uv" ]; then
            export PATH="$HOME/.local/bin:$PATH"
        fi

        if ! command -v uv &>/dev/null; then
            echo "Error: UV installation completed but binary not found in PATH"
            echo "Please add UV to your PATH manually or restart your shell"
            exit 1
        fi
    fi

    echo "UV version: $(uv --version 2>&1 || echo 'unknown')"
}

uninstall_uv() {
    if ! command -v uv &>/dev/null; then
        echo "UV is not installed. Skipping uninstallation."
        exit 0
    fi

    echo "Uninstalling UV..."

    detect_platform

    case "$PLATFORM" in
    linux | darwin)
        # Try to remove from cargo/bin
        if [ -f "$HOME/.cargo/bin/uv" ]; then
            rm -f "$HOME/.cargo/bin/uv"
            rm -f "$HOME/.cargo/bin/uvx"
            echo "Removed UV from $HOME/.cargo/bin"
        fi

        # Try to remove from local/bin (pip installation)
        if [ -f "$HOME/.local/bin/uv" ]; then
            rm -f "$HOME/.local/bin/uv"
            rm -f "$HOME/.local/bin/uvx"
            echo "Removed UV from $HOME/.local/bin"
        fi

        # Try pip uninstall
        if command -v pip3 &>/dev/null; then
            pip3 uninstall -y uv 2>/dev/null || true
        fi
        ;;
    windows)
        # Try pip uninstall
        if command -v pip &>/dev/null; then
            pip uninstall -y uv 2>/dev/null || true
        fi
        # Note: Windows installation via PowerShell script may require manual removal
        echo "Note: If UV was installed via PowerShell script, you may need to remove it manually"
        ;;
    *)
        echo "Unsupported platform: $PLATFORM"
        exit 1
        ;;
    esac

    echo "UV has been uninstalled."
    echo "Note: You may need to restart your shell or remove PATH entries manually."
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    echo ""
    echo "Optional environment variables:"
    echo "  UV_VERSION         - Pin specific version (not currently supported, uses latest)"
    echo ""
    echo "Examples:"
    echo "  $0 install"
    echo "  $0 uninstall"
    exit 1
}

if [ "$#" -eq 0 ]; then
    install_uv
elif [ "$1" == "install" ]; then
    install_uv
elif [ "$1" == "uninstall" ]; then
    uninstall_uv
else
    usage
fi

if [ "$1" != "uninstall" ]; then
    echo ""
    echo "UV installation completed successfully."
    echo "Run 'uv --version' to verify installation."
fi
