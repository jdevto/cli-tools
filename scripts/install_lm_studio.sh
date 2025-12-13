#!/bin/bash

set -e

LM_STUDIO_VERSION="${LM_STUDIO_VERSION:-0.3.34-1}"  # Optional: pin version
LM_STUDIO_PORT="${LM_STUDIO_PORT:-1234}"            # Default API port (for CLI/server)
LM_STUDIO_USER="${LM_STUDIO_USER:-}"                # User to run LM Studio as (auto-detected if not set)
TMP_DIR="/tmp/lm-studio-install"

# Decide how to run privileged commands
SUDO="sudo"
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
elif ! command -v sudo >/dev/null 2>&1; then
    echo "sudo not found and you are not root; cannot install packages."
    exit 1
fi

PACKAGE_MANAGER=""
PLATFORM=""
ARCH=""
SERVICE_USER=""
SERVICE_USER_HOME=""

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

detect_platform() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        PLATFORM="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        PLATFORM="darwin"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        PLATFORM="windows"
    else
        echo "Unsupported platform: $OSTYPE"
        exit 1
    fi
}

detect_architecture() {
    local arch=$(uname -m)
    if [ "$arch" = "x86_64" ]; then
        ARCH="x64"
    elif [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then
        ARCH="arm64"
    else
        echo "Unsupported architecture: $arch"
        exit 1
    fi
}

detect_package_manager() {
    if command -v dnf >/dev/null 2>&1; then
        PACKAGE_MANAGER="dnf"
    elif command -v yum >/dev/null 2>&1; then
        PACKAGE_MANAGER="yum"
    elif command -v apt >/dev/null 2>&1 || command -v apt-get >/dev/null 2>&1; then
        if command -v apt >/dev/null 2>&1; then
            PACKAGE_MANAGER="apt"
        else
            PACKAGE_MANAGER="apt-get"
        fi
    else
        echo "Unsupported package manager. Exiting."
        exit 1
    fi
}

detect_user() {
    # Try to detect the current user, fallback to common users if running as root
    if [ -n "$LM_STUDIO_USER" ] && id "$LM_STUDIO_USER" &>/dev/null; then
        SERVICE_USER="$LM_STUDIO_USER"
    elif [ "$EUID" -eq 0 ]; then
        # Running as root, try to find a non-root user
        if id ec2-user &>/dev/null; then
            SERVICE_USER="ec2-user"
        elif id ubuntu &>/dev/null; then
            SERVICE_USER="ubuntu"
        elif [ -n "$SUDO_USER" ]; then
            SERVICE_USER="$SUDO_USER"
        else
            SERVICE_USER="ec2-user"
        fi
    else
        SERVICE_USER="$(whoami)"
    fi
    SERVICE_USER_HOME=$(eval echo "~$SERVICE_USER")
}

install_dependencies() {
    detect_package_manager
    echo "Detected package manager: $PACKAGE_MANAGER"

    # Check what's missing
    local missing_packages=()

    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        missing_packages+=("wget")
    fi

    # Note: We install GUI dependencies for AppImage bootstrap, but check individually
    # The AppImage bundles many libraries, so some may not be strictly required
    case "$PACKAGE_MANAGER" in
        dnf)
            if ! command -v Xvfb >/dev/null 2>&1; then
                missing_packages+=("xorg-x11-server-Xvfb")
            fi
            if ! rpm -q fuse >/dev/null 2>&1; then
                missing_packages+=("fuse" "fuse-libs")
            fi
            ;;
        yum)
            if ! command -v Xvfb >/dev/null 2>&1; then
                missing_packages+=("xorg-x11-server-Xvfb")
            fi
            if ! rpm -q fuse >/dev/null 2>&1; then
                missing_packages+=("fuse")
            fi
            ;;
        apt|apt-get)
            if ! command -v Xvfb >/dev/null 2>&1; then
                missing_packages+=("xvfb")
            fi
            if ! dpkg -l | grep -q "^ii.*libfuse2"; then
                missing_packages+=("libfuse2")
            fi
            ;;
    esac

    if [ ${#missing_packages[@]} -eq 0 ]; then
        echo "All dependencies are already installed."
        return 0
    fi

    echo "Installing missing packages: ${missing_packages[*]}"

    case "$PACKAGE_MANAGER" in
        dnf)
            $SUDO dnf clean all >/dev/null 2>&1 || true
            $SUDO dnf makecache >/dev/null 2>&1 || true
            # Install GUI dependencies needed for AppImage bootstrap
            $SUDO dnf install -y "${missing_packages[@]}" \
                xdg-utils atk at-spi2-atk gtk3 nss cups-libs \
                libXScrnSaver gdk-pixbuf2 alsa-lib nodejs npm 2>/dev/null || {
                echo "Warning: Failed to install some dependencies with dnf."
                echo "The AppImage bundles many libraries, so it may still work."
            }
            ;;
        yum)
            $SUDO yum install -y "${missing_packages[@]}" \
                xdg-utils atk at-spi2-atk gtk3 nss cups-libs \
                libXScrnSaver gdk-pixbuf2 alsa-lib nodejs npm 2>/dev/null || {
                echo "Warning: Failed to install some dependencies with yum."
            }
            ;;
        apt|apt-get)
            $SUDO $PACKAGE_MANAGER update >/dev/null 2>&1 || true
            $SUDO $PACKAGE_MANAGER install -y "${missing_packages[@]}" \
                xdg-utils libatk1.0-0 libatk-bridge2.0-0 libgtk-3-0 \
                libnss3 libcups2 libxss1 libgdk-pixbuf2.0-0 libasound2 \
                nodejs npm 2>/dev/null || true
            ;;
    esac

    echo "Dependencies installed (needed for AppImage bootstrap)"
}

