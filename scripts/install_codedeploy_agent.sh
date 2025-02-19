#!/bin/bash

set -e

# Set AWS region manually if not running on EC2
AWS_REGION="${AWS_REGION:-ap-southeast-2}"

CODEDEPLOY_S3_URL="https://aws-codedeploy-$AWS_REGION.s3.$AWS_REGION.amazonaws.com/latest/install"

cleanup() {
    rm -f /tmp/codedeploy-install
}
trap cleanup EXIT

get_installed_codedeploy_version() {
    if command -v codedeploy-agent &>/dev/null; then
        codedeploy-agent --version | awk '{print $3}'
    else
        echo "none"
    fi
}

install_dependencies() {
    if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y ruby wget curl jq awscli
    elif command -v yum &>/dev/null; then
        sudo yum install -y ruby wget jq aws-cli
        sudo yum install -y curl --allowerasing
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y ruby wget jq aws-cli
        sudo dnf install -y curl --allowerasing
    else
        echo "Unsupported package manager. Exiting."
        exit 1
    fi
}

install_codedeploy_agent() {
    installed_version=$(get_installed_codedeploy_version)

    if [ "$installed_version" != "none" ]; then
        echo "CodeDeploy agent is already installed (version: $installed_version)."
        exit 0
    fi

    echo "Installing AWS CodeDeploy Agent..."
    install_dependencies

    cd /tmp
    wget -O codedeploy-install "$CODEDEPLOY_S3_URL"
    chmod +x codedeploy-install
    sudo ./codedeploy-install auto

    echo "Enabling and starting CodeDeploy Agent..."
    sudo systemctl enable codedeploy-agent
    sudo systemctl start codedeploy-agent
    sudo systemctl status codedeploy-agent --no-pager

    echo "AWS CodeDeploy Agent installed successfully!"
}

uninstall_codedeploy_agent() {
    echo "Uninstalling AWS CodeDeploy Agent..."
    if command -v codedeploy-agent &>/dev/null; then
        sudo systemctl stop codedeploy-agent
        if command -v apt &>/dev/null; then
            sudo apt remove -y codedeploy-agent
        elif command -v yum &>/dev/null || command -v dnf &>/dev/null; then
            sudo yum remove -y codedeploy-agent || sudo dnf remove -y codedeploy-agent
        else
            echo "Unsupported package manager. Skipping CodeDeploy removal."
        fi
        echo "CodeDeploy Agent has been uninstalled."
    else
        echo "CodeDeploy Agent is not installed. Nothing to uninstall."
    fi
}

register_codedeploy_on_prem() {
    if [ -z "$1" ]; then
        echo "Error: Provide an instance name for on-prem registration."
        echo "Usage: $0 register <INSTANCE_NAME>"
        exit 1
    fi

    INSTANCE_NAME="$1"
    echo "Registering instance '$INSTANCE_NAME' with AWS CodeDeploy..."

    aws deploy register-on-premises-instance --instance-name "$INSTANCE_NAME" \
        --iam-session-arn "arn:aws:iam::123456789012:role/CodeDeployOnPremRole"

    echo "Instance '$INSTANCE_NAME' successfully registered with CodeDeploy."
}

usage() {
    echo "Usage: $0 [install|uninstall|register <INSTANCE_NAME>]"
    exit 1
}

if [ "$#" -eq 0 ]; then
    install_codedeploy_agent
elif [ "$1" == "install" ]; then
    install_codedeploy_agent
elif [ "$1" == "uninstall" ]; then
    uninstall_codedeploy_agent
elif [ "$1" == "register" ]; then
    register_codedeploy_on_prem "$2"
else
    usage
fi

if [ "$1" != "uninstall" ]; then
    echo "Operation completed. Run 'systemctl status codedeploy-agent' to verify installation."
fi
