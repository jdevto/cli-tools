#!/bin/bash

set -e

SSM_AGENT_URL_BASE="https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent"
TMP_DEB="amazon-ssm-agent.deb"
TMP_RPM="amazon-ssm-agent.rpm"
TMP_MSI="AmazonSSMAgent.msi"
TMP_PKG="amazon-ssm-agent.pkg"

cleanup() {
    rm -f "$TMP_DEB" "$TMP_RPM" "$TMP_MSI" "$TMP_PKG"
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
        sudo $PACKAGE_MANAGER update && sudo $PACKAGE_MANAGER install -y curl
        ;;
    dnf)
        sudo dnf install -y curl
        ;;
    yum)
        sudo yum install -y curl
        ;;
    apk)
        sudo apk add --no-cache curl
        ;;
    *)
        echo "Unsupported package manager. Exiting."
        exit 1
        ;;
    esac
}

install_ssm_agent() {
    if command -v amazon-ssm-agent &>/dev/null; then
        echo "AWS SSM Agent is already installed. Skipping installation."
        echo "Current version: $(amazon-ssm-agent --version 2>&1 | head -n 1 || echo 'unknown')"
        exit 0
    fi
    install_dependencies

    if command -v apt &>/dev/null || command -v apt-get &>/dev/null; then
        echo "Installing SSM agent for Debian/Ubuntu..."
        # Detect architecture
        ARCH=$(dpkg --print-architecture)
        if [ "$ARCH" = "amd64" ]; then
            ARCH="x86_64"
        elif [ "$ARCH" = "arm64" ]; then
            ARCH="arm64"
        fi
        curl -fsSL "$SSM_AGENT_URL_BASE/latest/debian_$ARCH/amazon-ssm-agent.deb" -o "$TMP_DEB"
        sudo dpkg -i "$TMP_DEB"
    elif command -v dnf &>/dev/null; then
        echo "Installing SSM agent for Amazon Linux 2023, RHEL 8/9, Fedora..."
        # Try installing from repository first (preferred method)
        if sudo dnf install -y amazon-ssm-agent 2>/dev/null; then
            echo "SSM agent installed from repository"
        else
            # Fallback to manual installation
            ARCH=$(uname -m)
            if [ "$ARCH" = "x86_64" ]; then
                curl -fsSL "$SSM_AGENT_URL_BASE/latest/linux_amd64/amazon-ssm-agent.rpm" -o "$TMP_RPM"
            elif [ "$ARCH" = "aarch64" ]; then
                curl -fsSL "$SSM_AGENT_URL_BASE/latest/linux_arm64/amazon-ssm-agent.rpm" -o "$TMP_RPM"
            else
                echo "Unsupported architecture: $ARCH"
                exit 1
            fi
            sudo rpm -Uvh "$TMP_RPM"
        fi
    elif command -v yum &>/dev/null; then
        echo "Installing SSM agent for Amazon Linux 2, RHEL 7, CentOS 7..."
        # Try installing from repository first (preferred method)
        if sudo yum install -y amazon-ssm-agent 2>/dev/null; then
            echo "SSM agent installed from repository"
        else
            # Fallback to manual installation
            ARCH=$(uname -m)
            if [ "$ARCH" = "x86_64" ]; then
                curl -fsSL "$SSM_AGENT_URL_BASE/latest/linux_amd64/amazon-ssm-agent.rpm" -o "$TMP_RPM"
            elif [ "$ARCH" = "aarch64" ]; then
                curl -fsSL "$SSM_AGENT_URL_BASE/latest/linux_arm64/amazon-ssm-agent.rpm" -o "$TMP_RPM"
            else
                echo "Unsupported architecture: $ARCH"
                exit 1
            fi
            sudo rpm -Uvh "$TMP_RPM"
        fi
    elif command -v apk &>/dev/null; then
        echo "Installing SSM agent for Alpine Linux..."
        # Alpine doesn't have official SSM agent package, manual installation required
        ARCH=$(uname -m)
        if [ "$ARCH" = "x86_64" ]; then
            curl -fsSL "$SSM_AGENT_URL_BASE/latest/linux_amd64/amazon-ssm-agent.rpm" -o "$TMP_RPM"
            # Convert RPM to Alpine package or install directly
            sudo apk add --allow-untrusted "$TMP_RPM" || sudo rpm -Uvh --nodeps "$TMP_RPM"
        elif [ "$ARCH" = "aarch64" ]; then
            curl -fsSL "$SSM_AGENT_URL_BASE/latest/linux_arm64/amazon-ssm-agent.rpm" -o "$TMP_RPM"
            sudo apk add --allow-untrusted "$TMP_RPM" || sudo rpm -Uvh --nodeps "$TMP_RPM"
        else
            echo "Unsupported architecture: $ARCH"
            exit 1
        fi
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        echo "Installing SSM agent for macOS..."
        ARCH=$(uname -m)
        if [ "$ARCH" = "arm64" ]; then
            curl -fsSL "$SSM_AGENT_URL_BASE/latest/darwin_arm64/amazon-ssm-agent.pkg" -o "$TMP_PKG"
        else
            curl -fsSL "$SSM_AGENT_URL_BASE/latest/darwin_amd64/amazon-ssm-agent.pkg" -o "$TMP_PKG"
        fi
        sudo installer -pkg "$TMP_PKG" -target /
    elif [[ "$(uname -s)" == "MINGW"* ]] || [[ "$(uname -s)" == "MSYS"* ]] || [[ "$(uname -s)" == "CYGWIN"* ]]; then
        echo "Installing SSM agent for Windows..."
        ARCH=$(uname -m)
        if [ "$ARCH" = "x86_64" ]; then
            curl -fsSL "$SSM_AGENT_URL_BASE/latest/windows_amd64/AmazonSSMAgent.msi" -o "$TMP_MSI"
        else
            echo "Unsupported Windows architecture: $ARCH"
            exit 1
        fi
        msiexec /i "$TMP_MSI" /quiet
    else
        echo "Unsupported operating system. Exiting."
        exit 1
    fi

    # Start and enable the service (Linux only)
    if [[ "$(uname -s)" == "Linux" ]]; then
        if systemctl is-system-running &>/dev/null; then
            echo "Starting and enabling SSM agent service..."
            sudo systemctl enable amazon-ssm-agent
            sudo systemctl start amazon-ssm-agent
            echo "SSM agent service started and enabled"
        elif command -v service &>/dev/null; then
            echo "Starting SSM agent service..."
            sudo service amazon-ssm-agent start
            sudo chkconfig amazon-ssm-agent on 2>/dev/null || true
        fi
    fi

    echo "AWS SSM Agent installed successfully."
}

