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

get_latest_version() {
    echo "Fetching the latest AWS MSK IAM Auth version..."
    latest_version=$(curl -s "$MSK_AUTH_URL" | jq -r .tag_name)

    if [ -z "$latest_version" ] || [ "$latest_version" == "null" ]; then
        echo "Failed to fetch the latest version. Exiting."
        exit 1
    fi
    echo "Latest version: $latest_version"
}

install_msk_iam_auth() {
    install_kafka
    get_latest_version

    if [ ! -d "$LIBS_DIR" ]; then
        mkdir -p "$LIBS_DIR"
    fi

    JAR_FILE="$LIBS_DIR/aws-msk-iam-auth-$latest_version-all.jar"
    JAR_URL="https://github.com/aws/aws-msk-iam-auth/releases/download/$latest_version/aws-msk-iam-auth-$latest_version-all.jar"

    if [ -f "$JAR_FILE" ]; then
        echo "AWS MSK IAM Auth JAR is already up-to-date."
    else
        echo "Downloading AWS MSK IAM Auth JAR (version $latest_version)..."
        sudo curl -L -o "$JAR_FILE" "$JAR_URL"
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
        CURRENT_LOG_LEVEL=$(grep -Eo "INFO|WARN|ERROR|DEBUG" "$TOOLS_LOG4J_CONFIG" | head -1)

        if [ "$ENABLE_DEBUG_LOGS" = true ]; then
            if [ "$CURRENT_LOG_LEVEL" != "DEBUG" ]; then
                sed -i.bak "s/$CURRENT_LOG_LEVEL/DEBUG/g" "$TOOLS_LOG4J_CONFIG"
                echo "Log level changed from $CURRENT_LOG_LEVEL to DEBUG."
            else
                echo "Log level is already set to DEBUG. No changes needed."
            fi
        else
            if grep -q "DEBUG" "$TOOLS_LOG4J_CONFIG"; then
                sed -i.bak "s/DEBUG/$CURRENT_LOG_LEVEL/g" "$TOOLS_LOG4J_CONFIG"
                echo "Log level reset to $CURRENT_LOG_LEVEL."
            else
                echo "Log level remains unchanged ($CURRENT_LOG_LEVEL)."
            fi
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

    if [ -f "$TOOLS_LOG4J_CONFIG.bak" ]; then
        sudo rm -f "$TOOLS_LOG4J_CONFIG.bak"
        echo "Kafka log configuration backup removed."
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
    install)
        ACTION="install"
        shift
        ;;
    uninstall)
        ACTION="uninstall"
        shift
        ;;
    --enable-debug-logs)
        ENABLE_DEBUG_LOGS=true
        shift
        ;;
    *)
        usage
        ;;
    esac
done

if [ -z "$ACTION" ]; then
    install_msk_iam_auth
elif [ "$ACTION" == "install" ]; then
    install_msk_iam_auth
elif [ "$ACTION" == "uninstall" ]; then
    uninstall_msk_iam_auth
else
    usage
fi

if [ "$ACTION" != "uninstall" ]; then
    echo "Operation completed. Verify with: ls $LIBS_DIR/"
fi