install_lm_studio() {
    detect_platform
    detect_architecture
    detect_user
    install_dependencies

    if [ "$PLATFORM" != "linux" ]; then
        echo "Error: LM Studio AppImage is only available for Linux"
        exit 1
    fi

    local appimage_path="/opt/lm-studio/LM-Studio-${LM_STUDIO_VERSION}-${ARCH}.AppImage"

    if [ -f "$appimage_path" ]; then
        echo "LM Studio is already installed. Skipping installation."
        echo "Installed version: ${LM_STUDIO_VERSION}, arch: ${ARCH}"
        return 0
    fi

    echo "Installing LM Studio (headless mode)..."

    $SUDO mkdir -p /opt/lm-studio
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"

    echo "Downloading LM Studio AppImage (this is a large file ~1GB, may take several minutes)..."
    APPIMAGE_URL="https://installers.lmstudio.ai/linux/${ARCH}/${LM_STUDIO_VERSION}/LM-Studio-${LM_STUDIO_VERSION}-${ARCH}.AppImage"
    APPIMAGE_FILE="LM-Studio-${LM_STUDIO_VERSION}-${ARCH}.AppImage"

    echo "Download URL: $APPIMAGE_URL"

    # Don't remove partial download - allow resume
    if [ -f "$APPIMAGE_FILE" ]; then
        echo "Found existing partial download, will resume..."
        ls -lh "$APPIMAGE_FILE"
    fi

    if command -v wget &>/dev/null; then
        echo "Using wget to download (this may take a few minutes, file is ~1GB)..."
        # Use --continue for resume, --timeout for longer timeout, --tries for retries
        # --progress=bar shows progress bar, --no-verbose reduces output but keeps progress
        if ! wget --continue --timeout=600 --tries=5 --progress=bar:force:noscroll --no-verbose "$APPIMAGE_URL" -O "$APPIMAGE_FILE"; then
            echo ""
            echo "Error: Failed to download LM Studio AppImage with wget"
            echo "URL: $APPIMAGE_URL"
            if [ -f "$APPIMAGE_FILE" ]; then
                echo "Partial download found:"
                ls -lh "$APPIMAGE_FILE"
                echo "You can retry the script to resume the download"
            fi
            exit 1
        fi
    elif command -v curl &>/dev/null; then
        echo "Using curl to download (this may take a few minutes, file is ~1GB)..."
        # Use -C - for resume, --max-time for timeout, --retry for retries
        if ! curl -fL --progress-bar --max-time 600 --retry 3 -C - "$APPIMAGE_URL" -o "$APPIMAGE_FILE"; then
            echo "Error: Failed to download LM Studio AppImage with curl"
            echo "URL: $APPIMAGE_URL"
            if [ -f "$APPIMAGE_FILE" ]; then
                echo "Partial download found, checking size..."
                ls -lh "$APPIMAGE_FILE"
                echo "You can retry the script to resume the download"
            fi
            exit 1
        fi
    else
        echo "Error: Neither wget nor curl is available"
        exit 1
    fi

    if [ ! -f "$APPIMAGE_FILE" ]; then
        echo "Error: AppImage file was not downloaded"
        exit 1
    fi

    # Verify file size is reasonable (should be around 1GB)
    FILE_SIZE=$(stat -f%z "$APPIMAGE_FILE" 2>/dev/null || stat -c%s "$APPIMAGE_FILE" 2>/dev/null || echo "0")
    MIN_SIZE=$((100 * 1024 * 1024))  # At least 100MB

    if [ "$FILE_SIZE" -lt "$MIN_SIZE" ]; then
        echo "Error: Downloaded file seems too small ($(numfmt --to=iec-i --suffix=B $FILE_SIZE 2>/dev/null || echo "${FILE_SIZE} bytes"))"
        echo "Expected at least 100MB. The download may have failed."
        rm -f "$APPIMAGE_FILE"
        exit 1
    fi

    echo "Downloaded successfully: $(ls -lh "$APPIMAGE_FILE" | awk '{print $5}')"
    chmod +x "$APPIMAGE_FILE"

    $SUDO mv "$APPIMAGE_FILE" "$appimage_path"
    $SUDO chown root:root "$appimage_path"

    # Symlink that can be used to run AppImage manually
    $SUDO ln -sf "$appimage_path" /usr/local/bin/lm-studio

    echo "LM Studio AppImage installed successfully"

    # Bootstrap CLI if it doesn't exist (it gets installed when AppImage runs for the first time)
    if [ ! -f "$SERVICE_USER_HOME/.lmstudio/bin/lms" ]; then
        echo "Bootstrapping LM Studio CLI (running AppImage briefly to install CLI)..."
        echo "This may take 10-30 seconds..."

        # Start Xvfb in background for AppImage to use
        echo "Starting Xvfb on display :99..."
        $SUDO -u "$SERVICE_USER" Xvfb :99 -screen 0 1024x768x16 -ac -nolisten tcp >/dev/null 2>&1 &
        XVFB_PID=$!
        sleep 3  # Give Xvfb more time to start

        # Verify Xvfb is running
        if ! kill -0 $XVFB_PID 2>/dev/null; then
            echo "Error: Failed to start Xvfb"
            return 1
        fi

        # Check if display is accessible
        if ! $SUDO -u "$SERVICE_USER" DISPLAY=:99 xdpyinfo >/dev/null 2>&1; then
            echo "Warning: Xvfb display :99 may not be ready, but continuing..."
        fi

        echo "Running AppImage to bootstrap CLI..."
        # Run AppImage as the service user with Xvfb display, timeout after 30 seconds
        # Redirect stderr to see any errors, but don't fail on non-zero exit
        $SUDO -u "$SERVICE_USER" env DISPLAY=:99 timeout 30 "$appimage_path" --no-sandbox >/tmp/lmstudio-bootstrap.log 2>&1 &
        BOOTSTRAP_PID=$!

        # Wait for CLI to appear (check every 2 seconds, max 30 seconds)
        local wait_count=0
        while [ $wait_count -lt 15 ] && [ ! -f "$SERVICE_USER_HOME/.lmstudio/bin/lms" ]; do
            sleep 2
            wait_count=$((wait_count + 1))
            # Check if process is still running
            if ! kill -0 $BOOTSTRAP_PID 2>/dev/null; then
                # Process exited, check if CLI was created
                if [ -f "$SERVICE_USER_HOME/.lmstudio/bin/lms" ]; then
                    break
                fi
                # Check exit code from log
                if [ -f /tmp/lmstudio-bootstrap.log ]; then
                    echo "AppImage exited. Checking logs..."
                    tail -20 /tmp/lmstudio-bootstrap.log 2>/dev/null || true
                fi
                break
            fi
        done

        # Kill the AppImage process if still running
        kill $BOOTSTRAP_PID 2>/dev/null || true
        wait $BOOTSTRAP_PID 2>/dev/null || true

        # Kill Xvfb
        kill $XVFB_PID 2>/dev/null || true
        wait $XVFB_PID 2>/dev/null || true

        # Clean up log file
        rm -f /tmp/lmstudio-bootstrap.log

        if [ -f "$SERVICE_USER_HOME/.lmstudio/bin/lms" ]; then
            echo "CLI bootstrapped successfully at $SERVICE_USER_HOME/.lmstudio/bin/lms"
        else
            echo "Error: CLI bootstrap failed. CLI not found at $SERVICE_USER_HOME/.lmstudio/bin/lms"
            echo ""
            echo "The AppImage may need to be run interactively to install the CLI."
            echo "Try running manually:"
            echo "  sudo -u $SERVICE_USER DISPLAY=:99 /usr/local/bin/lm-studio --no-sandbox"
            echo "Then stop it after a few seconds once the CLI is installed."
            return 1
        fi
    fi

    # Copy CLI to global location if it exists in user home
    if [ -f "$SERVICE_USER_HOME/.lmstudio/bin/lms" ]; then
        echo "Installing CLI globally to /usr/local/bin/lms..."
        $SUDO cp "$SERVICE_USER_HOME/.lmstudio/bin/lms" /usr/local/bin/lms
        $SUDO chmod +x /usr/local/bin/lms
        echo "CLI installed globally at /usr/local/bin/lms"
    fi
}

