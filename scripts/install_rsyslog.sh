#!/bin/bash

set -e

RSYSLOG_CONF="/etc/rsyslog.conf"
CONFIGURE=false

cleanup() {
    rm -f /tmp/rsyslog-install
}
trap cleanup EXIT

get_installed_rsyslog_version() {
    if command -v rsyslogd &>/dev/null; then
        rsyslogd -v | head -n 1 | awk '{print $3}'
    else
        echo "none"
    fi
}

install_dependencies() {
    if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y rsyslog
    elif command -v yum &>/dev/null; then
        sudo yum install -y rsyslog
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y rsyslog
    else
        echo "Unsupported package manager. Exiting."
        exit 1
    fi
}

install_rsyslog() {
    installed_version=$(get_installed_rsyslog_version)

    if [ "$installed_version" != "none" ]; then
        echo "rsyslog is already installed (version: $installed_version)."
        exit 0
    fi

    echo "Installing rsyslog..."
    install_dependencies

    echo "Enabling and starting rsyslog service..."
    sudo systemctl enable rsyslog
    sudo systemctl start rsyslog
    sudo systemctl status rsyslog --no-pager

    echo "rsyslog installed successfully!"

    if [ "$CONFIGURE" == true ]; then
        configure_rsyslog
    fi
}

configure_rsyslog() {
    echo "Configuring rsyslog ..."
    if [ -f "$RSYSLOG_CONF" ]; then
        sudo sed -i '/^*.\*/d' "$RSYSLOG_CONF"
        echo "*.info;mail.none;authpriv.none;cron.none   /var/log/messages" | sudo tee -a "$RSYSLOG_CONF"
    else
        echo "rsyslog configuration file not found. Exiting."
        exit 1
    fi

    echo "Restarting rsyslog service..."
    sudo systemctl restart rsyslog
    echo "rsyslog configured successfully."
}

uninstall_rsyslog() {
    echo "Uninstalling rsyslog..."
    if command -v rsyslogd &>/dev/null; then
        sudo systemctl stop rsyslog
        if command -v apt &>/dev/null; then
            sudo apt remove -y rsyslog
            sudo apt autoremove -y
        elif command -v yum &>/dev/null || command -v dnf &>/dev/null; then
            sudo yum remove -y rsyslog || sudo dnf remove -y rsyslog
        else
            echo "Unsupported package manager. Skipping rsyslog removal."
        fi
        echo "rsyslog has been uninstalled."
    else
        echo "rsyslog is not installed. Nothing to uninstall."
    fi
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
        --configure)
            CONFIGURE=true
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
        esac
    done
}

usage() {
    echo "Usage: $0 [install|uninstall] [--configure]"
    exit 1
}

parse_args "$@"

if [ "$ACTION" == "install" ]; then
    install_rsyslog
elif [ "$ACTION" == "uninstall" ]; then
    uninstall_rsyslog
else
    usage
fi

if [ "$ACTION" != "uninstall" ]; then
    echo "Operation completed. Run 'systemctl status rsyslog' to verify installation."
fi
