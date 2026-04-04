#!/bin/bash

set -e

cleanup() {
    :
}
trap cleanup EXIT

usage() {
    cat <<'EOF'
Usage: install_ag.sh [install|uninstall]

Default: install.

Install or remove ag (The Silver Searcher) using the system package manager.
Package names follow common distro conventions (see docs/install_ag.md).

Examples:
  install_ag.sh
  install_ag.sh install
  install_ag.sh uninstall
EOF
    exit 1
}

install_ag_pkg() {
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y silversearcher-ag
    elif command -v apt &>/dev/null; then
        sudo apt update -qq
        sudo DEBIAN_FRONTEND=noninteractive apt install -y silversearcher-ag
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y the_silver_searcher
    elif command -v yum &>/dev/null; then
        sudo yum install -y the_silver_searcher
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y the_silver_searcher
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm the_silver_searcher
    elif command -v apk &>/dev/null; then
        sudo apk add --no-cache the_silver_searcher
    elif [[ "${OSTYPE:-}" == darwin* ]] && command -v brew &>/dev/null; then
        brew install the_silver_searcher
    else
        echo "Error: Unsupported environment. Need one of: apt-get/apt, dnf, yum, zypper, pacman, apk, or macOS with Homebrew."
        echo "See the Silver Searcher project on GitHub (ggreer/the_silver_searcher) for other install options."
        exit 1
    fi
}

install_ag() {
    if command -v ag &>/dev/null; then
        echo "ag is already installed. Skipping."
        ag --version 2>/dev/null || true
        exit 0
    fi

    echo "Installing The Silver Searcher (ag)..."
    install_ag_pkg

    if ! command -v ag &>/dev/null; then
        echo "Error: Install finished but ag was not found on PATH."
        exit 1
    fi

    echo "ag installed successfully."
    ag --version 2>/dev/null || true
}

uninstall_ag() {
    if ! command -v ag &>/dev/null; then
        echo "ag is not on PATH. Nothing to uninstall."
        exit 0
    fi

    local removed=false

    if command -v dpkg &>/dev/null && dpkg -s silversearcher-ag &>/dev/null 2>&1; then
        sudo apt-get remove -y silversearcher-ag
        removed=true
    elif command -v rpm &>/dev/null && rpm -q the_silver_searcher &>/dev/null; then
        if command -v dnf &>/dev/null; then
            sudo dnf remove -y the_silver_searcher
        elif command -v yum &>/dev/null; then
            sudo yum remove -y the_silver_searcher
        elif command -v zypper &>/dev/null; then
            sudo zypper remove -y the_silver_searcher
        else
            echo "Error: rpm shows the_silver_searcher but neither dnf, yum, nor zypper was found."
            exit 1
        fi
        removed=true
    elif command -v pacman &>/dev/null && pacman -Qi the_silver_searcher &>/dev/null; then
        sudo pacman -R --noconfirm the_silver_searcher
        removed=true
    elif command -v apk &>/dev/null && apk info -e the_silver_searcher &>/dev/null; then
        sudo apk del the_silver_searcher
        removed=true
    elif [[ "${OSTYPE:-}" == darwin* ]] && command -v brew &>/dev/null && brew list the_silver_searcher &>/dev/null; then
        brew uninstall the_silver_searcher
        removed=true
    fi

    if [[ "$removed" == true ]]; then
        echo "ag has been uninstalled."
    else
        echo "ag is on PATH but was not installed via a recognized package (silversearcher-ag / the_silver_searcher / Homebrew). Remove it manually."
    fi
}

case "${1:-install}" in
    install)   install_ag ;;
    uninstall) uninstall_ag ;;
    -h|--help) usage ;;
    *)
        echo "Unknown action: ${1:-}"
        usage
        ;;
esac

if [ "${1:-install}" != "uninstall" ] && [ "${1:-install}" != "-h" ] && [ "${1:-install}" != "--help" ]; then
    echo ""
    echo "Run 'ag --version' to verify."
fi
