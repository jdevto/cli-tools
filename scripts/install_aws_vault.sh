#!/bin/bash

set -e

AWS_VAULT_URL="https://github.com/99designs/aws-vault/releases/latest/download/aws-vault-linux-amd64"
AWS_VAULT_BIN="/usr/local/bin/aws-vault"
GPG_AGENT_CONF="$HOME/.gnupg/gpg-agent.conf"
AWS_VAULT_BACKEND=${2:-"pass"}  # Default to 'pass' if not provided

install_aws_cli() {
    echo "Ensuring AWS CLI is installed..."
    if ! command -v aws &>/dev/null; then
        echo "AWS CLI is not installed. Installing..."
        bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_aws_cli.sh) install
    else
        echo "AWS CLI is already installed: $(aws --version)"
    fi
}

uninstall_aws_cli() {
    echo "Ensuring AWS CLI is uninstalled..."
    if command -v aws &>/dev/null; then
        echo "AWS CLI is installed. Uninstalling..."
        bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_aws_cli.sh) uninstall
    else
        echo "AWS CLI is already uninstalled."
    fi
}

install_dependencies() {
    echo "Installing dependencies..."
    if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y pinentry-tty pass
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y pinentry pass
    else
        echo "Unsupported package manager. Exiting."
        exit 1
    fi
}

uninstall_dependencies() {
    echo "Uninstalling dependencies..."
    if command -v apt &>/dev/null; then
        sudo apt remove -y pinentry-tty pass
        sudo apt autoremove -y
    elif command -v dnf &>/dev/null; then
        sudo dnf remove -y pinentry pass
    else
        echo "Unsupported package manager. Skipping dependencies removal."
    fi
}

install_aws_vault() {
    install_aws_cli

    echo "Checking for the latest AWS Vault version..."
    latest_version=$(curl -s https://api.github.com/repos/99designs/aws-vault/releases/latest | jq -r .tag_name)

    if [ -z "$latest_version" ]; then
        echo "Failed to fetch the latest AWS Vault version. Exiting."
        exit 1
    fi

    echo "Checking for existing AWS Vault installation..."
    if command -v aws-vault &>/dev/null; then
        current_version=$(aws-vault --version | awk '{print $3}')
        echo "Installed AWS Vault version: $current_version"
        if [ "$(printf '%s' "$current_version" "$latest_version" | sort -V | head -n1)" == "$latest_version" ]; then
            echo "AWS Vault is already up-to-date. Skipping installation."
            return
        fi
        echo "New version available ($latest_version). Updating..."
    else
        echo "AWS Vault is not installed. Proceeding with installation..."
    fi

    echo "Downloading AWS Vault binary (version $latest_version)..."
    sudo curl -L -o "$AWS_VAULT_BIN" "https://github.com/99designs/aws-vault/releases/download/$latest_version/aws-vault-linux-amd64"
    sudo chmod 755 "$AWS_VAULT_BIN"
    echo "AWS Vault installed successfully: $(aws-vault --version)"

    install_dependencies

    echo "Configuring AWS Vault backend..."
    if [ "$AWS_VAULT_BACKEND" == "file" ]; then
        echo "Using file backend for AWS Vault..."
        if ! grep -q "export AWS_VAULT_BACKEND=file" "$HOME/.bashrc"; then
            echo "export AWS_VAULT_BACKEND=file" >> "$HOME/.bashrc"
            source "$HOME/.bashrc"
        fi
    else
        echo "Using pass backend for AWS Vault..."
        if ! grep -q "pinentry-program /usr/bin/pinentry" "$GPG_AGENT_CONF"; then
            echo "pinentry-program /usr/bin/pinentry" >> "$GPG_AGENT_CONF"
            gpgconf --kill gpg-agent
            gpgconf --launch gpg-agent
        fi

        if ! gpg --list-keys --with-colons | awk -F: '/^pub/ {print $5; exit}'; then
            echo "No GPG key found. Generating one..."
            gpg --generate-key
        fi

        if ! pass show initialized &>/dev/null; then
            echo "Initializing pass with the first available GPG key..."
            gpg --list-keys --with-colons | awk -F: '/^pub/ {print $5; exit}' | xargs -I {} pass init {}
        fi
    fi
}

uninstall_aws_vault() {
    echo "Uninstalling AWS Vault..."
    if command -v aws-vault &> /dev/null; then
        sudo rm -f "$AWS_VAULT_BIN"
        echo "AWS Vault has been uninstalled."
    else
        echo "AWS Vault is not installed. Nothing to uninstall."
    fi

    uninstall_dependencies
    uninstall_aws_cli
}

usage() {
    echo "Usage: $0 [install|uninstall] [backend: pass|file]"
    exit 1
}

if [ "$#" -eq 0 ]; then
    install_aws_vault
elif [ "$1" == "install" ]; then
    install_aws_vault
elif [ "$1" == "uninstall" ]; then
    uninstall_aws_vault
else
    usage
fi

if [ "$1" != "uninstall" ]; then
    echo "Operation completed. Run 'aws-vault --version' to verify installation."
fi
