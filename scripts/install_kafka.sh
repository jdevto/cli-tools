#!/bin/bash

set -e

KAFKA_INSTALL_DIR="/opt/kafka"
TMP_DIR="/tmp"
SCALA_VERSION="2.13"
SET_PERMISSIONS=false
CHOSEN_USER="$(whoami)"

cleanup() {
    rm -rf "$TMP_DIR/kafka.tgz"
}
trap cleanup EXIT

get_latest_kafka_version() {
    curl -s "https://dlcdn.apache.org/kafka/" | grep -oP '>\K[0-9]+\.[0-9]+\.[0-9]+(?=/<)' | sort -V | tail -1
}

get_installed_kafka_version() {
    if [ -d "$KAFKA_INSTALL_DIR" ]; then
        "$KAFKA_INSTALL_DIR/bin/kafka-topics.sh" --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+'
    else
        echo "none"
    fi
}

install_dependencies() {
    REQUIRED_PACKAGES=("curl" "tar")

    if command -v apt &>/dev/null; then
        sudo apt update
        for package in "${REQUIRED_PACKAGES[@]}"; do
            if ! dpkg -l | grep -q "^ii  $package "; then
                echo "Installing missing package: $package"
                sudo apt install -y "$package"
            else
                echo "Package $package is already installed."
            fi
        done

    elif command -v dnf &>/dev/null; then
        for package in "${REQUIRED_PACKAGES[@]}"; do
            if ! rpm -q "$package" &>/dev/null; then
                echo "Installing missing package: $package"
                sudo dnf install -y "$package" --allowerasing
            else
                echo "Package $package is already installed."
            fi
        done
    else
        echo "Unsupported package manager. Exiting."
        exit 1
    fi
}

install_kafka() {
    installed_version=$(get_installed_kafka_version)
    latest_version=$(get_latest_kafka_version)

    if [ -z "$latest_version" ]; then
        echo "Failed to fetch the latest Kafka version. Exiting."
        exit 1
    fi

    if [ "$installed_version" != "none" ] && [ "$installed_version" == "$latest_version" ]; then
        echo "Kafka is already up-to-date ($installed_version). Skipping installation."
        exit 0
    fi

    if [ "$installed_version" == "none" ]; then
        echo "Kafka is not installed. Proceeding with installation..."
    else
        echo "New Kafka version available ($latest_version). Updating..."
        sudo rm -rf "$KAFKA_INSTALL_DIR"
    fi

    install_dependencies

    KAFKA_TGZ="kafka_${SCALA_VERSION}-${latest_version}.tgz"
    KAFKA_URL="https://dlcdn.apache.org/kafka/${latest_version}/${KAFKA_TGZ}"

    curl -fsSL "$KAFKA_URL" -o "$TMP_DIR/kafka.tgz"

    if [ ! -f "$TMP_DIR/kafka.tgz" ]; then
        echo "Failed to download Kafka. Check if the version exists at $KAFKA_URL"
        exit 1
    fi

    tar -xvzf "$TMP_DIR/kafka.tgz" -C /opt
    mv "/opt/kafka_${SCALA_VERSION}-${latest_version}" "$KAFKA_INSTALL_DIR"

    if [ "$SET_PERMISSIONS" = true ]; then
        sudo chown -R "$CHOSEN_USER":"$CHOSEN_USER" "$KAFKA_INSTALL_DIR"
        echo "Permissions set for $CHOSEN_USER."
    fi

    echo "Kafka installed successfully: $latest_version"
}

uninstall_kafka() {
    echo "Uninstalling Kafka..."
    if [ -d "$KAFKA_INSTALL_DIR" ]; then
        sudo rm -rf "$KAFKA_INSTALL_DIR"
        echo "Kafka has been uninstalled."
    else
        echo "Kafka is not installed. Nothing to uninstall."
    fi
}

usage() {
    echo "Usage: $0 [install|uninstall] [--set-permissions [username]]"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    install)
        ACTION="install"
        shift
        ;;
    uninstall)
        ACTION="uninstall"
        shift
        ;;
    --set-permissions)
        SET_PERMISSIONS=true
        if [[ -n "$2" && "$2" != "--"* ]]; then
            CHOSEN_USER="$2"
            shift
        fi
        shift
        ;;
    *)
        usage
        ;;
    esac
done

if [ -z "$ACTION" ]; then
    install_kafka
elif [ "$ACTION" == "install" ]; then
    install_kafka
elif [ "$ACTION" == "uninstall" ]; then
    uninstall_kafka
else
    usage
fi

if [ "$ACTION" != "uninstall" ]; then
    echo "Operation completed. Run '$KAFKA_INSTALL_DIR/bin/kafka-topics.sh --version' to verify installation."
fi