create_systemd_service() {
    echo "Creating systemd service for LM Studio..."

    detect_user
    detect_architecture

    # Prefer global CLI, fallback to user CLI
    if [ -f "/usr/local/bin/lms" ]; then
        LMS_CLI="/usr/local/bin/lms"
    elif [ -f "$SERVICE_USER_HOME/.lmstudio/bin/lms" ]; then
        LMS_CLI="$SERVICE_USER_HOME/.lmstudio/bin/lms"
        echo "Note: Using user CLI. Copying to global location..."
        $SUDO cp "$LMS_CLI" /usr/local/bin/lms
        $SUDO chmod +x /usr/local/bin/lms
        LMS_CLI="/usr/local/bin/lms"
    else
        echo "Error: LM Studio CLI not found at /usr/local/bin/lms or $SERVICE_USER_HOME/.lmstudio/bin/lms"
        echo "The CLI should have been bootstrapped during installation."
        echo "Please re-run the install script."
        exit 1
    fi

    # Create wrapper script to start Xvfb and AppImage, then start server
    local appimage_path="/opt/lm-studio/LM-Studio-${LM_STUDIO_VERSION}-${ARCH}.AppImage"

    $SUDO tee /usr/local/bin/lm-studio-service.sh > /dev/null <<WRAPPER_EOF
#!/bin/bash
# Wrapper script to start LM Studio AppImage in service mode

set -e

SERVICE_USER_HOME="$SERVICE_USER_HOME"
APPIMAGE_PATH="$appimage_path"
LMS_CLI="$LMS_CLI"
PORT="${LM_STUDIO_PORT}"

# Start Xvfb in background
Xvfb :99 -screen 0 1024x768x16 -ac -nolisten tcp >/dev/null 2>&1 &
XVFB_PID=\$!
sleep 3

# Verify Xvfb is running
if ! kill -0 \$XVFB_PID 2>/dev/null; then
    echo "Error: Failed to start Xvfb"
    exit 1
fi

export DISPLAY=:99

# Start AppImage in service mode (this will run in background)
"\$APPIMAGE_PATH" --no-sandbox --run-as-service >/dev/null 2>&1 &
APPIMAGE_PID=\$!

# Wait for AppImage to be ready
echo "Waiting for LM Studio AppImage to start..."
sleep 10

# Verify AppImage is running
if ! kill -0 \$APPIMAGE_PID 2>/dev/null; then
    echo "Error: AppImage failed to start"
    kill \$XVFB_PID 2>/dev/null || true
    exit 1
fi

# Start the API server using CLI
echo "Starting LM Studio API server on port \$PORT..."
"$LMS_CLI" server start --port "\$PORT"

# Keep script running (monitor AppImage process)
wait \$APPIMAGE_PID
EXIT_CODE=\$?

# Cleanup
kill \$XVFB_PID 2>/dev/null || true
exit \$EXIT_CODE
WRAPPER_EOF

    $SUDO chmod +x /usr/local/bin/lm-studio-service.sh

    $SUDO tee /etc/systemd/system/lm-studio.service > /dev/null <<EOF
[Unit]
Description=LM Studio API Server
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
Environment="HOME=$SERVICE_USER_HOME"
Environment="DISPLAY=:99"
Environment="LM_STUDIO_PORT=${LM_STUDIO_PORT}"
Environment="PATH=/usr/local/bin:/usr/bin:/bin:$SERVICE_USER_HOME/.lmstudio/bin"
WorkingDirectory=$SERVICE_USER_HOME
ExecStart=/usr/local/bin/lm-studio-service.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    $SUDO systemctl daemon-reload
    $SUDO systemctl enable lm-studio.service

    echo "Systemd service created and enabled"
    echo "Service user: $SERVICE_USER"
    echo "CLI path: $LMS_CLI"
    echo "To start the service: sudo systemctl start lm-studio"
    echo "To check status: sudo systemctl status lm-studio"
    echo "To view logs: sudo journalctl -u lm-studio -f"
}

