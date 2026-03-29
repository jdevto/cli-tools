# cli-tools

Command-line interface tools/scripts

## Table of Contents

- [install_aws_cli.sh](docs/install_aws_cli.md)
- [install_aws_vault.sh](docs/install_aws_vault.md)
- [bwsm_secret.sh](docs/bwsm_secret.md)
- [install_cloudwatch_agent.sh](docs/install_cloudwatch_agent.md)
- [install_codedeploy_agent.sh](docs/install_codedeploy_agent.md)
- [install_glab.sh](docs/install_glab.md)
- [install_goaccess.sh](docs/install_goaccess.md)
- [install_grafana.sh](docs/install_grafana.md)
- [install_k9s.sh](docs/install_k9s.md)
- [install_kafka.sh](docs/install_kafka.md)
- [install_kustomize.sh](docs/install_kustomize.md)
- [install_kubectl.sh](docs/install_kubectl.md)
- [install_lm_studio.sh](docs/install_lm_studio.md)
- [install_loki.sh](docs/install_loki.md)
- [install_promtail.sh](docs/install_promtail.md)
- [install_python.sh](docs/install_python.md)
- [install_s3_mount.sh](docs/install_s3_mount.md)
- [install_sam.sh](docs/install_sam.md)
- [install_ssm_agent.sh](docs/install_ssm_agent.md)
- [install_ssm_plugin.sh](docs/install_ssm_plugin.md)
- [install_terraform.sh](docs/install_terraform.md)
- [install_tfenv.sh](docs/install_tfenv.md)
- [install_uv.sh](docs/install_uv.md)
- [install_vscode_server.sh](docs/install_vscode_server.md)
- [manage_kafka.sh](docs/manage_kafka.md)
- [setup_msk_iam_auth.sh](docs/setup_msk_iam_auth.md)
- [sync_github_repos.sh](docs/sync_github_repos.md)
- [get_discord_events.py](docs/get_discord_events.md)
- [get_twitch_schedule.py](docs/get_twitch_schedule.md)
- [get_youtube_upcoming.py](docs/get_youtube_upcoming.md)

## Overview

This repository provides various command-line tools to streamline workflows.

Each script has its own documentation available in the `docs/` directory.

Refer to the respective files for detailed usage instructions:

- **[install_aws_cli.sh](docs/install_aws_cli.md)**: Install or uninstall the AWS CLI on supported Linux distributions.
- **[install_aws_vault.sh](docs/install_aws_vault.md)**: Manage AWS Vault installation and configuration.
- **[bwsm_secret.sh](docs/bwsm_secret.md)**: Manage secrets in Bitwarden Secrets Manager (get, create, update, delete, list) with automatic prerequisite handling.
- **[install_cloudwatch_agent.sh](docs/install_cloudwatch_agent.md)**: Install or uninstall the AWS CloudWatch Unified Agent.
- **[install_codedeploy_agent.sh](docs/install_codedeploy_agent.md)**: Install or uninstall the AWS CodeDeploy agent.
- **[install_glab.sh](docs/install_glab.md)**: Install or uninstall the GitLab CLI (`glab`) from official [GitLab releases](https://gitlab.com/gitlab-org/cli/-/releases) (Linux/macOS).
- **[install_goaccess.sh](docs/install_goaccess.md)**: Install or uninstall GoAccess (real-time log analyzer) from the official source; version aligned with [goaccess.io/download](https://goaccess.io/download).
- **[install_grafana.sh](docs/install_grafana.md)**: Install or uninstall Grafana web-based analytics and monitoring platform.
- **[install_k9s.sh](docs/install_k9s.md)**: Install or uninstall k9s, a terminal UI for Kubernetes, on Linux and macOS.
- **[install_kafka.sh](docs/install_kafka.md)**: Install or uninstall Apache Kafka on a Linux system.
- **[install_kustomize.sh](docs/install_kustomize.md)**: Install or uninstall Kustomize (Kubernetes configuration management) on Linux and macOS from official GitHub releases.
- **[install_kubectl.sh](docs/install_kubectl.md)**: Install or uninstall `kubectl` on a Linux system.
- **[install_lm_studio.sh](docs/install_lm_studio.md)**: Install or uninstall LM Studio for running large language models locally with headless API server support.
- **[install_loki.sh](docs/install_loki.md)**: Install or uninstall Grafana Loki log aggregation system.
- **[install_promtail.sh](docs/install_promtail.md)**: Install or uninstall Grafana Promtail log shipper with flexible configuration options.
- **[install_python.sh](docs/install_python.md)**: Install or uninstall Python with version pinning support on Linux, macOS, and Windows.
- **[install_s3_mount.sh](docs/install_s3_mount.md)**: Install or uninstall AWS Mountpoint for Amazon S3 to mount S3 buckets as local filesystems.
- **[install_sam.sh](docs/install_sam.md)**: Install or uninstall the AWS SAM CLI for building, testing, and deploying serverless applications on Linux and macOS.
- **[install_ssm_agent.sh](docs/install_ssm_agent.md)**: Install or uninstall the AWS Systems Manager (SSM) Agent on various Linux distributions, macOS, and Windows.
- **[install_ssm_plugin.sh](docs/install_ssm_plugin.md)**: Install or uninstall the AWS SSM Session Manager Plugin for remote EC2 access.
- **[install_terraform.sh](docs/install_terraform.md)**: Install or uninstall Terraform on supported Linux distributions.
- **[install_tfenv.sh](docs/install_tfenv.md)**: Install or uninstall `tfenv`, a version manager for Terraform.
- **[install_uv.sh](docs/install_uv.md)**: Install or uninstall UV, an extremely fast Python package installer and resolver.
- **[install_vscode_server.sh](docs/install_vscode_server.md)**: Install or uninstall VS Code Server for remote browser-based code editing.
- **[manage_kafka.sh](docs/manage_kafka.md)**: Manage Kafka topics, consumers, and producers.
- **[setup_msk_iam_auth.sh](docs/setup_msk_iam_auth.md)**: Configure IAM authentication for Amazon MSK.
- **[sync_github_repos.sh](docs/sync_github_repos.md)**: Clone or update repositories for a GitHub organization or user.
- **[get_discord_events.py](docs/get_discord_events.md)**: Fetch a Discord guild's scheduled events (raw API JSON to stdout).
- **[get_twitch_schedule.py](docs/get_twitch_schedule.md)**: Fetch a Twitch channel's upcoming stream schedule from the Helix API (JSON to stdout).
- **[get_youtube_upcoming.py](docs/get_youtube_upcoming.md)**: Fetch a YouTube channel's upcoming scheduled live streams (YouTube Data API v3, JSON to stdout).

## Usage

Each script follows a simple command format. Navigate to the script’s documentation for full details.

```bash
./<script_name>.sh [options]
```

## Installation & Setup

Ensure you have the required dependencies installed. See each script's documentation for details on additional requirements.

## Contribution

Feel free to contribute by submitting issues or pull requests.
