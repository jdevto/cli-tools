#!/bin/bash

set -e

# Default AWS Region (Can be overridden by CLI args or env var)
AWS_REGION="${AWS_REGION:-ap-southeast-2}"
CONFIG_FILE_INPUT=""
CONFIGURE=false
ACTION=""

# CloudWatch Agent package
CLOUDWATCH_AGENT_PACKAGE="amazon-cloudwatch-agent"
DEFAULT_CONFIG_FILE="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"

cleanup() {
    rm -f /tmp/amazon-cloudwatch-agent.rpm /tmp/amazon-cloudwatch-agent.deb
}
trap cleanup EXIT

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

detect_instance_id() {
    if curl -s --connect-timeout 2 http://169.254.169.254/latest/api/token >/dev/null 2>&1; then
        TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
        INSTANCE_ID=$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/instance-id")
    elif curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/instance-id >/dev/null 2>&1; then
        INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    else
        INSTANCE_ID=$(hostname)
    fi

    if [ -z "$INSTANCE_ID" ]; then
        INSTANCE_ID="fallback-instance-id"
    fi

    echo "$INSTANCE_ID"
}

parse_args() {
    if [[ "$#" -eq 0 ]]; then
        echo "Error: No action specified. Use 'install' or 'uninstall'."
        usage
    fi

    ACTION="$1"
    shift

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --configure)
            CONFIGURE=true
            shift
            ;;
        --config)
            CONFIG_FILE_INPUT="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
        esac
    done
}

is_cloudwatch_agent_installed() {
    if command -v amazon-cloudwatch-agent &>/dev/null; then
        return 0 # Installed
    elif command -v rpm &>/dev/null && rpm -q amazon-cloudwatch-agent &>/dev/null; then
        return 0 # Installed via RPM (Amazon Linux, CentOS, RHEL)
    elif command -v dpkg &>/dev/null && dpkg -l | grep -q amazon-cloudwatch-agent; then
        return 0 # Installed via DEB (Ubuntu)
    else
        return 1 # Not installed
    fi
}

configure_cloudwatch_agent() {
    CONFIG_FILE="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"

    INSTANCE_ID=$(detect_instance_id)
    echo "Configuring CloudWatch Unified Agent for region $AWS_REGION..."
    echo "Using instance identifier: $INSTANCE_ID"
    echo "Writing configuration to $CONFIG_FILE"

    tee "$CONFIG_FILE" >/dev/null <<EOF
{
    "agent": {
        "metrics_collection_interval": 60,
        "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log",
        "region": "$AWS_REGION"
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "/var/log/messages",
                        "log_stream_name": "$INSTANCE_ID"
                    }
                ]
            }
        }
    }
}
EOF

    echo "Setting correct permissions..."
    chown root:root "$CONFIG_FILE"
    chmod 644 "$CONFIG_FILE"

    echo "Cleaning up old CloudWatch Agent configurations..."
    CONFIG_DIR="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d"
    if [ -d "$CONFIG_DIR" ]; then
        if [ -f "$CONFIG_DIR/default" ]; then
            echo "Removing old default config..."
            rm -f "$CONFIG_DIR/default"
        fi
    fi

    echo "Applying CloudWatch Unified Agent configuration..."
    amazon-cloudwatch-agent-ctl -a stop
    amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:$CONFIG_FILE -s
    systemctl restart amazon-cloudwatch-agent
}

install_amazon_linux() {
    echo "Using AWS Region: $AWS_REGION"

    if is_cloudwatch_agent_installed; then
        echo "CloudWatch Unified Agent is already installed. Skipping installation."
        return
    fi

    echo "Installing CloudWatch Unified Agent on Amazon Linux..."
    yum install -y "$CLOUDWATCH_AGENT_PACKAGE"

    configure_cloudwatch_agent
    echo "CloudWatch Unified Agent installed and configured for region $AWS_REGION."
}

install_ubuntu_centos_rhel() {
    echo "Using AWS Region: $AWS_REGION"

    if is_cloudwatch_agent_installed; then
        echo "CloudWatch Unified Agent is already installed. Skipping installation."
        return
    fi

    echo "Installing CloudWatch Unified Agent..."
    if command -v apt &>/dev/null; then
        apt update && apt install -y amazon-cloudwatch-agent
    elif command -v yum &>/dev/null; then
        yum install -y amazon-cloudwatch-agent
    elif command -v dnf &>/dev/null; then
        dnf install -y amazon-cloudwatch-agent
    else
        echo "Unsupported package manager. Exiting."
        exit 1
    fi

    configure_cloudwatch_agent
    echo "CloudWatch Unified Agent installed and configured for region $AWS_REGION."
}

uninstall_cloudwatch_agent() {
    if ! is_cloudwatch_agent_installed; then
        echo "CloudWatch Unified Agent is not installed. Skipping uninstallation."
        return
    fi

    echo "Uninstalling CloudWatch Unified Agent..."
    systemctl stop amazon-cloudwatch-agent || true
    systemctl disable amazon-cloudwatch-agent || true

    if command -v apt &>/dev/null; then
        apt remove -y amazon-cloudwatch-agent
    elif command -v yum &>/dev/null || command -v dnf &>/dev/null; then
        yum remove -y amazon-cloudwatch-agent || dnf remove -y amazon-cloudwatch-agent
    elif command -v rpm &>/dev/null && rpm -q amazon-cloudwatch-agent &>/dev/null; then
        rpm -e amazon-cloudwatch-agent
    else
        echo "Unsupported package manager. Skipping CloudWatch agent removal."
    fi

    echo "CloudWatch Unified Agent has been uninstalled."
}

usage() {
    echo "Usage: $0 [install|uninstall] [--region <AWS_REGION>] [--configure] [--config <file>]"
    exit 1
}

main() {
    OS=$(detect_os)
    case "$OS" in
    amzn | amzn2)
        echo "Detected Amazon Linux. Proceeding with installation..."
        install_amazon_linux
        ;;
    ubuntu | centos | rhel)
        echo "Detected $OS. Proceeding with installation..."
        install_ubuntu_centos_rhel
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
    esac
}

parse_args "$@"

if [ "$ACTION" == "install" ]; then
    main
elif [ "$ACTION" == "uninstall" ]; then
    uninstall_cloudwatch_agent
else
    usage
fi

if [ "$ACTION" != "uninstall" ]; then
    echo "Operation completed. Run 'systemctl status amazon-cloudwatch-agent' to verify installation."
fi
