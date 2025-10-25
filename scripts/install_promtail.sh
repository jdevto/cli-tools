#!/bin/bash

set -e

# Default to latest version, can be overridden with --version flag
PROMTAIL_VERSION=""
ENABLE_LOKI_CONFIG=false
AUTO_START=false
FORCE_UNINSTALL=false
TMP_DIR="/tmp/promtail-install"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/promtail"
DATA_DIR="/var/lib/promtail"
SERVICE_DIR="/etc/systemd/system"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

get_latest_promtail_version() {
    curl -s "https://api.github.com/repos/grafana/loki/releases/latest" | jq -r '.tag_name' | sed 's/^v//'
}

get_installed_promtail_version() {
    if command -v promtail &>/dev/null; then
        promtail --version 2>&1 | grep -oP 'version \K[0-9]+\.[0-9]+\.[0-9]+' | head -1
    else
        echo "none"
    fi
}

check_prerequisites() {
    echo "Checking prerequisites..."

    # Check for required tools
    local missing_tools=()

    if ! command -v curl &>/dev/null; then
        missing_tools+=("curl")
    fi

    if ! command -v unzip &>/dev/null; then
        missing_tools+=("unzip")
    fi

    if ! command -v jq &>/dev/null; then
        missing_tools+=("jq")
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "Installing missing tools: ${missing_tools[*]}"
        install_dependencies "${missing_tools[@]}"
    fi

    echo "✅ Prerequisites check passed"
}

check_loki_optional() {
    echo "Checking for Loki (optional)..."

    # Check if Loki is installed locally
    if command -v loki &>/dev/null; then
        echo "✅ Loki found locally"

        # Test local Loki connectivity
        if curl -s http://localhost:3100/ready >/dev/null 2>&1; then
            echo "✅ Local Loki is running and accessible"
            return 0
        else
            echo "⚠️  Local Loki is installed but not running"
            echo "   Start it with: sudo systemctl start loki"
            return 1
        fi
    else
        echo "ℹ️  No local Loki installation found"
        echo "   Promtail can still work with remote Loki or other destinations"
        return 1
    fi
}

install_dependencies() {
    local tools=("$@")
    echo "Installing dependencies: ${tools[*]}..."

    if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y "${tools[@]}"
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y "${tools[@]}"
    elif command -v yum &>/dev/null; then
        sudo yum install -y "${tools[@]}"
    else
        echo "❌ ERROR: Unsupported package manager. Please install ${tools[*]} manually."
        exit 1
    fi
}

create_user() {
    if ! id promtail &>/dev/null; then
        echo "Creating promtail user..."
        sudo useradd -r -s /bin/false promtail
    else
        echo "Promtail user already exists."
    fi
}

create_directories() {
    echo "Creating directories..."
    sudo mkdir -p "$CONFIG_DIR"
    sudo mkdir -p "$DATA_DIR"
}

download_and_install() {
    local component=$1
    local url=$2
    local binary_name=$3

    echo "Downloading $component..."
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"

    curl -fsSL "$url" -o "${component}.zip"

    if [ ! -f "${component}.zip" ]; then
        echo "❌ ERROR: Failed to download $component."
        exit 1
    fi

    unzip -q "${component}.zip"

    if [ ! -f "$binary_name" ]; then
        echo "❌ ERROR: Binary $binary_name not found in archive."
        exit 1
    fi

    echo "Installing $component..."
    sudo mv "$binary_name" "$INSTALL_DIR/$component"
    sudo chmod +x "$INSTALL_DIR/$component"

    echo "$component installed successfully: $($INSTALL_DIR/$component --version 2>&1 | head -1)"
}

