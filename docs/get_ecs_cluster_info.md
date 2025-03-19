# get_ecs_cluster_info.sh

This script retrieves ECS cluster metrics, including resource usage and task details. It can report on a specific cluster or all available clusters.

## Usage

```bash
./get_ecs_cluster_info.sh [CLUSTER_NAME]
```

- If **CLUSTER_NAME** is provided, the script retrieves metrics for that specific cluster.
- If no **CLUSTER_NAME** is provided, it lists all clusters and gathers metrics for each one.

## Example Usage

Retrieve ECS cluster metrics for a specific cluster:

```bash
./get_ecs_cluster_info.sh my-cluster
```

Retrieve metrics for all ECS clusters:

```bash
./get_ecs_cluster_info.sh
```

## Running Without Cloning

Run the script directly from GitHub:

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/get_ecs_cluster_info.sh)
```

## Metrics Collected

### CPU Metrics

- Total CPU
- Used CPU
- Available CPU
- CPU Utilization (%)

### Memory Metrics

- Total Memory
- Used Memory
- Available Memory
- Memory Utilization (%)

### Task Counts

- Running tasks
- Stopped/failed tasks
- Pending tasks

### Capacity Providers

- Lists ECS capacity providers for each cluster.

## Verification

After execution, verify the retrieved ECS clusters:

```bash
aws ecs list-clusters
```

## Requirements

- AWS CLI installed and configured with appropriate IAM permissions.
- Bash shell environment.

## Supported Operating Systems

- Linux (Ubuntu, Red Hat, Fedora)
- macOS (with AWS CLI installed)

## Error Handling

- If no ECS clusters are found, the script exits with an error message.
- If AWS CLI commands fail, errors are displayed for troubleshooting.
- If an unsupported OS is detected, the script exits with an appropriate message.
