# install_agentcore_cli.sh

This script installs or uninstalls the **Amazon Bedrock AgentCore CLI** (`agentcore`) using npm. The package is `@aws/agentcore` from the public npm registry. AWS documents this flow in the [AgentCore CLI quickstart](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/agentcore-get-started-cli.html). Source and issues: [aws/agentcore-cli](https://github.com/aws/agentcore-cli).

## Usage

```bash
./install_agentcore_cli.sh [install|uninstall]
```

- **install** (default): Runs `npm install -g @aws/agentcore` (or a pinned version if set).
- **uninstall**: Runs `npm uninstall -g @aws/agentcore`.

## Example Usage

```bash
./install_agentcore_cli.sh
```

```bash
./install_agentcore_cli.sh install
```

Pin a version or dist-tag:

```bash
AGENTCORE_CLI_VERSION=1.0.0 ./install_agentcore_cli.sh install
```

```bash
./install_agentcore_cli.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_agentcore_cli.sh) install
```

You must already have Node.js 20+ and npm on `PATH`. If you need Node first, see [install_npm.sh](install_npm.md) in this repo.

## Verification

```bash
agentcore --version
```

```bash
agentcore --help
```

## Supported Operating Systems

Any environment where **Node.js 20+**, **npm**, and `npm install -g` work (Linux, macOS, Windows). The script does not download Node; it only invokes npm.

## Supported Architectures

Follows your Node/npm installation (for example x86_64 and arm64).

## Features

- Checks for Node 20+ and npm before installing
- Idempotent: if `agentcore` is already on `PATH`, prints the version and exits without reinstalling
- Optional version or dist-tag via `AGENTCORE_CLI_VERSION`

## Optional environment variables

| Variable | Description |
| -------- | ----------- |
| `AGENTCORE_CLI_VERSION` | If set, passed to npm as `@aws/agentcore@<value>`. If unset, installs the latest default version from the registry. |

## Prerequisites

- **Node.js** 20 or later on `PATH`
- **npm** on `PATH`

## Additional resources

- **AWS documentation**: [Get started with Amazon Bedrock AgentCore](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/agentcore-get-started-cli.html)
- **GitHub**: [aws/agentcore-cli](https://github.com/aws/agentcore-cli)
