#!/bin/bash

set -e

VSCODE_SERVER_PORT="${VSCODE_SERVER_PORT:-8000}"
VSCODE_TOKEN="${VSCODE_TOKEN:-}"
VSCODE_THEME="${VSCODE_THEME:-Default Dark Modern}"  # Theme for VS Code Server (e.g., "Default Dark Modern", "Default Light Modern", "Default High Contrast")
VSCODE_VERSION="${VSCODE_VERSION:-}"  # Optional: pin version, otherwise uses latest
TMP_DIR="/tmp/vscode-server-install"

cleanup() {
    rm -rf "$TMP_DIR"
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
    else
        echo "Unsupported package manager. Exiting."
        exit 1
    fi
}

detect_user() {
    # Try to detect the current user, fallback to ec2-user if running as root
    if [ "$EUID" -eq 0 ]; then
        # Running as root, try to find a non-root user
        if id ec2-user &>/dev/null; then
            VSCODE_USER="ec2-user"
        elif id ubuntu &>/dev/null; then
            VSCODE_USER="ubuntu"
        elif [ -n "$SUDO_USER" ]; then
            VSCODE_USER="$SUDO_USER"
        else
            VSCODE_USER="ec2-user"
        fi
    else
        VSCODE_USER="$(whoami)"
    fi
    VSCODE_HOME="/home/$VSCODE_USER"
}

install_dependencies() {
    detect_package_manager
    echo "Detected package manager: $PACKAGE_MANAGER"

    # Check what's missing
    local missing_packages=()

    if ! command -v wget &>/dev/null; then
        missing_packages+=("wget")
    fi

    if ! command -v tar &>/dev/null; then
        missing_packages+=("tar")
    fi

    if ! command -v gzip &>/dev/null; then
        missing_packages+=("gzip")
    fi

    if ! command -v netstat &>/dev/null && ! command -v ss &>/dev/null; then
        missing_packages+=("net-tools")
    fi

    if [ ${#missing_packages[@]} -eq 0 ]; then
        echo "All dependencies are already installed."
        return 0
    fi

    echo "Installing missing packages: ${missing_packages[*]}"

    case "$PACKAGE_MANAGER" in
    apt | apt-get)
        sudo $PACKAGE_MANAGER update && sudo $PACKAGE_MANAGER install -y "${missing_packages[@]}"
        ;;
    dnf)
        sudo dnf install -y "${missing_packages[@]}"
        ;;
    yum)
        sudo yum install -y "${missing_packages[@]}"
        ;;
    *)
        echo "Unsupported package manager. Exiting."
        exit 1
        ;;
    esac
}


