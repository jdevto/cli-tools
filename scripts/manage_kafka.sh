#!/bin/bash

set -e

KAFKA_DIR="/opt/kafka"
DEFAULT_CLIENT_PROPERTIES_FILE="$KAFKA_DIR/iam-auth-client.properties"

usage() {
    echo "Usage: $0 <category> <action> [options]"
    echo "Categories and Actions:"
    echo "  topic     - Manage Kafka topics (create, delete, describe, list)"
    echo "  message   - Produce or consume messages"
    echo "  consumer  - Manage consumer groups (describe-group, reset-offsets)"
    echo ""
    echo "Options:"
    echo "  -c   CLUSTER_ARN         (Required) AWS ARN for MSK Cluster"
    echo "  -t   TOPIC_NAME          (Required for topic/message operations, except 'list')"
    echo "  -g   GROUP_ID            (Required for consumer operations)"
    echo "  -f   CLIENT_PROPERTIES   (Optional) Path to client properties file (default: $DEFAULT_CLIENT_PROPERTIES_FILE)"
    echo ""
    echo "Examples:"
    echo "  $0 topic create -c CLUSTER_ARN -t TOPIC_NAME"
    echo "  $0 message produce -c CLUSTER_ARN -t TOPIC_NAME"
    echo "  $0 consumer describe-group -c CLUSTER_ARN -g GROUP_ID"
    exit 1
}

# Ensure at least two arguments (CATEGORY and ACTION)
if [[ $# -lt 2 ]]; then
    usage
fi

CATEGORY=$1
ACTION=$2
shift 2

declare -A VALID_ACTIONS=(
    ["topic"]="create delete describe list"
    ["message"]="produce consume"
    ["consumer"]="describe-group reset-offsets"
)

if [[ -z "${VALID_ACTIONS[$CATEGORY]}" || ! " ${VALID_ACTIONS[$CATEGORY]} " =~ " $ACTION " ]]; then
    echo "Error: Invalid category ($CATEGORY) or action ($ACTION)."
    usage
fi

CLIENT_PROPERTIES_FILE="$DEFAULT_CLIENT_PROPERTIES_FILE"

while getopts "c:t:g:f:" opt; do
    case ${opt} in
    c) CLUSTER_ARN="$OPTARG" ;;
    t) TOPIC_NAME="$OPTARG" ;;
    g) GROUP_ID="$OPTARG" ;;
    f) CLIENT_PROPERTIES_FILE="$OPTARG" ;;
    *) usage ;;
    esac
done

CLIENT_PROPERTIES_FILE="${CLIENT_PROPERTIES_FILE:-$DEFAULT_CLIENT_PROPERTIES_FILE}"

if [[ -z "$CLUSTER_ARN" ]]; then
    echo "Error: Missing required argument -c CLUSTER_ARN"
    usage
fi

if [[ "$CATEGORY" == "topic" && "$ACTION" != "list" && -z "$TOPIC_NAME" ]]; then
    echo "Error: Missing required argument -t TOPIC_NAME for topic operations (except 'list')."
    usage
fi

if [[ "$CATEGORY" == "message" && -z "$TOPIC_NAME" ]]; then
    echo "Error: Missing required argument -t TOPIC_NAME for message operations."
    usage
fi

if [[ "$CATEGORY" == "consumer" && -z "$GROUP_ID" ]]; then
    echo "Error: Missing required argument -g GROUP_ID for consumer operations."
    usage
fi

if ! command -v aws &>/dev/null; then
    echo "Error: AWS CLI is not installed. Install it first."
    exit 1
fi

if [[ ! -x "$KAFKA_DIR/bin/kafka-topics.sh" ]]; then
    echo "Error: Kafka is not installed. Install it first."
    exit 1
fi

if [[ ! -f "$CLIENT_PROPERTIES_FILE" ]]; then
    echo "Error: Missing client properties file ($CLIENT_PROPERTIES_FILE)."
    exit 1
fi

for i in {1..3}; do
    BS=$(aws kafka get-bootstrap-brokers --cluster-arn "$CLUSTER_ARN" --query "BootstrapBrokerStringSaslIam" --output text) && break
    echo "Retrying to fetch bootstrap brokers ($i/3)..."
    sleep 2
done

if [[ -z "$BS" || "$BS" == "None" ]]; then
    echo "Error: Failed to retrieve bootstrap brokers for cluster $CLUSTER_ARN."
    exit 1
fi

echo "Bootstrap Brokers: $BS"

manage_topic() {
    case "$ACTION" in
    create)
        echo "Creating Kafka topic: $TOPIC_NAME"
        "$KAFKA_DIR/bin/kafka-topics.sh" --bootstrap-server "$BS" --command-config "$CLIENT_PROPERTIES_FILE" --create --topic "$TOPIC_NAME"
        ;;
    delete)
        echo "Deleting Kafka topic: $TOPIC_NAME"
        "$KAFKA_DIR/bin/kafka-topics.sh" --bootstrap-server "$BS" --command-config "$CLIENT_PROPERTIES_FILE" --delete --topic "$TOPIC_NAME"
        ;;
    describe)
        echo "Describing Kafka topic: $TOPIC_NAME"
        "$KAFKA_DIR/bin/kafka-topics.sh" --bootstrap-server "$BS" --command-config "$CLIENT_PROPERTIES_FILE" --describe --topic "$TOPIC_NAME"
        ;;
    list)
        echo "Listing all Kafka topics..."
        "$KAFKA_DIR/bin/kafka-topics.sh" --bootstrap-server "$BS" --command-config "$CLIENT_PROPERTIES_FILE" --list
        ;;
    esac
}

manage_message() {
    case "$ACTION" in
    produce)
        echo "Producing a test message to topic: $TOPIC_NAME"
        echo "Test message from script" | "$KAFKA_DIR/bin/kafka-console-producer.sh" --bootstrap-server "$BS" --producer.config "$CLIENT_PROPERTIES_FILE" --topic "$TOPIC_NAME"
        ;;
    consume)
        echo "Consuming messages from topic: $TOPIC_NAME"
        "$KAFKA_DIR/bin/kafka-console-consumer.sh" --bootstrap-server "$BS" --consumer.config "$CLIENT_PROPERTIES_FILE" --topic "$TOPIC_NAME" --from-beginning
        ;;
    esac
}

manage_consumer() {
    case "$ACTION" in
    describe-group)
        echo "Describing Kafka consumer group: $GROUP_ID"
        "$KAFKA_DIR/bin/kafka-consumer-groups.sh" --bootstrap-server "$BS" --command-config "$CLIENT_PROPERTIES_FILE" --group "$GROUP_ID" --describe
        ;;
    reset-offsets)
        echo "Resetting offsets for consumer group: $GROUP_ID"
        "$KAFKA_DIR/bin/kafka-consumer-groups.sh" --bootstrap-server "$BS" --command-config "$CLIENT_PROPERTIES_FILE" --group "$GROUP_ID" --reset-offsets --to-earliest --execute
        ;;
    esac
}

case "$CATEGORY" in
topic) manage_topic ;;
message) manage_message ;;
consumer) manage_consumer ;;
esac
