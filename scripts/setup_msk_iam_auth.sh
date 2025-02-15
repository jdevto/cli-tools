#!/bin/bash

set -e

KAFKA_INSTALL_SCRIPT="https://raw.githubusercontent.com/jdevto/cli-tools/refs/heads/main/scripts/install_kafka.sh"
MSK_AUTH_URL="https://api.github.com/repos/aws/aws-msk-iam-auth/releases/latest"
KAFKA_DIR="/opt/kafka"
LIBS_DIR="$KAFKA_DIR/libs"
CLIENT_PROPERTIES_FILE="$KAFKA_DIR/iam-auth-client.properties"
TOOLS_LOG4J_CONFIG="$KAFKA_DIR/config/tools-log4j.properties"

ENABLE_DEBUG_LOGS=false

install_kafka() {
    if [ ! -d "$KAFKA_DIR" ]; then
        echo "Kafka not found. Installing..."
        curl -fsSL "$KAFKA_INSTALL_SCRIPT" | bash
    else
        echo "Kafka is already installed."
    fi
}

get_latest_version_and_url() {
    echo "Fetching the latest AWS MSK IAM Auth version..."
    response=$(curl -s "$MSK_AUTH_URL")

    jar_url=$(echo "$response" | jq -r '.assets[] | select(.name | test("aws-msk-iam-auth-.*-all.jar$")) | .browser_download_url')

    if [[ -z "$jar_url" || "$jar_url" == "null" ]]; then
        echo "Failed to fetch the latest JAR URL. Exiting."
        exit 1
    fi

    echo "JAR URL: $jar_url"
}

install_msk_iam_auth() {
    install_kafka
    get_latest_version_and_url

    if [ ! -d "$LIBS_DIR" ]; then
        mkdir -p "$LIBS_DIR"
    fi

    JAR_FILE="$LIBS_DIR/$(basename "$jar_url")"

    if [ -f "$JAR_FILE" ]; then
        echo "AWS MSK IAM Auth JAR is already up-to-date."
    else
        echo "Downloading AWS MSK IAM Auth JAR..."
        sudo curl -L -o "$JAR_FILE" "$jar_url"
        echo "JAR installed successfully: $JAR_FILE"
    fi

    if [ ! -f "$CLIENT_PROPERTIES_FILE" ]; then
        echo "Creating IAM authentication configuration..."
        cat >"$CLIENT_PROPERTIES_FILE" <<EOF
security.protocol=SASL_SSL
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required awsDebugCreds=true;
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
EOF
        echo "IAM authentication properties configured."
    else
        echo "IAM authentication properties file already exists. Skipping creation."
    fi

    if [ -f "$TOOLS_LOG4J_CONFIG" ]; then
        if [ "$ENABLE_DEBUG_LOGS" = true ]; then
            sed -i -E \
                -e "s/^(.+)INFO(.+)$/\1DEBUG\2/" \
                -e "s/^(.+)WARN(.+)$/\1DEBUG\2/" \
                -e "s/^(.+)ERROR(.+)$/\1DEBUG\2/" \
                "$TOOLS_LOG4J_CONFIG"
            echo "Log level changed to DEBUG."
        else
            sed -i -E \
                -e "s/^(.+)DEBUG(.+)INFO/\1INFO\2/" \
                -e "s/^(.+)DEBUG(.+)WARN/\1WARN\2/" \
                -e "s/^(.+)DEBUG(.+)ERROR/\1ERROR\2/" \
                "$TOOLS_LOG4J_CONFIG"
            echo "Log level restored to default."
        fi
    else
        echo "Warning: Kafka log4j configuration file not found. Skipping log level update."
    fi

    echo "AWS MSK IAM authentication setup completed successfully!"
}

uninstall_msk_iam_auth() {
    echo "Uninstalling AWS MSK IAM authentication..."
    if ls "$LIBS_DIR/aws-msk-iam-auth-"*"-all.jar" 1>/dev/null 2>&1; then
        sudo rm -rf "$LIBS_DIR/aws-msk-iam-auth-*.jar"
        echo "AWS MSK IAM authentication JAR removed."
    else
        echo "No AWS MSK IAM authentication JAR found. Skipping removal."
    fi

    if [ -f "$CLIENT_PROPERTIES_FILE" ]; then
        sudo rm -f "$CLIENT_PROPERTIES_FILE"
        echo "IAM authentication properties removed."
    else
        echo "IAM authentication properties file does not exist. Skipping removal."
    fi
}

usage() {
    echo "Usage: $0 [install|uninstall] [--enable-debug-logs]"
    echo "  --enable-debug-logs   Modify Kafka log level to DEBUG."
    exit 1
}

ACTION=""
while [[ $# -gt 0 ]]; do
    case "$1" in
    install) ACTION="install" ;;
    uninstall) ACTION="uninstall" ;;
    --enable-debug-logs) ENABLE_DEBUG_LOGS=true ;;
    *) usage ;;
    esac
    shift
done

case "$ACTION" in
install) install_msk_iam_auth ;;
uninstall) uninstall_msk_iam_auth ;;
*) usage ;;
esac

if [ "$ACTION" != "uninstall" ]; then
    echo "Operation completed. Verify with: ls $LIBS_DIR/"
fi
