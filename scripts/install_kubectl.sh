#!/bin/bash

set -e

KUBECTL_URL="https://dl.k8s.io"
KUBECTL_STABLE_URL="$KUBECTL_URL/release/stable.txt"
TMP_BIN="kubectl"
INSTALL_PATH="/usr/local/bin/kubectl"

cleanup() {
    rm -f "$TMP_BIN"
}
trap cleanup EXIT

get_latest_kubectl_version() {
    curl -sSL "$KUBECTL_STABLE_URL"
}

get_installed_kubectl_version() {
    if command -v kubectl &>/dev/null; then
        kubectl version --client --output=json 2>/dev/null | jq -r '.clientVersion.gitVersion' | sed 's/v//'
    else
        echo "none"
    fi
}

install_dependencies() {
    local missing_deps=()
    for dep in curl jq; do
        if ! command -v "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ "${#missing_deps[@]}" -ne 0 ]; then
        echo "Installing missing dependencies: ${missing_deps[*]}"
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y "${missing_deps[@]}"
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y "${missing_deps[@]}"
        elif command -v yum &>/dev/null; then
            sudo yum install -y "${missing_deps[@]}"
        elif command -v zypper &>/dev/null; then
            sudo zypper install -y "${missing_deps[@]}"
        elif command -v pacman &>/dev/null; then
            sudo pacman -Sy --noconfirm "${missing_deps[@]}"
        else
            echo "Unsupported package manager. Install ${missing_deps[*]} manually."
            exit 1
        fi
    fi
}

install_kubectl() {
    install_dependencies

    local installed_version
    installed_version=$(get_installed_kubectl_version)
    local latest_version
    latest_version=$(get_latest_kubectl_version)

    if [ "$installed_version" != "none" ] && [ "$installed_version" == "$latest_version" ]; then
        echo "kubectl is already up-to-date ($installed_version). Skipping installation."
        exit 0
    fi

    echo "Installing kubectl $latest_version..."

    curl -LO "$KUBECTL_URL/$latest_version/bin/linux/amd64/kubectl"
    chmod +x "$TMP_BIN"
    sudo mv "$TMP_BIN" "$INSTALL_PATH"

    if ! command -v kubectl &>/dev/null; then
        echo "kubectl installation failed."
        exit 1
    fi

    echo "kubectl installed successfully: $(kubectl version --client --output=json | jq -r '.clientVersion.gitVersion')"
}

uninstall_kubectl() {
    echo "Uninstalling kubectl..."
    if command -v kubectl &>/dev/null; then
        sudo rm -f "$INSTALL_PATH"
        echo "kubectl has been uninstalled."
    else
        echo "kubectl is not installed. Nothing to uninstall."
    fi
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    exit 1
}

case "$1" in
"" | install) install_kubectl ;;
uninstall) uninstall_kubectl ;;
*) usage ;;
esac

if [ "$1" != "uninstall" ]; then
    echo "Operation completed. Run 'kubectl version --client' to verify installation."
fi