start_service() {
    echo "Starting LM Studio service..."

    detect_architecture

    # Check if service file exists
    if [ ! -f "/etc/systemd/system/lm-studio.service" ]; then
        echo "Error: LM Studio service file not found at /etc/systemd/system/lm-studio.service"
        echo "Please run 'sudo $0 install' first to install LM Studio and create the service."
        exit 1
    fi

    # Check if binary exists
    local appimage_path="/opt/lm-studio/LM-Studio-${LM_STUDIO_VERSION}-${ARCH}.AppImage"
    if [ ! -f "$appimage_path" ]; then
        echo "Error: LM Studio AppImage not found at $appimage_path"
        echo "Please run 'sudo $0 install' first to install LM Studio."
        exit 1
    fi

    $SUDO systemctl daemon-reload
    $SUDO systemctl enable lm-studio.service
    $SUDO systemctl start lm-studio.service

    echo "Service started. Checking status..."
    $SUDO systemctl status lm-studio --no-pager
}

stop_service() {
    echo "Stopping LM Studio service..."

    # Check if service file exists
    if [ ! -f "/etc/systemd/system/lm-studio.service" ]; then
        echo "Error: LM Studio service file not found at /etc/systemd/system/lm-studio.service"
        echo "Please run 'sudo $0 install' first to install LM Studio and create the service."
        exit 1
    fi

    $SUDO systemctl stop lm-studio.service
    echo "Service stopped."
}