create_promtail_config() {
    echo "Creating Promtail configuration..."

    if [ "$ENABLE_LOKI_CONFIG" = true ]; then
        echo "Creating Loki-compatible configuration..."
        sudo tee "$CONFIG_DIR/config.yml" > /dev/null << 'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log

    pipeline_stages:
      - match:
          selector: '{job="varlogs"}'
          stages:
            - regex:
                expression: '^(?P<timestamp>\S+\s+\S+)\s+(?P<hostname>\S+)\s+(?P<service>\S+):\s+(?P<message>.*)'
            - timestamp:
                source: timestamp
                format: 'Jan 02 15:04:05'
            - labels:
                service:
                hostname:
EOF
    else
        echo "Creating generic configuration (no destination configured)..."
        sudo tee "$CONFIG_DIR/config.yml" > /dev/null << 'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

# No clients configured - add your destination here
clients: []

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log

    pipeline_stages:
      - match:
          selector: '{job="varlogs"}'
          stages:
            - regex:
                expression: '^(?P<timestamp>\S+\s+\S+)\s+(?P<hostname>\S+)\s+(?P<service>\S+):\s+(?P<message>.*)'
            - timestamp:
                source: timestamp
                format: 'Jan 02 15:04:05'
            - labels:
                service:
                hostname:
EOF
    fi

    sudo chown -R promtail:promtail "$CONFIG_DIR"
    sudo chown -R promtail:promtail "$DATA_DIR"
}

