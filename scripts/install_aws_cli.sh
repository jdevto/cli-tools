#!/bin/bash

set -e

AWS_CLI_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
TMP_ZIP="awscliv2.zip"
TMP_DIR="aws"

cleanup() {
    rm -rf "$TMP_DIR" "$TMP_ZIP"
}
trap cleanup EXIT

get_latest_aws_version() {
    curl -s "https://api.github.com/repos/aws/aws-cli/tags" | jq -r '.[].name' | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' | sed 's/^v//' | sort -V | tail -1
}

get_installed_aws_version() {
    if command -v aws &>/dev/null; then
        aws --version | awk '{print $1}' | cut -d/ -f2
    else
        echo "none"
    fi
}

install_dependencies() {
    if ! command -v aws &>/dev/null; then
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y unzip curl
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y unzip curl
        else
            echo "Unsupported package manager. Exiting."
            exit 1
        fi
    fi
}

install_aws_cli() {
    installed_version=$(get_installed_aws_version)
    latest_version=$(get_latest_aws_version)

    if [ "$installed_version" != "none" ] && [ "$installed_version" == "$latest_version" ]; then
        echo "AWS CLI is already up-to-date. Skipping installation."
        exit 0
    fi

    if [ "$installed_version" == "none" ]; then
        echo "AWS CLI is not installed. Proceeding with installation..."
    else
        echo "New version available ($latest_version). Updating..."
    fi

    install_dependencies

    echo "Downloading AWS CLI installer..."
    curl -fsSL "$AWS_CLI_URL" -o "$TMP_ZIP"

    if [ ! -f "$TMP_ZIP" ]; then
        echo "Failed to download AWS CLI installer."
        exit 1
    fi

    unzip -q "$TMP_ZIP"
    sudo ./aws/install --update

    if ! command -v aws &>/dev/null; then
        echo "AWS CLI installation failed."
        exit 1
    fi

    echo "AWS CLI installed successfully: $(aws --version)"
}

uninstall_aws_cli() {
    echo "Uninstalling AWS CLI..."
    if command -v aws &> /dev/null; then
        sudo rm -rf /usr/local/aws-cli /usr/bin/aws
        echo "AWS CLI has been uninstalled."
    else
        echo "AWS CLI is not installed. Nothing to uninstall."
    fi
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    exit 1
}

if [ "$#" -eq 0 ]; then
    install_aws_cli
elif [ "$1" == "install" ]; then
    install_aws_cli
elif [ "$1" == "uninstall" ]; then
    uninstall_aws_cli
else
    usage
fi

if [ "$1" != "uninstall" ]; then
    echo "Operation completed. Run 'aws --version' to verify installation."
fi