status_service() {
    echo "LM Studio service status:"

    # Check if service file exists
    if [ ! -f "/etc/systemd/system/lm-studio.service" ]; then
        echo "Error: LM Studio service file not found at /etc/systemd/system/lm-studio.service"
        echo "Please run 'sudo $0 install' first to install LM Studio and create the service."
        exit 1
    fi

    $SUDO systemctl status lm-studio --no-pager
}

uninstall_lm_studio() {
    echo "Uninstalling LM Studio..."

    # Try to extract user from service file before removing it
    local service_user=""
    if [ -f "/etc/systemd/system/lm-studio.service" ]; then
        service_user=$(grep "^User=" /etc/systemd/system/lm-studio.service 2>/dev/null | cut -d'=' -f2 || echo "")
    fi

    # Stop and disable service
    if systemctl list-units --full --all 2>/dev/null | grep -q "lm-studio.service"; then
        echo "Stopping and disabling lm-studio.service..."
        $SUDO systemctl stop lm-studio.service 2>/dev/null || true
        $SUDO systemctl disable lm-studio.service 2>/dev/null || true
        $SUDO systemctl reset-failed lm-studio.service 2>/dev/null || true
    fi

    # Remove service file
    echo "Removing systemd service file..."
    $SUDO rm -f /etc/systemd/system/lm-studio.service
    $SUDO systemctl daemon-reload
    $SUDO systemctl reset-failed 2>/dev/null || true

    # Remove AppImage and symlinks
    echo "Removing AppImage and binaries..."
    $SUDO rm -rf /opt/lm-studio
    $SUDO rm -f /usr/local/bin/lm-studio
    $SUDO rm -f /usr/local/bin/lms
    $SUDO rm -f /usr/local/bin/lm-studio-service.sh

    # Remove user CLI if it exists (detect user from service or current user)
    if [ -z "$service_user" ]; then
        detect_user
        service_user="$SERVICE_USER"
    fi

    if [ -n "$service_user" ]; then
        local service_user_home
        service_user_home=$(eval echo "~$service_user")
        # Remove entire LM Studio user directory (includes CLI, config, models, etc.)
        if [ -d "$service_user_home/.lmstudio" ]; then
            echo "Removing LM Studio user data directory ($service_user_home/.lmstudio)..."
            rm -rf "$service_user_home/.lmstudio"
        fi
    fi

    # Also check for any temporary AppImage mount points that might be left behind
    echo "Cleaning up any temporary AppImage mount points..."
    $SUDO find /tmp -maxdepth 1 -type d -name ".mount_LM-Studio*" -exec rm -rf {} + 2>/dev/null || true

    # Verify service is completely removed
    if systemctl list-units --full --all 2>/dev/null | grep -q "lm-studio.service"; then
        echo "Warning: Service still appears in systemd. Forcing removal..."
        $SUDO systemctl reset-failed lm-studio.service 2>/dev/null || true
        $SUDO systemctl daemon-reload
    fi

    # Final verification
    if [ -f "/etc/systemd/system/lm-studio.service" ]; then
        echo "Error: Service file still exists at /etc/systemd/system/lm-studio.service"
        echo "Please remove it manually: sudo rm -f /etc/systemd/system/lm-studio.service"
    else
        echo "Service file removed successfully"
    fi

    echo ""
    echo "LM Studio has been completely uninstalled."
    echo ""
    echo "Removed:"
    echo "  ✓ Systemd service (/etc/systemd/system/lm-studio.service)"
    echo "  ✓ Service wrapper script (/usr/local/bin/lm-studio-service.sh)"
    echo "  ✓ AppImage directory (/opt/lm-studio)"
    echo "  ✓ Global binaries (/usr/local/bin/lm-studio, /usr/local/bin/lms)"
    if [ -n "$service_user" ]; then
        echo "  ✓ User data directory (~$service_user/.lmstudio)"
    fi
    echo "  ✓ Temporary AppImage mount points (/tmp/.mount_LM-Studio*)"
    echo ""
    echo "Note: System packages (fuse, xvfb, gtk3, etc.) were not removed."
    echo "      If you want to remove them, do so manually with your package manager."
}