uninstall_ssm_agent() {
    if ! command -v amazon-ssm-agent &>/dev/null; then
        echo "AWS SSM Agent is not installed. Skipping uninstallation."
        exit 0
    fi
    detect_package_manager
    echo "Uninstalling AWS SSM Agent..."

    # Stop and disable the service (Linux only)
    if [[ "$(uname -s)" == "Linux" ]]; then
        if systemctl is-system-running &>/dev/null; then
            sudo systemctl stop amazon-ssm-agent 2>/dev/null || true
            sudo systemctl disable amazon-ssm-agent 2>/dev/null || true
        elif command -v service &>/dev/null; then
            sudo service amazon-ssm-agent stop 2>/dev/null || true
        fi
    fi

    case "$PACKAGE_MANAGER" in
    apt | apt-get)
        sudo $PACKAGE_MANAGER remove -y amazon-ssm-agent
        sudo dpkg --purge amazon-ssm-agent
        ;;
    dnf)
        sudo dnf remove -y amazon-ssm-agent
        ;;
    yum)
        sudo yum remove -y amazon-ssm-agent
        ;;
    apk)
        sudo apk del amazon-ssm-agent
        ;;
    *)
        echo "Unsupported package manager. Skipping removal."
        ;;
    esac

    echo "AWS SSM Agent has been uninstalled."
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    exit 1
}

if [ "$#" -eq 0 ]; then
    install_ssm_agent
elif [ "$1" == "install" ]; then
    install_ssm_agent
elif [ "$1" == "uninstall" ]; then
    uninstall_ssm_agent
else
    usage
fi

if [ "$1" != "uninstall" ]; then
    echo "Operation completed. Run 'amazon-ssm-agent --version' to verify installation."
fi
