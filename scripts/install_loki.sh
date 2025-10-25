#!/bin/bash

set -e

# Default to latest version, can be overridden with --version flag
LOKI_VERSION=""
AUTO_START=false
FORCE_UNINSTALL=false
TMP_DIR="/tmp/loki-install"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/loki"
DATA_DIR="/var/lib/loki"
SERVICE_DIR="/etc/systemd/system"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

get_latest_loki_version() {
    curl -s "https://api.github.com/repos/grafana/loki/releases/latest" | jq -r '.tag_name' | sed 's/^v//'
}

get_installed_loki_version() {
    if command -v loki &>/dev/null; then
        loki --version 2>&1 | grep -oP 'version \K[0-9]+\.[0-9]+\.[0-9]+' | head -1
    else
        echo "none"
    fi
}

install_dependencies() {
    echo "Installing dependencies..."

    # Check what's missing
    local missing_packages=()

    if ! command -v unzip &>/dev/null; then
        missing_packages+=("unzip")
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
    if ! id loki &>/dev/null; then
        echo "Creating loki user..."
        if ! sudo useradd -r -s /bin/false loki; then
            echo "Warning: Failed to create loki user. Continuing with installation..."
        fi
    else
        echo "Loki user already exists."
    fi
}

create_directories() {
    echo "Creating directories..."
    if ! sudo mkdir -p "$CONFIG_DIR"; then
        echo "Error: Failed to create config directory $CONFIG_DIR"
        exit 1
    fi
    if ! sudo mkdir -p "$DATA_DIR"/{chunks,rules}; then
        echo "Error: Failed to create data directory $DATA_DIR"
        exit 1
    fi
    echo "Directories created successfully"
}

download_and_install() {
    local component=$1
    local url=$2
    local binary_name=$3

    echo "Downloading $component..."
    echo "URL: $url"
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"
    echo "Working in: $(pwd)"

    curl -fsSL "$url" -o "${component}.zip"

    if [ ! -f "${component}.zip" ]; then
        echo "Failed to download $component from $url"
        exit 1
    fi

    echo "Downloaded ${component}.zip successfully"
    unzip -q "${component}.zip"
    echo "Extracted archive contents:"
    ls -la

    if [ ! -f "$binary_name" ]; then
        echo "Binary $binary_name not found in archive. Available files:"
        ls -la
        exit 1
    fi

    echo "Installing $component..."
    sudo mv "$binary_name" "$INSTALL_DIR/$component"
    sudo chmod +x "$INSTALL_DIR/$component"

    echo "$component installed successfully: $($INSTALL_DIR/$component --version 2>&1 | head -1)"
}

create_loki_config() {
    echo "Creating Loki configuration..."

    # Use Loki's default configuration as a base
    echo "Downloading default Loki configuration..."
    curl -s "https://raw.githubusercontent.com/grafana/loki/main/cmd/loki/loki-local-config.yaml" -o "$TMP_DIR/loki-default.yaml"

    if [ -f "$TMP_DIR/loki-default.yaml" ]; then
        echo "Using Loki's default configuration with minimal modifications..."
        # Copy the default config and make minimal changes
        cp "$TMP_DIR/loki-default.yaml" "$TMP_DIR/loki-custom.yaml"

        # Update paths to match our installation
        sed -i 's|/tmp/loki|/var/lib/loki|g' "$TMP_DIR/loki-custom.yaml"
        sed -i 's|/tmp/loki/chunks|/var/lib/loki/chunks|g' "$TMP_DIR/loki-custom.yaml"
        sed -i 's|/tmp/loki/rules|/var/lib/loki/rules|g' "$TMP_DIR/loki-custom.yaml"

        # Copy the modified config
        sudo cp "$TMP_DIR/loki-custom.yaml" "$CONFIG_DIR/loki.yml"
    else
        echo "Failed to download default config, using minimal configuration..."
        # Fallback to a minimal working config
        sudo tee "$CONFIG_DIR/loki.yml" > /dev/null << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /var/lib/loki
  storage:
    filesystem:
      chunks_directory: /var/lib/loki/chunks
      rules_directory: /var/lib/loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  max_cache_freshness_per_query: 10m
  split_queries_by_interval: 15m
  max_query_parallelism: 32
  max_streams_per_user: 0
  max_line_size: 256000
  ingestion_rate_mb: 16
  ingestion_burst_size_mb: 32

analytics:
  reporting_enabled: false
EOF
    fi

    sudo chown -R loki:loki "$CONFIG_DIR"
    sudo chown -R loki:loki "$DATA_DIR"
}

