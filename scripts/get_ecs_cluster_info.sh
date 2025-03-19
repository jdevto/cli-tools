#!/bin/bash

set -e  # Exit on error

usage() {
  echo "Usage: $0 [CLUSTER_NAME]"
  echo ""
  echo "If CLUSTER_NAME is provided, the script retrieves ECS metrics for that specific cluster."
  echo "If no CLUSTER_NAME is provided, it lists all ECS clusters and retrieves metrics for each one."
  echo ""
  echo "Metrics retrieved:"
  echo "  - Total, used, and available CPU"
  echo "  - CPU utilization percentage"
  echo "  - Total, used, and available memory"
  echo "  - Memory utilization percentage"
  echo "  - Running, stopped/failed, and pending tasks"
  echo "  - ECS capacity providers"
  echo ""
  echo "Example:"
  echo "  $0 my-cluster"
  echo "  $0   # Fetches metrics for all clusters"
  exit 1
}

# Function to calculate sum of a resource type (CPU or MEMORY)
sum_resource() {
  local CLUSTER_NAME="$1"
  local RESOURCE_NAME="$2"
  local INSTANCE_ARNS
  INSTANCE_ARNS=$(aws ecs list-container-instances --cluster "$CLUSTER_NAME" --query "containerInstanceArns[]" --output text)

  if [[ -z "$INSTANCE_ARNS" ]]; then
    echo "0"
    return
  fi

  aws ecs describe-container-instances --cluster "$CLUSTER_NAME" --container-instances $INSTANCE_ARNS \
    --query "containerInstances[].registeredResources[?name=='$RESOURCE_NAME'].integerValue" --output text | \
    awk '{sum += $1} END {print sum}'
}

# Function to calculate remaining resources (CPU or MEMORY)
remaining_resource() {
  local CLUSTER_NAME="$1"
  local RESOURCE_NAME="$2"
  local INSTANCE_ARNS
  INSTANCE_ARNS=$(aws ecs list-container-instances --cluster "$CLUSTER_NAME" --query "containerInstanceArns[]" --output text)

  if [[ -z "$INSTANCE_ARNS" ]]; then
    echo "0"
    return
  fi

  aws ecs describe-container-instances --cluster "$CLUSTER_NAME" --container-instances $INSTANCE_ARNS \
    --query "containerInstances[].remainingResources[?name=='$RESOURCE_NAME'].integerValue" --output text | \
    awk '{sum += $1} END {print sum}'
}

# Function to calculate utilization percentages
calculate_utilization() {
  local USED=$1
  local TOTAL=$2
  if [[ "$TOTAL" -gt 0 ]]; then
    awk "BEGIN {printf \"%.2f\", ($USED / $TOTAL) * 100}"
  else
    echo "0.00"
  fi
}

# Function to process an ECS cluster
process_cluster() {
  local CLUSTER_NAME="$1"

  echo "Processing ECS Cluster: $CLUSTER_NAME"

  # Get total and remaining CPU
  TOTAL_CPU=$(sum_resource "$CLUSTER_NAME" "CPU")
  REMAINING_CPU=$(remaining_resource "$CLUSTER_NAME" "CPU")
  USED_CPU=$((TOTAL_CPU - REMAINING_CPU))

  # Get total and remaining Memory
  TOTAL_MEMORY=$(sum_resource "$CLUSTER_NAME" "MEMORY")
  REMAINING_MEMORY=$(remaining_resource "$CLUSTER_NAME" "MEMORY")
  USED_MEMORY=$((TOTAL_MEMORY - REMAINING_MEMORY))

  CPU_UTILIZATION=$(calculate_utilization "$USED_CPU" "$TOTAL_CPU")
  MEMORY_UTILIZATION=$(calculate_utilization "$USED_MEMORY" "$TOTAL_MEMORY")

  # Get running, stopped, and pending tasks
  RUNNING_TASKS=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --query "taskArns[]" --output text | wc -w)
  FAILED_TASKS=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --desired-status STOPPED --query "taskArns[]" --output text | wc -w)
  PENDING_TASKS=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --desired-status PENDING --query "taskArns[]" --output text | wc -w)

  # Get ECS capacity providers
  CAPACITY_PROVIDERS=$(aws ecs describe-clusters --clusters "$CLUSTER_NAME" --query "clusters[0].capacityProviders" --output json)

  # Output results
  echo "--------------------------"
  echo "CPU Metrics:"
  echo "  Total CPU: $TOTAL_CPU"
  echo "  Used CPU: $USED_CPU"
  echo "  Available CPU: $REMAINING_CPU"
  echo "  CPU Utilization: $CPU_UTILIZATION%"
  echo ""
  echo "Memory Metrics:"
  echo "  Total Memory: ${TOTAL_MEMORY}MB"
  echo "  Used Memory: ${USED_MEMORY}MB"
  echo "  Available Memory: ${REMAINING_MEMORY}MB"
  echo "  Memory Utilization: $MEMORY_UTILIZATION%"
  echo ""
  echo "Running Tasks: $RUNNING_TASKS"
  echo "Stopped/Failed Tasks: $FAILED_TASKS"
  echo "Pending Tasks: $PENDING_TASKS"
  echo ""
  echo "Capacity Providers:"
  echo "$CAPACITY_PROVIDERS"
  echo ""
}

# Main logic
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
fi

if [[ -z "$1" ]]; then
  echo "No cluster name provided. Fetching all ECS clusters..."
  CLUSTERS=$(aws ecs list-clusters --query "clusterArns[]" --output text)

  if [[ -z "$CLUSTERS" ]]; then
    echo "No ECS clusters found."
    exit 1
  fi

  for CLUSTER in $CLUSTERS; do
    process_cluster "$CLUSTER"
  done
else
  process_cluster "$1"
fi
