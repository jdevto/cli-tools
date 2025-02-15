# manage-kafka.sh

This script provides an easy-to-use interface for managing Kafka topics, producing and consuming messages, and handling consumer groups in an AWS MSK cluster.

## Usage

```bash
./manage_kafka.sh <category> <action> [options]
```

### Categories & Actions

| Category  | Actions Available |
|-----------|------------------|
| `topic`   | `create`, `delete`, `describe`, `list` |
| `message` | `produce`, `consume` |
| `consumer` | `describe-group`, `reset-offsets` |

## Options

| Option | Description |
|--------|-------------|
| `-c CLUSTER_ARN` | (Required) AWS ARN for MSK Cluster |
| `-t TOPIC_NAME` | (Required for topic/message operations, except `list`) |
| `-g GROUP_ID` | (Required for consumer operations) |
| `-f CLIENT_PROPERTIES` | (Optional) Path to client properties file (default: `/opt/kafka/iam-auth-client.properties`) |

## Example Usage

### Topic Management

To create a Kafka topic:

```bash
./manage_kafka.sh topic create -c CLUSTER_ARN -t my-topic
```

To delete a Kafka topic:

```bash
./manage_kafka.sh topic delete -c CLUSTER_ARN -t my-topic
```

To describe a Kafka topic:

```bash
./manage_kafka.sh topic describe -c CLUSTER_ARN -t my-topic
```

To list all Kafka topics:

```bash
./manage_kafka.sh topic list -c CLUSTER_ARN
```

### Message Operations

To produce a message to a topic:

```bash
./manage_kafka.sh message produce -c CLUSTER_ARN -t my-topic
```

To consume messages from a topic:

```bash
./manage_kafka.sh message consume -c CLUSTER_ARN -t my-topic
```

### Consumer Group Management

To describe a consumer group:

```bash
./manage_kafka.sh consumer describe-group -c CLUSTER_ARN -g my-group
```

To reset offsets for a consumer group:

```bash
./manage_kafka.sh consumer reset-offsets -c CLUSTER_ARN -g my-group
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/manage_kafka.sh) topic list -c CLUSTER_ARN
```

## Verification

To check if Kafka topics exist:

```bash
./manage_kafka.sh topic list -c CLUSTER_ARN
```

To check if messages can be produced and consumed:

```bash
./manage_kafka.sh message produce -c CLUSTER_ARN -t my-topic
./manage_kafka.sh message consume -c CLUSTER_ARN -t my-topic
```

To check consumer group status:

```bash
./manage_kafka.sh consumer describe-group -c CLUSTER_ARN -g my-group
```

To verify offset resets:

```bash
./manage_kafka.sh consumer reset-offsets -c CLUSTER_ARN -g my-group
```

## Prerequisites

1. **AWS CLI Installed** - Ensure that AWS CLI is installed and configured.
2. **Kafka CLI Installed** - Kafka binaries should be available under `/opt/kafka/bin/`.
3. **Client Properties File** - The IAM authentication client properties file should exist (`/opt/kafka/iam-auth-client.properties`).

## Error Handling

- If required arguments are missing, the script exits with an error message.
- If Kafka or AWS CLI is not installed, the script warns the user.
- If bootstrap brokers retrieval fails, the script retries up to 3 times.

## Cleanup

- If the script is uninstalled, all authentication files and log configurations will be removed.
- The script ensures that temporary files and logs are managed properly.