create_systemd_service() {
    echo "Creating systemd service..."

    sudo tee "$SERVICE_DIR/loki.service" > /dev/null << 'EOF'
[Unit]
Description=Loki service
After=network.target

[Service]
Type=simple
User=loki
Group=loki
ExecStartPre=/bin/bash -c 'if ! id loki >/dev/null 2>&1; then useradd -r -s /bin/false loki; fi'
ExecStart=/usr/local/bin/loki -config.file=/etc/loki/loki.yml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

install_loki() {
    # Determine version to install
    if [ -z "$LOKI_VERSION" ]; then
        LOKI_VERSION=$(get_latest_loki_version)
        echo "Using latest version: v$LOKI_VERSION"
    else
        echo "Using specified version: v$LOKI_VERSION"
    fi

    # Set URL based on version
    LOKI_URL="https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip"

    installed_version=$(get_installed_loki_version)

    if [ "$installed_version" != "none" ] && [ "$installed_version" == "$LOKI_VERSION" ]; then
        echo "Loki is already installed with the requested version (v$installed_version). Skipping installation."
        exit 0
    fi

    if [ "$installed_version" == "none" ]; then
        echo "Loki is not installed. Proceeding with installation..."
    else
        echo "Updating from v$installed_version to v$LOKI_VERSION..."
    fi

    install_dependencies
    create_user
    create_directories

    download_and_install "loki" "$LOKI_URL" "loki-linux-amd64"

    create_loki_config
    create_systemd_service

    # Verify installation
    if [ ! -f "$INSTALL_DIR/loki" ]; then
        echo "Error: Loki binary installation failed"
        exit 1
    fi

    if [ ! -f "$SERVICE_DIR/loki.service" ]; then
        echo "Error: Loki service file creation failed"
        exit 1
    fi

    if [ ! -f "$CONFIG_DIR/loki.yml" ]; then
        echo "Error: Loki configuration file creation failed"
        exit 1
    fi

    echo "Loki installation completed successfully!"
    echo ""

    if [ "$AUTO_START" = true ]; then
        echo "Starting Loki service..."
        sudo systemctl daemon-reload
        sudo systemctl enable loki
        sudo systemctl start loki
        echo "Service started. Checking status..."
        sudo systemctl status loki --no-pager
    else
        echo "To start the service:"
        echo "  sudo systemctl daemon-reload"
        echo "  sudo systemctl enable loki"
        echo "  sudo systemctl start loki"
        echo ""
        echo "Or use: $0 install --start"
    fi
    echo ""
    echo "To check status:"
    echo "  sudo systemctl status loki"
    echo ""
    echo "Loki will be available at: http://localhost:3100"
}

uninstall_loki() {
    echo "Uninstalling Loki..."

    # Stop and disable service
    sudo systemctl stop loki 2>/dev/null || true
    sudo systemctl disable loki 2>/dev/null || true

    # Remove binary
    sudo rm -f "$INSTALL_DIR/loki"

    # Remove configuration and data
    if [ "$FORCE_UNINSTALL" = true ]; then
        echo "Force mode: Removing all configuration files and data..."
        sudo rm -rf "$CONFIG_DIR"
        sudo rm -rf "$DATA_DIR"
        sudo rm -f "$SERVICE_DIR/loki.service"
        sudo systemctl daemon-reload
    else
        read -p "Remove configuration files and data? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo rm -rf "$CONFIG_DIR"
            sudo rm -rf "$DATA_DIR"
            sudo rm -f "$SERVICE_DIR/loki.service"
            sudo systemctl daemon-reload
        fi
    fi

    # Remove user
    if [ "$FORCE_UNINSTALL" = true ]; then
        echo "Force mode: Removing loki user..."
        sudo userdel loki 2>/dev/null || true
    else
        read -p "Remove loki user? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo userdel loki 2>/dev/null || true
        fi
    fi

    echo "Loki has been uninstalled."
}

start_service() {
    echo "Starting Loki service..."

    # Check if service file exists
    if [ ! -f "$SERVICE_DIR/loki.service" ]; then
        echo "Error: Loki service file not found at $SERVICE_DIR/loki.service"
        echo "Please run 'sudo $0 install' first to install Loki and create the service."
        exit 1
    fi

    # Check if binary exists
    if [ ! -f "$INSTALL_DIR/loki" ]; then
        echo "Error: Loki binary not found at $INSTALL_DIR/loki"
        echo "Please run 'sudo $0 install' first to install Loki."
        exit 1
    fi

    sudo systemctl daemon-reload
    sudo systemctl enable loki
    sudo systemctl start loki

    echo "Service started. Checking status..."
    sudo systemctl status loki --no-pager
}

stop_service() {
    echo "Stopping Loki service..."

    # Check if service file exists
    if [ ! -f "$SERVICE_DIR/loki.service" ]; then
        echo "Error: Loki service file not found at $SERVICE_DIR/loki.service"
        echo "Please run 'sudo $0 install' first to install Loki and create the service."
        exit 1
    fi

    sudo systemctl stop loki
    echo "Service stopped."
}

status_service() {
    echo "Loki service status:"

    # Check if service file exists
    if [ ! -f "$SERVICE_DIR/loki.service" ]; then
        echo "Error: Loki service file not found at $SERVICE_DIR/loki.service"
        echo "Please run 'sudo $0 install' first to install Loki and create the service."
        exit 1
    fi

    sudo systemctl status loki --no-pager
}

usage() {
    echo "Usage: $0 [install|uninstall|start|stop|status] [--version VERSION] [--start] [--force]"
    echo ""
    echo "Commands:"
    echo "  install   - Install Loki (latest version by default)"
    echo "  uninstall - Remove Loki"
    echo "  start     - Start Loki service"
    echo "  stop      - Stop Loki service"
    echo "  status    - Show service status"
    echo ""
    echo "Options:"
    echo "  --version VERSION - Install specific version (e.g., 2.9.0)"
    echo "  --start          - Automatically start service after installation"
    echo "  --force          - Force uninstall without prompts (removes all data)"
    echo ""
    echo "Examples:"
    echo "  $0 install                    # Install latest version"
    echo "  $0 install --version 2.9.0   # Install specific version"
    echo "  $0 install --start           # Install and start service"
    echo "  $0 uninstall --force         # Remove everything without prompts"
    echo "  $0 status                    # Check service status"
    echo ""
    echo "Note: Loki is a log aggregation system."
    echo "Configure log shippers to send logs to http://localhost:3100"
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
            LOKI_VERSION="$2"
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
    install_loki
elif [ "$COMMAND" == "install" ]; then
    install_loki
elif [ "$COMMAND" == "uninstall" ]; then
    uninstall_loki
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
