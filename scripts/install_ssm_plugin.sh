#!/bin/bash

set -e

SSM_PLUGIN_URL_BASE="https://s3.amazonaws.com/session-manager-downloads/plugin/latest"
TMP_DEB="session-manager-plugin.deb"
TMP_RPM="session-manager-plugin.rpm"
TMP_ZIP="sessionmanager-bundle.zip"
INSTALL_DIR="/usr/local/sessionmanagerplugin"
BIN_DIR="/usr/local/bin"

cleanup() {
    rm -f "$TMP_DEB" "$TMP_RPM" "$TMP_ZIP"
}
trap cleanup EXIT

detect_package_manager() {
    if command -v apt &>/dev/null; then
        PACKAGE_MANAGER="apt"
    elif command -v apt-get &>/dev/null; then
        PACKAGE_MANAGER="apt-get"
    elif command -v dnf &>/dev/null; then
        PACKAGE_MANAGER="dnf"
    elif command -v yum &>/dev/null; then
        PACKAGE_MANAGER="yum"
    elif command -v apk &>/dev/null; then
        PACKAGE_MANAGER="apk"
    else
        echo "Unsupported package manager. Exiting."
        exit 1
    fi
}

install_dependencies() {
    detect_package_manager
    echo "Detected package manager: $PACKAGE_MANAGER"

    case "$PACKAGE_MANAGER" in
    apt | apt-get)
        sudo $PACKAGE_MANAGER update && sudo $PACKAGE_MANAGER install -y curl gnupg software-properties-common
        ;;
    dnf)
        sudo dnf install -y curl gnupg2
        ;;
    yum)
        sudo yum install -y curl gnupg2
        ;;
    apk)
        sudo apk add --no-cache curl gnupg
        ;;
    *)
        echo "Unsupported package manager. Exiting."
        exit 1
        ;;
    esac
}

install_ssm_plugin() {
    if command -v session-manager-plugin &>/dev/null; then
        echo "AWS SSM Session Manager Plugin is already installed. Skipping installation."
        exit 0
    fi
    install_dependencies

    if command -v apt &>/dev/null || command -v apt-get &>/dev/null; then
        echo "Installing SSM plugin for Debian/Ubuntu..."
        curl -fsSL "$SSM_PLUGIN_URL_BASE/ubuntu_64bit/session-manager-plugin.deb" -o "$TMP_DEB"
        sudo dpkg -i "$TMP_DEB"
    elif command -v dnf &>/dev/null; then
        echo "Installing SSM plugin for Amazon Linux 2023, RHEL 8/9..."
        sudo dnf install -y "$SSM_PLUGIN_URL_BASE/linux_64bit/session-manager-plugin.rpm"
    elif command -v yum &>/dev/null; then
        echo "Installing SSM plugin for Amazon Linux 2, RHEL 7..."
        sudo yum install -y "$SSM_PLUGIN_URL_BASE/linux_64bit/session-manager-plugin.rpm"
    elif command -v apk &>/dev/null; then
        echo "Installing SSM plugin for Alpine Linux..."
        sudo apk add --no-cache session-manager-plugin
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        echo "Installing SSM plugin for macOS..."
        curl -fsSL "$SSM_PLUGIN_URL_BASE/mac/sessionmanager-bundle.zip" -o "$TMP_ZIP"
        unzip "$TMP_ZIP"
        sudo ./sessionmanager-bundle/install -i "$INSTALL_DIR" -b "$BIN_DIR/session-manager-plugin"
    else
        echo "Unsupported operating system. Exiting."
        exit 1
    fi

    echo "AWS SSM Session Manager Plugin installed successfully."
}

uninstall_ssm_plugin() {
    if ! command -v session-manager-plugin &>/dev/null; then
        echo "AWS SSM Session Manager Plugin is not installed. Skipping uninstallation."
        exit 0
    fi
    detect_package_manager
    echo "Uninstalling AWS SSM Session Manager Plugin..."

    case "$PACKAGE_MANAGER" in
    apt | apt-get)
        sudo $PACKAGE_MANAGER remove -y session-manager-plugin
        sudo dpkg --purge session-manager-plugin
        ;;
    dnf)
        sudo dnf remove -y session-manager-plugin
        ;;
    yum)
        sudo yum remove -y session-manager-plugin
        ;;
    apk)
        sudo apk del session-manager-plugin
        ;;
    *)
        echo "Unsupported package manager. Skipping removal."
        ;;
    esac

    echo "AWS SSM Session Manager Plugin has been uninstalled."
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    exit 1
}

if [ "$#" -eq 0 ]; then
    install_ssm_plugin
elif [ "$1" == "install" ]; then
    install_ssm_plugin
elif [ "$1" == "uninstall" ]; then
    uninstall_ssm_plugin
else
    usage
fi

if [ "$1" != "uninstall" ]; then
    echo "Operation completed. Run 'session-manager-plugin --version' to verify installation."
fi
