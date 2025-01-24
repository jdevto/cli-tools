#!/bin/bash

set -e

TERRAFORM_REPO="https://rpm.releases.hashicorp.com"
APT_GPG_KEY="https://apt.releases.hashicorp.com/gpg"
APT_REPO="https://apt.releases.hashicorp.com"
TMP_KEY="hashicorp.gpg"

cleanup() {
    rm -f "$TMP_KEY"
}
trap cleanup EXIT

get_latest_terraform_version() {
    curl -s "https://api.github.com/repos/hashicorp/terraform/releases/latest" | jq -r .tag_name | sed 's/^v//'
}

get_installed_terraform_version() {
    if command -v terraform &>/dev/null; then
        terraform version | head -n1 | awk '{print $2}' | sed 's/^v//'
    else
        echo "none"
    fi
}

install_dependencies() {
    if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y curl gnupg software-properties-common
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y curl gnupg2
    else
        echo "Unsupported package manager. Exiting."
        exit 1
    fi
}

install_terraform() {
    installed_version=$(get_installed_terraform_version)
    latest_version=$(get_latest_terraform_version)

    if [ "$installed_version" != "none" ] && [ "$installed_version" == "$latest_version" ]; then
        echo "Terraform is already up-to-date ($installed_version). Skipping installation."
        exit 0
    fi

    if [ "$installed_version" == "none" ]; then
        echo "Terraform is not installed. Proceeding with installation..."
    else
        echo "New Terraform version available ($latest_version). Updating..."
    fi

    install_dependencies

    if command -v apt &>/dev/null; then
        curl -fsSL "$APT_GPG_KEY" | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] $APT_REPO $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt update && sudo apt install -y terraform
    elif command -v dnf &>/dev/null; then
        sudo dnf config-manager --add-repo $TERRAFORM_REPO/RHEL/hashicorp.repo
        sudo dnf install -y terraform
    fi

    echo "Terraform installed successfully: $(terraform version)"
}

uninstall_terraform() {
    echo "Uninstalling Terraform..."
    if command -v terraform &>/dev/null; then
        if command -v apt &>/dev/null; then
            sudo apt remove -y terraform
            sudo rm -f /usr/share/keyrings/hashicorp-archive-keyring.gpg
            sudo rm -f /etc/apt/sources.list.d/hashicorp.list
        elif command -v dnf &>/dev/null; then
            sudo dnf remove -y terraform
            sudo rm -f /etc/yum.repos.d/hashicorp.repo
        else
            echo "Unsupported package manager. Skipping Terraform removal."
        fi
        echo "Terraform has been uninstalled."
    else
        echo "Terraform is not installed. Nothing to uninstall."
    fi
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    exit 1
}

if [ "$#" -eq 0 ]; then
    install_terraform
elif [ "$1" == "install" ]; then
    install_terraform
elif [ "$1" == "uninstall" ]; then
    uninstall_terraform
else
    usage
fi

if [ "$1" != "uninstall" ]; then
    echo "Operation completed. Run 'terraform version' to verify installation."
fi
