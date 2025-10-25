#!/bin/bash

set -e

# Default to latest version, can be overridden with --version flag
GRAFANA_VERSION=""
AUTO_START=false
FORCE_UNINSTALL=false
TMP_DIR="/tmp/grafana-install"
INSTALL_DIR="/opt/grafana"
CONFIG_DIR="/etc/grafana"
DATA_DIR="/var/lib/grafana"
SERVICE_DIR="/etc/systemd/system"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

get_latest_grafana_version() {
    curl -s "https://api.github.com/repos/grafana/grafana/releases/latest" | jq -r '.tag_name' | sed 's/^v//'
}

get_installed_grafana_version() {
    if [ -f "$INSTALL_DIR/bin/grafana" ]; then
        "$INSTALL_DIR/bin/grafana" --version 2>&1 | grep -oP 'version \K[0-9]+\.[0-9]+\.[0-9]+' | head -1
    else
        echo "none"
    fi
}

install_dependencies() {
    echo "Installing dependencies..."

    # Check what's missing
    local missing_packages=()

    if ! command -v tar &>/dev/null; then
        missing_packages+=("tar")
    fi

    if ! command -v curl &>/dev/null; then
        missing_packages+=("curl")
    fi

    if ! command -v jq &>/dev/null; then
        missing_packages+=("jq")
    fi

    if [ ${#missing_packages[@]} -eq 0 ]; then
        echo "All dependencies are already installed."
        return 0
    fi

    echo "Installing missing packages: ${missing_packages[*]}"

    if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y "${missing_packages[@]}"
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y "${missing_packages[@]}"
    elif command -v yum &>/dev/null; then
        sudo yum install -y "${missing_packages[@]}"
    else
        echo "Unsupported package manager. Please install ${missing_packages[*]} manually."
        exit 1
    fi
}

create_user() {
    if ! id grafana &>/dev/null; then
        echo "Creating grafana user..."
        if ! sudo useradd -r -s /bin/false grafana; then
            echo "Warning: Failed to create grafana user. Continuing with installation..."
        fi
    else
        echo "Grafana user already exists."
    fi
}

create_directories() {
    echo "Creating directories..."
    if ! sudo mkdir -p "$CONFIG_DIR"; then
        echo "Error: Failed to create config directory $CONFIG_DIR"
        exit 1
    fi
    if ! sudo mkdir -p "$DATA_DIR"; then
        echo "Error: Failed to create data directory $DATA_DIR"
        exit 1
    fi
    if ! sudo mkdir -p "$INSTALL_DIR"; then
        echo "Error: Failed to create install directory $INSTALL_DIR"
        exit 1
    fi

    # Create additional required directories
    sudo mkdir -p "/var/log/grafana"
    sudo mkdir -p "/var/lib/grafana/plugins"
    sudo mkdir -p "/etc/grafana/provisioning"

    echo "Directories created successfully"
}

download_and_install() {
    local component=$1
    local url=$2
    local archive_name=$3

    echo "Downloading $component..."
    echo "URL: $url"
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"
    echo "Working in: $(pwd)"

    curl -fsSL "$url" -o "$archive_name"

    if [ ! -f "$archive_name" ]; then
        echo "Failed to download $component from $url"
        exit 1
    fi

    echo "Downloaded $archive_name successfully"
    tar -xzf "$archive_name"
    echo "Extracted archive contents:"
    ls -la

    # Find the extracted directory
    local extracted_dir=$(ls -d grafana-* | grep -v '\.tar\.gz$' | head -1)
    if [ -z "$extracted_dir" ]; then
        echo "Error: Could not find extracted Grafana directory"
        ls -la
        exit 1
    fi

    echo "Found extracted directory: $extracted_dir"

    echo "Installing $component..."
    sudo rm -rf "$INSTALL_DIR"
    sudo mv "$extracted_dir" "$INSTALL_DIR"
    sudo chown -R grafana:grafana "$INSTALL_DIR"

    echo "$component installed successfully: $($INSTALL_DIR/bin/grafana --version 2>&1 | head -1)"
}

create_grafana_config() {
    echo "Creating Grafana configuration..."

    # Use Grafana's official default configuration as a base
    echo "Using Grafana's official default configuration with minimal modifications..."

    if [ -f "$INSTALL_DIR/conf/defaults.ini" ]; then
        echo "Copying official default configuration..."
        sudo cp "$INSTALL_DIR/conf/defaults.ini" "$CONFIG_DIR/grafana.ini"

        # Make minimal modifications for our installation
        sudo sed -i 's|;data =|data = /var/lib/grafana|g' "$CONFIG_DIR/grafana.ini"
        sudo sed -i 's|;logs =|logs = /var/log/grafana|g' "$CONFIG_DIR/grafana.ini"
        sudo sed -i 's|;plugins =|plugins = /var/lib/grafana/plugins|g' "$CONFIG_DIR/grafana.ini"
        sudo sed -i 's|;provisioning =|provisioning = /etc/grafana/provisioning|g' "$CONFIG_DIR/grafana.ini"

        # Set admin credentials properly - handle malformed lines
        sudo sed -i 's|.*admin_user =.*|admin_user = admin|' "$CONFIG_DIR/grafana.ini"
        sudo sed -i 's|.*admin_password =.*|admin_password = admin|' "$CONFIG_DIR/grafana.ini"

        # Generate a random secret key for security
        SECRET_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        sudo sed -i "/^;secret_key =/c\secret_key = $SECRET_KEY" "$CONFIG_DIR/grafana.ini"
        sudo sed -i "/^secret_key =/c\secret_key = $SECRET_KEY" "$CONFIG_DIR/grafana.ini"

        echo "Official configuration copied and customized"
        echo "Admin credentials set: admin/admin"
        echo "Secret key generated: $SECRET_KEY"
    else
        echo "Official config not found, using minimal configuration..."
        # Generate a random secret key for security
        SECRET_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        echo "Generated secret key: $SECRET_KEY"

        # Fallback to a minimal working config
        sudo tee "$CONFIG_DIR/grafana.ini" > /dev/null << EOF
[server]
http_port = 3000
domain = localhost
root_url = http://localhost:3000/

[database]
type = sqlite3
path = grafana.db

[session]
provider = file

[security]
admin_user = admin
admin_password = admin
secret_key = $SECRET_KEY

[users]
allow_sign_up = false
allow_org_create = false
auto_assign_org = true
auto_assign_org_role = Viewer

[log]
mode = console
level = info

[paths]
data = /var/lib/grafana/
logs = /var/log/grafana
plugins = /var/lib/grafana/plugins
provisioning = /etc/grafana/provisioning

[analytics]
reporting_enabled = false
check_for_updates = false
EOF
    fi

    # Set proper ownership for all Grafana directories
    sudo chown -R grafana:grafana "$CONFIG_DIR"
    sudo chown -R grafana:grafana "$DATA_DIR"
    sudo chown -R grafana:grafana "/var/log/grafana"
    sudo chown -R grafana:grafana "/var/lib/grafana"
    sudo chown -R grafana:grafana "/etc/grafana"
}

create_systemd_service() {
    echo "Creating systemd service..."

    sudo tee "$SERVICE_DIR/grafana.service" > /dev/null << 'EOF'
[Unit]
Description=Grafana service
After=network.target

[Service]
Type=notify
User=grafana
Group=grafana
ExecStartPre=/bin/bash -c 'if ! id grafana >/dev/null 2>&1; then useradd -r -s /bin/false grafana; fi'
ExecStart=/opt/grafana/bin/grafana server --config=/etc/grafana/grafana.ini --pidfile=/var/lib/grafana/grafana-server.pid
Restart=always
RestartSec=5
WorkingDirectory=/opt/grafana
Environment=GF_PATHS_CONFIG=/etc/grafana/grafana.ini
Environment=GF_PATHS_DATA=/var/lib/grafana
Environment=GF_PATHS_LOGS=/var/log/grafana
Environment=GF_PATHS_PLUGINS=/var/lib/grafana/plugins
Environment=GF_PATHS_PROVISIONING=/etc/grafana/provisioning

[Install]
WantedBy=multi-user.target
EOF
}

install_grafana() {
    # Determine version to install
    if [ -z "$GRAFANA_VERSION" ]; then
        GRAFANA_VERSION=$(get_latest_grafana_version)
        echo "Using latest version: v$GRAFANA_VERSION"
    else
        echo "Using specified version: v$GRAFANA_VERSION"
    fi

    # Set URL based on version
    GRAFANA_URL="https://dl.grafana.com/oss/release/grafana-${GRAFANA_VERSION}.linux-amd64.tar.gz"
    ARCHIVE_NAME="grafana-${GRAFANA_VERSION}.linux-amd64.tar.gz"

    installed_version=$(get_installed_grafana_version)

    if [ "$installed_version" != "none" ] && [ "$installed_version" == "$GRAFANA_VERSION" ]; then
        echo "Grafana is already installed with the requested version (v$installed_version). Skipping installation."
        exit 0
    fi

    if [ "$installed_version" == "none" ]; then
        echo "Grafana is not installed. Proceeding with installation..."
    else
        echo "Updating from v$installed_version to v$GRAFANA_VERSION..."
    fi

    install_dependencies
    create_user
    create_directories

    download_and_install "grafana" "$GRAFANA_URL" "$ARCHIVE_NAME"

    create_grafana_config
    create_systemd_service

    # Final permission fix to ensure all directories are owned by grafana user
    echo "Setting final permissions..."
    sudo chown -R grafana:grafana "$CONFIG_DIR"
    sudo chown -R grafana:grafana "$DATA_DIR"
    sudo chown -R grafana:grafana "/var/log/grafana"
    sudo chown -R grafana:grafana "/var/lib/grafana"
    sudo chown -R grafana:grafana "/etc/grafana"
    sudo chown -R grafana:grafana "$INSTALL_DIR"

    # Verify installation
    if [ ! -f "$INSTALL_DIR/bin/grafana" ]; then
        echo "Error: Grafana binary installation failed"
        exit 1
    fi

    if [ ! -f "$SERVICE_DIR/grafana.service" ]; then
        echo "Error: Grafana service file creation failed"
        exit 1
    fi

    if [ ! -f "$CONFIG_DIR/grafana.ini" ]; then
        echo "Error: Grafana configuration file creation failed"
        exit 1
    fi

    echo "Grafana installation completed successfully!"
    echo ""

    if [ "$AUTO_START" = true ]; then
        echo "Starting Grafana service..."
        sudo systemctl daemon-reload
        sudo systemctl enable grafana
        sudo systemctl start grafana
        echo "Service started. Checking status..."
        sudo systemctl status grafana --no-pager
    else
        echo "To start the service:"
        echo "  sudo systemctl daemon-reload"
        echo "  sudo systemctl enable grafana"
        echo "  sudo systemctl start grafana"
        echo ""
        echo "Or use: $0 install --start"
    fi
    echo ""
    echo "To check status:"
    echo "  sudo systemctl status grafana"
    echo ""
    echo "Grafana will be available at: http://localhost:3000"
    echo "Default credentials: admin/admin"
}

uninstall_grafana() {
    echo "Uninstalling Grafana..."

    # Stop and disable service
    sudo systemctl stop grafana 2>/dev/null || true
    sudo systemctl disable grafana 2>/dev/null || true

    # Remove binary
    sudo rm -rf "$INSTALL_DIR"

    # Remove configuration and data
    if [ "$FORCE_UNINSTALL" = true ]; then
        echo "Force mode: Removing all configuration files and data..."
        sudo rm -rf "$CONFIG_DIR"
        sudo rm -rf "$DATA_DIR"
        sudo rm -rf "/var/log/grafana"
        sudo rm -f "$SERVICE_DIR/grafana.service"
        sudo systemctl daemon-reload
    else
        read -p "Remove configuration files and data? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo rm -rf "$CONFIG_DIR"
            sudo rm -rf "$DATA_DIR"
            sudo rm -rf "/var/log/grafana"
            sudo rm -f "$SERVICE_DIR/grafana.service"
            sudo systemctl daemon-reload
        fi
    fi

    # Remove user
    if [ "$FORCE_UNINSTALL" = true ]; then
        echo "Force mode: Removing grafana user..."
        sudo userdel grafana 2>/dev/null || true
    else
        read -p "Remove grafana user? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo userdel grafana 2>/dev/null || true
        fi
    fi

    echo "Grafana has been uninstalled."
}

start_service() {
    echo "Starting Grafana service..."

    # Check if service file exists
    if [ ! -f "$SERVICE_DIR/grafana.service" ]; then
        echo "Error: Grafana service file not found at $SERVICE_DIR/grafana.service"
        echo "Please run 'sudo $0 install' first to install Grafana and create the service."
        exit 1
    fi

    # Check if binary exists
    if [ ! -f "$INSTALL_DIR/bin/grafana" ]; then
        echo "Error: Grafana binary not found at $INSTALL_DIR/bin/grafana"
        echo "Please run 'sudo $0 install' first to install Grafana."
        exit 1
    fi

    sudo systemctl daemon-reload
    sudo systemctl enable grafana
    sudo systemctl start grafana

    echo "Service started. Checking status..."
    sudo systemctl status grafana --no-pager
}

stop_service() {
    echo "Stopping Grafana service..."

    # Check if service file exists
    if [ ! -f "$SERVICE_DIR/grafana.service" ]; then
        echo "Error: Grafana service file not found at $SERVICE_DIR/grafana.service"
        echo "Please run 'sudo $0 install' first to install Grafana and create the service."
        exit 1
    fi

    sudo systemctl stop grafana
    echo "Service stopped."
}

status_service() {
    echo "Grafana service status:"

    # Check if service file exists
    if [ ! -f "$SERVICE_DIR/grafana.service" ]; then
        echo "Error: Grafana service file not found at $SERVICE_DIR/grafana.service"
        echo "Please run 'sudo $0 install' first to install Grafana and create the service."
        exit 1
    fi

    sudo systemctl status grafana --no-pager
}

usage() {
    echo "Usage: $0 [install|uninstall|start|stop|status] [--version VERSION] [--start] [--force]"
    echo ""
    echo "Commands:"
    echo "  install   - Install Grafana (latest version by default)"
    echo "  uninstall - Remove Grafana"
    echo "  start     - Start Grafana service"
    echo "  stop      - Stop Grafana service"
    echo "  status    - Show service status"
    echo ""
    echo "Options:"
    echo "  --version VERSION - Install specific version (e.g., 11.0.0)"
    echo "  --start          - Automatically start service after installation"
    echo "  --force          - Force uninstall without prompts (removes all data)"
    echo ""
    echo "Examples:"
    echo "  $0 install                    # Install latest version"
    echo "  $0 install --version 11.0.0  # Install specific version"
    echo "  $0 install --start           # Install and start service"
    echo "  $0 uninstall --force         # Remove everything without prompts"
    echo "  $0 status                    # Check service status"
    echo ""
    echo "Note: Grafana is a web-based analytics and monitoring platform."
    echo "Access it at http://localhost:3000 (default: admin/admin)"
    exit 1
}

# Parse arguments
COMMAND=""
while [[ $# -gt 0 ]]; do
    case $1 in
        install|uninstall|start|stop|status)
            COMMAND="$1"
            shift
            ;;
        --version)
            GRAFANA_VERSION="$2"
            shift 2
            ;;
        --start)
            AUTO_START=true
            shift
            ;;
        --force)
            FORCE_UNINSTALL=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Execute command
if [ -z "$COMMAND" ]; then
    install_grafana
elif [ "$COMMAND" == "install" ]; then
    install_grafana
elif [ "$COMMAND" == "uninstall" ]; then
    uninstall_grafana
elif [ "$COMMAND" == "start" ]; then
    start_service
elif [ "$COMMAND" == "stop" ]; then
    stop_service
elif [ "$COMMAND" == "status" ]; then
    status_service
else
    usage
fi

if [ "$COMMAND" != "uninstall" ] && [ "$COMMAND" != "stop" ] && [ "$COMMAND" != "status" ]; then
    echo "Operation completed. Run '$0 status' to check service status."
fi