install_vscode_server() {
    if command -v code-server &>/dev/null && [ -f /opt/code-server/bin/code-server ]; then
        echo "VS Code Server is already installed. Skipping installation."
        echo "Current version: $(code-server --version 2>&1 | head -n 1 || echo 'unknown')"
        exit 0
    fi

    install_dependencies

    echo "Downloading VS Code Server..."

    # Get version (use pinned version if set, otherwise fetch latest)
    if [ -z "$VSCODE_VERSION" ]; then
        VSCODE_VERSION=$(wget -qO- https://api.github.com/repos/coder/code-server/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || echo "v4.106.3")
        echo "Latest VS Code Server version: $VSCODE_VERSION"
    else
        echo "Using pinned VS Code Server version: $VSCODE_VERSION"
    fi

    # Strip 'v' prefix from version for filename (tag is v4.106.3 but filename is code-server-4.106.3)
    VSCODE_VERSION_NO_V=${VSCODE_VERSION#v}

    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"

    echo "Downloading VS Code Server release..."
    wget -q "https://github.com/coder/code-server/releases/download/${VSCODE_VERSION}/code-server-${VSCODE_VERSION_NO_V}-linux-amd64.tar.gz" -O code-server.tar.gz

    echo "Extracting VS Code Server..."
    tar -xzf code-server.tar.gz
    sudo mv code-server-${VSCODE_VERSION_NO_V}-linux-amd64 /opt/code-server
    echo "VS Code Server extracted to /opt/code-server"

    # Verify code-server binary exists
    if [ -f /opt/code-server/bin/code-server ]; then
        echo "VS Code Server binary verified at /opt/code-server/bin/code-server"
        /opt/code-server/bin/code-server --version || true
    else
        echo "Error: VS Code Server binary not found!"
        exit 1
    fi
}

configure_vscode_server() {
    if [ -z "$VSCODE_TOKEN" ]; then
        echo "Error: VSCODE_TOKEN is required. Cannot configure VS Code Server."
        echo "Please provide VSCODE_TOKEN as an environment variable."
        exit 1
    fi

    detect_user

    # Create systemd service for VS Code Server
    echo "Creating systemd service for VS Code Server..."
    echo "Using user: $VSCODE_USER"
    sudo tee /etc/systemd/system/code-server.service > /dev/null <<EOF
[Unit]
Description=VS Code Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$VSCODE_USER
WorkingDirectory=$VSCODE_HOME
Environment="PASSWORD=$VSCODE_TOKEN"
ExecStart=/opt/code-server/bin/code-server --bind-addr 0.0.0.0:${VSCODE_SERVER_PORT} --auth password
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    echo "Systemd service file created"

    # Configure VS Code Server default settings with configurable theme
    echo "Configuring VS Code Server default settings..."
    echo "Using theme: $VSCODE_THEME"
    sudo mkdir -p "$VSCODE_HOME/.local/share/code-server/User"
    sudo tee "$VSCODE_HOME/.local/share/code-server/User/settings.json" > /dev/null <<EOF
{
    "workbench.colorTheme": "$VSCODE_THEME",
    "window.titleBarStyle": "custom"
}
EOF
    sudo chown -R "$VSCODE_USER:$VSCODE_USER" "$VSCODE_HOME/.local"
    echo "VS Code Server configured with theme: $VSCODE_THEME"
}

start_vscode_server() {
    if [ ! -f /etc/systemd/system/code-server.service ]; then
        echo "Error: VS Code Server service file not found. Please run installation first."
        exit 1
    fi

    if [ ! -f /opt/code-server/bin/code-server ]; then
        echo "Error: VS Code Server binary not found. Please run installation first."
        exit 1
    fi

    echo "Reloading systemd daemon..."
    sudo systemctl daemon-reload

    echo "Enabling VS Code Server service..."
    sudo systemctl enable code-server

    echo "Starting VS Code Server service..."
    if sudo systemctl start code-server; then
        echo "VS Code Server service started successfully"
    else
        echo "Error: Failed to start VS Code Server service"
        sudo systemctl status code-server --no-pager -l || true
        exit 1
    fi

    # Wait for service to start and verify it's running
    echo "Waiting for VS Code Server to initialize..."
    sleep 10

    if systemctl is-active --quiet code-server; then
        echo "VS Code Server service is active"
    else
        echo "Warning: VS Code Server service may not be active"
        sudo systemctl status code-server --no-pager -l || true
    fi

    # Verify port is listening
    echo "Verifying VS Code Server is listening on port ${VSCODE_SERVER_PORT}..."
    if netstat -tlnp 2>/dev/null | grep -q ":${VSCODE_SERVER_PORT} " || ss -tlnp 2>/dev/null | grep -q ":${VSCODE_SERVER_PORT} "; then
        echo "VS Code Server is listening on port ${VSCODE_SERVER_PORT}"
    else
        echo "Warning: VS Code Server may not be listening on port ${VSCODE_SERVER_PORT}"
        echo "Checking listening ports..."
        netstat -tlnp 2>/dev/null || ss -tlnp 2>/dev/null || true
    fi

    # Display service status
    echo "VS Code Server service status:"
    sudo systemctl status code-server --no-pager -l | head -n 20 || true
}

uninstall_vscode_server() {
    if ! command -v code-server &>/dev/null && [ ! -f /opt/code-server/bin/code-server ]; then
        echo "VS Code Server is not installed. Skipping uninstallation."
        exit 0
    fi

    echo "Uninstalling VS Code Server..."

    # Stop and disable the service (Linux only)
    if [[ "$(uname -s)" == "Linux" ]]; then
        if systemctl is-system-running &>/dev/null; then
            sudo systemctl stop code-server 2>/dev/null || true
            sudo systemctl disable code-server 2>/dev/null || true
        fi
    fi

    # Remove installation
    sudo rm -rf /opt/code-server
    sudo rm -f /etc/systemd/system/code-server.service

    # Reload systemd
    if [[ "$(uname -s)" == "Linux" ]]; then
        sudo systemctl daemon-reload
    fi

    echo "VS Code Server has been uninstalled."
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    echo ""
    echo "Required environment variables:"
    echo "  VSCODE_TOKEN       - Authentication token for VS Code Server (required)"
    echo ""
    echo "Optional environment variables:"
    echo "  VSCODE_SERVER_PORT - Port for VS Code Server (default: 8000)"
    echo "  VSCODE_THEME       - VS Code theme (default: 'Default Dark Modern')"
    echo "                       Examples: 'Default Dark Modern', 'Default Light Modern', 'Default High Contrast'"
    echo "  VSCODE_VERSION     - Pin specific version (e.g., v4.106.3) or leave empty for latest"
    echo ""
    echo "Examples:"
    echo "  VSCODE_TOKEN='mytoken123' VSCODE_SERVER_PORT=8000 $0 install"
    echo "  VSCODE_TOKEN='mytoken123' VSCODE_THEME='Default Light Modern' $0 install"
    echo "  $0 uninstall"
    exit 1
}

if [ "$#" -eq 0 ]; then
    install_vscode_server
    configure_vscode_server
    start_vscode_server
elif [ "$1" == "install" ]; then
    install_vscode_server
    configure_vscode_server
    start_vscode_server
elif [ "$1" == "uninstall" ]; then
    uninstall_vscode_server
else
    usage
fi

if [ "$1" != "uninstall" ]; then
    echo ""
    echo "VS Code Server installation completed successfully."
    echo "VS Code Server is running on port ${VSCODE_SERVER_PORT}"
    echo "Theme: ${VSCODE_THEME}"
    echo "Run 'code-server --version' to verify installation."
fi