usage() {
    echo "Usage: $0 [install|uninstall|start|stop|status]"
    echo ""
    echo "Commands:"
    echo "  install   - Install LM Studio"
    echo "  uninstall - Remove LM Studio"
    echo "  start     - Start LM Studio service"
    echo "  stop      - Stop LM Studio service"
    echo "  status    - Show service status"
    echo ""
    echo "Optional environment variables:"
    echo "  LM_STUDIO_VERSION  - Pin specific version (default: 0.3.34-1)"
    echo "  LM_STUDIO_PORT     - API server port (default: 1234)"
    echo "  LM_STUDIO_USER     - User to run service as (auto-detected if not set)"
    echo ""
    echo "Examples:"
    echo "  $0 install"
    echo "  LM_STUDIO_VERSION=0.3.34-1 $0 install"
    echo "  LM_STUDIO_PORT=8080 $0 install"
    echo "  $0 start"
    echo "  $0 status"
    echo "  $0 uninstall"
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
    install_lm_studio
    create_systemd_service
    echo ""
    echo "LM Studio installation completed successfully."
    echo ""
    echo "Next steps:"
    echo "1. Start the service: sudo systemctl start lm-studio"
    echo "2. The API server will start automatically on port ${LM_STUDIO_PORT}"
    echo "3. The API will be available at http://localhost:${LM_STUDIO_PORT}/v1"
    echo ""
    echo "Note: You may need to download a model first using: lms get <model-name>"
elif [ "$COMMAND" == "install" ]; then
    install_lm_studio
    create_systemd_service
    echo ""
    echo "LM Studio installation completed successfully."
    echo ""
    echo "Next steps:"
    echo "1. Start the service: sudo systemctl start lm-studio"
    echo "2. The API server will start automatically on port ${LM_STUDIO_PORT}"
    echo "3. The API will be available at http://localhost:${LM_STUDIO_PORT}/v1"
    echo ""
    echo "Note: You may need to download a model first using: lms get <model-name>"
elif [ "$COMMAND" == "uninstall" ]; then
    uninstall_lm_studio
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
    echo ""
    echo "Operation completed. Run '$0 status' to check service status."
fi
