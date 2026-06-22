#!/bin/bash

set -e

# Official documentation: https://git-scm.com/download/linux
cleanup() {
    :
}
trap cleanup EXIT

usage() {
    cat <<'EOF'
Usage: install_git.sh [install|uninstall]

Default: install.

Install or remove Git using the system package manager (apt, dnf/yum, zypper,
pacman, apk, or Homebrew on macOS).

Examples:
  install_git.sh
  install_git.sh install
  install_git.sh uninstall
EOF
    exit 1
}

install_git_pkg() {
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git
    elif command -v apt &>/dev/null; then
        sudo apt update -qq
        sudo DEBIAN_FRONTEND=noninteractive apt install -y git
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y git
    elif command -v yum &>/dev/null; then
        sudo yum install -y git
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y git
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm git
    elif command -v apk &>/dev/null; then
        sudo apk add --no-cache git
    elif [[ "${OSTYPE:-}" == darwin* ]] && command -v brew &>/dev/null; then
        brew install git
    else
        echo "Error: Unsupported environment. Need one of: apt-get/apt, dnf, yum, zypper, pacman, apk, or macOS with Homebrew."
        echo "See https://git-scm.com/download/linux for other install options."
        exit 1
    fi
}

install_git() {
    if command -v git &>/dev/null; then
        echo "Git is already installed. Skipping."
        git --version 2>/dev/null || true
        exit 0
    fi

    echo "Installing Git..."
    install_git_pkg

    if ! command -v git &>/dev/null; then
        echo "Error: Install finished but git was not found on PATH."
        exit 1
    fi

    echo "Git installed successfully."
    git --version 2>/dev/null || true
}

uninstall_git() {
    if ! command -v git &>/dev/null; then
        echo "Git is not on PATH. Nothing to uninstall."
        exit 0
    fi

    local removed=false

    if command -v dpkg &>/dev/null && dpkg -s git &>/dev/null 2>&1; then
        sudo apt-get remove -y git
        removed=true
    elif command -v rpm &>/dev/null && rpm -q git &>/dev/null; then
        if command -v dnf &>/dev/null; then
            sudo dnf remove -y git
        elif command -v yum &>/dev/null; then
            sudo yum remove -y git
        elif command -v zypper &>/dev/null; then
            sudo zypper remove -y git
        else
            echo "Error: rpm shows git but neither dnf, yum, nor zypper was found."
            exit 1
        fi
        removed=true
    elif command -v pacman &>/dev/null && pacman -Qi git &>/dev/null; then
        sudo pacman -R --noconfirm git
        removed=true
    elif command -v apk &>/dev/null && apk info -e git &>/dev/null; then
        sudo apk del git
        removed=true
    elif [[ "${OSTYPE:-}" == darwin* ]] && command -v brew &>/dev/null && brew list git &>/dev/null; then
        brew uninstall git
        removed=true
    fi

    if [[ "$removed" == true ]]; then
        echo "Git has been uninstalled."
    else
        echo "Git is on PATH but was not installed via a recognized package manager. Remove it manually."
    fi
}

case "${1:-install}" in
    install) install_git ;;
    uninstall) uninstall_git ;;
    -h | --help) usage ;;
    *)
        echo "Unknown action: ${1:-}"
        usage
        ;;
esac

if [ "${1:-install}" != "uninstall" ] && [ "${1:-install}" != "-h" ] && [ "${1:-install}" != "--help" ]; then
    echo ""
    echo "Run 'git --version' to verify."
fi