create_systemd_service() {
    echo "Creating systemd service..."

    sudo tee "$SERVICE_DIR/promtail.service" > /dev/null << 'EOF'
[Unit]
Description=Promtail service
After=network.target

[Service]
Type=simple
User=promtail
Group=promtail
ExecStartPre=/bin/bash -c 'if ! id promtail >/dev/null 2>&1; then useradd -r -s /bin/false promtail; fi'
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

install_promtail() {
    # Determine version to install
    if [ -z "$PROMTAIL_VERSION" ]; then
        PROMTAIL_VERSION=$(get_latest_promtail_version)
        echo "Using latest version: v$PROMTAIL_VERSION"
    else
        echo "Using specified version: v$PROMTAIL_VERSION"
    fi

    # Set URL based on version
    PROMTAIL_URL="https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/promtail-linux-amd64.zip"

    installed_version=$(get_installed_promtail_version)

    if [ "$installed_version" != "none" ] && [ "$installed_version" == "$PROMTAIL_VERSION" ]; then
        echo "Promtail is already installed with the requested version (v$installed_version). Skipping installation."
        exit 0
    fi

    if [ "$installed_version" == "none" ]; then
        echo "Promtail is not installed. Proceeding with installation..."
    else
        echo "Updating from v$installed_version to v$PROMTAIL_VERSION..."
    fi

    check_prerequisites
    create_user
    create_directories

    download_and_install "promtail" "$PROMTAIL_URL" "promtail-linux-amd64"

    create_promtail_config
    create_systemd_service

    echo "Promtail installation completed successfully!"
    echo ""

    if [ "$AUTO_START" = true ]; then
        echo "Starting Promtail service..."
        sudo systemctl daemon-reload
        sudo systemctl enable promtail
        sudo systemctl start promtail
        echo "Service started. Checking status..."
        sudo systemctl status promtail --no-pager
    else
        echo "To start the service:"
        echo "  sudo systemctl daemon-reload"
        echo "  sudo systemctl enable promtail"
        echo "  sudo systemctl start promtail"
        echo ""
        echo "Or use: $0 install --start"
    fi
    echo ""
    echo "To check status:"
    echo "  sudo systemctl status promtail"
    echo ""
    echo "Promtail will be available at: http://localhost:9080"
    echo ""
    if [ "$ENABLE_LOKI_CONFIG" = true ]; then
        echo "Configuration:"
        echo "  - Config file: /etc/promtail/config.yml"
        echo "  - Configured for Loki: http://localhost:3100"
        echo "  - Modify config to change Loki URL or add authentication"
    else
        echo "Configuration:"
        echo "  - Config file: /etc/promtail/config.yml"
        echo "  - No destination configured (clients: [])"
        echo "  - Add your destination in the config file"
        echo "  - Supports: Loki, Elasticsearch, InfluxDB, Kafka, HTTP endpoints"
    fi
}

uninstall_promtail() {
    echo "Uninstalling Promtail..."

    # Stop and disable service
    sudo systemctl stop promtail 2>/dev/null || true
    sudo systemctl disable promtail 2>/dev/null || true

    # Remove binary
    sudo rm -f "$INSTALL_DIR/promtail"

    # Remove configuration and data
    if [ "$FORCE_UNINSTALL" = true ]; then
        echo "Force mode: Removing all configuration files and data..."
        sudo rm -rf "$CONFIG_DIR"
        sudo rm -rf "$DATA_DIR"
        sudo rm -f "$SERVICE_DIR/promtail.service"
        sudo systemctl daemon-reload
    else
        read -p "Remove configuration files and data? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo rm -rf "$CONFIG_DIR"
            sudo rm -rf "$DATA_DIR"
            sudo rm -f "$SERVICE_DIR/promtail.service"
            sudo systemctl daemon-reload
        fi
    fi

    # Remove user
    if [ "$FORCE_UNINSTALL" = true ]; then
        echo "Force mode: Removing promtail user..."
        sudo userdel promtail 2>/dev/null || true
    else
        read -p "Remove promtail user? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo userdel promtail 2>/dev/null || true
        fi
    fi

    echo "Promtail has been uninstalled."
}

start_service() {
    echo "Starting Promtail service..."

    # Check if service file exists
    if [ ! -f "$SERVICE_DIR/promtail.service" ]; then
        echo "Error: Promtail service file not found at $SERVICE_DIR/promtail.service"
        echo "Please run 'sudo $0 install' first to install Promtail and create the service."
        exit 1
    fi

    # Check if binary exists
    if [ ! -f "$INSTALL_DIR/promtail" ]; then
        echo "Error: Promtail binary not found at $INSTALL_DIR/promtail"
        echo "Please run 'sudo $0 install' first to install Promtail."
        exit 1
    fi

    sudo systemctl daemon-reload
    sudo systemctl enable promtail
    sudo systemctl start promtail

    echo "Service started. Checking status..."
    sudo systemctl status promtail --no-pager
}

stop_service() {
    echo "Stopping Promtail service..."

    # Check if service file exists
    if [ ! -f "$SERVICE_DIR/promtail.service" ]; then
        echo "Error: Promtail service file not found at $SERVICE_DIR/promtail.service"
        echo "Please run 'sudo $0 install' first to install Promtail and create the service."
        exit 1
    fi

    sudo systemctl stop promtail
    echo "Service stopped."
}

status_service() {
    echo "Promtail service status:"

    # Check if service file exists
    if [ ! -f "$SERVICE_DIR/promtail.service" ]; then
        echo "Error: Promtail service file not found at $SERVICE_DIR/promtail.service"
        echo "Please run 'sudo $0 install' first to install Promtail and create the service."
        exit 1
    fi

    sudo systemctl status promtail --no-pager
}

usage() {
    echo "Usage: $0 [install|uninstall|start|stop|status] [--version VERSION] [--loki] [--start] [--force]"
    echo ""
    echo "Commands:"
    echo "  install   - Install Promtail (latest version by default)"
    echo "  uninstall - Remove Promtail"
    echo "  start     - Start Promtail service"
    echo "  stop      - Stop Promtail service"
    echo "  status    - Show service status"
    echo ""
    echo "Options:"
    echo "  --version VERSION - Install specific version (e.g., 2.9.0)"
    echo "  --loki           - Enable Loki-compatible configuration (default: false)"
    echo "  --start          - Automatically start service after installation"
    echo "  --force          - Force uninstall without prompts (removes all data)"
    echo ""
    echo "Prerequisites:"
    echo "  - curl, unzip, jq (will be installed automatically)"
    echo ""
    echo "Configuration:"
    echo "  - Without --loki: Generic config with no destination (clients: [])"
    echo "  - With --loki: Pre-configured for Loki at http://localhost:3100"
    echo "  - Edit /etc/promtail/config.yml to customize destination"
    echo ""
    echo "Examples:"
    echo "  $0 install                    # Install with generic config"
    echo "  $0 install --loki            # Install with Loki config"
    echo "  $0 install --start           # Install and start service"
    echo "  $0 install --version 2.9.0   # Install specific version"
    echo "  $0 uninstall --force         # Remove everything without prompts"
    echo "  $0 status                    # Check service status"
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
            PROMTAIL_VERSION="$2"
            shift 2
            ;;
        --loki)
            ENABLE_LOKI_CONFIG=true
            shift
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
    install_promtail
elif [ "$COMMAND" == "install" ]; then
    install_promtail
elif [ "$COMMAND" == "uninstall" ]; then
    uninstall_promtail
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
