#!/bin/bash

set -e

S3_BUCKET_NAME="${S3_BUCKET_NAME:-}"
MOUNT_POINT="${MOUNT_POINT:-/mnt/s3_config}"
MOUNTPOINT_VERSION="${MOUNTPOINT_VERSION:-}"  # Optional: pin version, otherwise uses latest
MOUNT_USER="${MOUNT_USER:-}"  # User to set ownership for mount (required)

cleanup() {
    rm -f /tmp/mount-s3.rpm
}
trap cleanup EXIT

detect_package_manager() {
    if command -v dnf &>/dev/null; then
        PACKAGE_MANAGER="dnf"
    elif command -v yum &>/dev/null; then
        PACKAGE_MANAGER="yum"
    elif command -v apt &>/dev/null || command -v apt-get &>/dev/null; then
        PACKAGE_MANAGER="apt"
    else
        echo "Unsupported package manager. Exiting."
        exit 1
    fi
}

install_dependencies() {
    detect_package_manager
    echo "Detected package manager: $PACKAGE_MANAGER"

    # Check what's missing
    local missing_packages=()

    if ! command -v wget &>/dev/null; then
        missing_packages+=("wget")
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

install_mountpoint() {
    if command -v mount-s3 &>/dev/null; then
        echo "AWS Mountpoint is already installed. Skipping installation."
        echo "Current version: $(mount-s3 --version 2>&1 | head -n 1 || echo 'unknown')"
        exit 0
    fi

    install_dependencies

    echo "Installing AWS Mountpoint for Amazon S3..."
    cd /tmp

    # Detect architecture
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        ARCH="x86_64"
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        ARCH="arm64"
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi

    # Get version (use pinned version if set, otherwise use latest)
    if [ -z "$MOUNTPOINT_VERSION" ]; then
        MOUNTPOINT_URL="https://s3.amazonaws.com/mountpoint-s3-release/latest/${ARCH}/mount-s3.rpm"
        echo "Downloading AWS Mountpoint RPM (latest) from ${MOUNTPOINT_URL}..."
    else
        MOUNTPOINT_URL="https://s3.amazonaws.com/mountpoint-s3-release/releases/${MOUNTPOINT_VERSION}/${ARCH}/mount-s3-${MOUNTPOINT_VERSION}-1.${ARCH}.rpm"
        echo "Downloading AWS Mountpoint RPM (version ${MOUNTPOINT_VERSION}) from ${MOUNTPOINT_URL}..."
    fi

    if wget "${MOUNTPOINT_URL}" -O mount-s3.rpm 2>&1; then
        echo "Download successful. Installing AWS Mountpoint RPM..."
        # Use rpm directly to avoid dnf Python module issues (preferred method)
        if rpm -Uvh mount-s3.rpm 2>&1; then
            echo "AWS Mountpoint installed successfully"
            rm -f mount-s3.rpm
        else
            echo "Warning: rpm install failed, trying with ${PACKAGE_MANAGER}..."
            # Try dnf/yum as fallback
            if sudo ${PACKAGE_MANAGER} install -y ./mount-s3.rpm 2>&1; then
                echo "AWS Mountpoint installed successfully via ${PACKAGE_MANAGER}"
                rm -f mount-s3.rpm
            else
                echo "Error: Failed to install AWS Mountpoint RPM with both rpm and ${PACKAGE_MANAGER}"
                echo "Checking if package is already installed..."
                if rpm -q mountpoint-s3 2>/dev/null; then
                    echo "AWS Mountpoint appears to be already installed"
                    rm -f mount-s3.rpm
                else
                    echo "Error: Failed to install AWS Mountpoint RPM"
                    exit 1
                fi
            fi
        fi
    else
        echo "Error: Failed to download AWS Mountpoint RPM"
        exit 1
    fi

    cd /

    # Verify mount-s3 is installed
    if ! command -v mount-s3 &>/dev/null; then
        echo "Error: Failed to install AWS Mountpoint"
        exit 1
    fi

    echo "Mountpoint version: $(mount-s3 --version 2>&1 || echo 'unknown')"
}

configure_s3_mount() {
    if [ -z "$S3_BUCKET_NAME" ]; then
        echo "Error: S3_BUCKET_NAME is required. Cannot configure S3 mount."
        exit 1
    fi

    if [ -z "$MOUNT_USER" ]; then
        echo "Error: MOUNT_USER is required. Cannot configure S3 mount."
        exit 1
    fi

    echo "Creating mount point ${MOUNT_POINT}..."
    sudo mkdir -p "${MOUNT_POINT}"
    sudo chmod 755 "${MOUNT_POINT}"

    # Get user UID and GID
    if id "$MOUNT_USER" &>/dev/null; then
        MOUNT_UID=$(id -u "$MOUNT_USER")
        MOUNT_GID=$(id -g "$MOUNT_USER")
        echo "${MOUNT_USER} UID: ${MOUNT_UID}, GID: ${MOUNT_GID}"
    else
        echo "Error: User ${MOUNT_USER} not found."
        exit 1
    fi

    # Create systemd service for S3 mount
    echo "Creating systemd service for S3 mount..."
    sudo tee /etc/systemd/system/s3-mount.service > /dev/null <<EOF
[Unit]
Description=Mount S3 bucket to ${MOUNT_POINT}
After=network-online.target
Wants=network-online.target
Before=remote-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/bash -c 'if mountpoint -q ${MOUNT_POINT}; then umount ${MOUNT_POINT} || true; fi'
ExecStart=/usr/bin/mount-s3 --read-only --allow-other --file-mode=0644 --dir-mode=0755 --uid=${MOUNT_UID} --gid=${MOUNT_GID} ${S3_BUCKET_NAME} ${MOUNT_POINT}
ExecStop=/bin/bash -c 'if mountpoint -q ${MOUNT_POINT}; then umount ${MOUNT_POINT}; fi'
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    echo "Systemd service file created"
}

start_s3_mount() {
    if [ ! -f /etc/systemd/system/s3-mount.service ]; then
        echo "Error: S3 mount service file not found. Please run installation first."
        exit 1
    fi

    if ! command -v mount-s3 &>/dev/null; then
        echo "Error: AWS Mountpoint binary not found. Please run installation first."
        exit 1
    fi

    echo "Enabling S3 mount service..."
    sudo systemctl daemon-reload
    sudo systemctl enable s3-mount.service

    echo "Starting S3 mount service..."
    if sudo systemctl start s3-mount.service; then
        echo "S3 mount service started successfully"
        sleep 3
        if mountpoint -q "${MOUNT_POINT}"; then
            echo "S3 bucket ${S3_BUCKET_NAME} is mounted at ${MOUNT_POINT}"
        else
            echo "Warning: Mount point exists but may not be mounted correctly"
            sudo systemctl status s3-mount.service --no-pager -l || true
        fi
    else
        echo "Error: Failed to start S3 mount service"
        sudo systemctl status s3-mount.service --no-pager -l || true
        exit 1
    fi
}

uninstall_s3_mount() {
    if [ ! -f /etc/systemd/system/s3-mount.service ]; then
        echo "S3 mount is not configured. Skipping uninstallation."
        exit 0
    fi

    echo "Uninstalling S3 mount..."

    # Stop and disable the service (Linux only)
    if [[ "$(uname -s)" == "Linux" ]]; then
        if systemctl is-system-running &>/dev/null; then
            sudo systemctl stop s3-mount.service 2>/dev/null || true
            sudo systemctl disable s3-mount.service 2>/dev/null || true
        fi
    fi

    # Unmount if mounted
    if mountpoint -q "${MOUNT_POINT}" 2>/dev/null; then
        sudo umount "${MOUNT_POINT}" 2>/dev/null || true
    fi

    # Remove service file
    sudo rm -f /etc/systemd/system/s3-mount.service

    # Reload systemd
    if [[ "$(uname -s)" == "Linux" ]]; then
        sudo systemctl daemon-reload
    fi

    echo "S3 mount has been uninstalled."
    echo "Note: AWS Mountpoint package is not removed. Use package manager to remove if needed."
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    echo ""
    echo "Required environment variables:"
    echo "  S3_BUCKET_NAME     - Name of the S3 bucket to mount (required for install)"
    echo "  MOUNT_USER         - User to set ownership for mount (required for install)"
    echo ""
    echo "Optional environment variables:"
    echo "  MOUNT_POINT        - Mount point directory (default: /mnt/s3_config)"
    echo "  MOUNTPOINT_VERSION - Pin specific version or leave empty for latest"
    echo ""
    echo "Examples:"
    echo "  S3_BUCKET_NAME=my-bucket MOUNT_USER=ec2-user $0 install"
    echo "  S3_BUCKET_NAME=my-bucket MOUNT_POINT=/mnt/my-s3 MOUNT_USER=ubuntu $0 install"
    echo "  MOUNT_POINT=/mnt/s3_config $0 uninstall"
    exit 1
}

if [ "$#" -eq 0 ]; then
    if [ -z "$S3_BUCKET_NAME" ] || [ -z "$MOUNT_USER" ]; then
        echo "Error: S3_BUCKET_NAME and MOUNT_USER are required."
        usage
    fi
    install_mountpoint
    configure_s3_mount
    start_s3_mount
elif [ "$1" == "install" ]; then
    if [ -z "$S3_BUCKET_NAME" ] || [ -z "$MOUNT_USER" ]; then
        echo "Error: S3_BUCKET_NAME and MOUNT_USER are required."
        usage
    fi
    install_mountpoint
    configure_s3_mount
    start_s3_mount
elif [ "$1" == "uninstall" ]; then
    uninstall_s3_mount
else
    usage
fi

if [ "$1" != "uninstall" ]; then
    echo ""
    echo "S3 mount installation completed successfully."
    echo "S3 bucket ${S3_BUCKET_NAME} is mounted at ${MOUNT_POINT} (read-only)"
    echo "Run 'mountpoint ${MOUNT_POINT}' to verify the mount."
fi
