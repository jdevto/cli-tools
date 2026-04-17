#!/bin/bash

set -e

# Optional: pin npm package version or dist-tag, e.g. 1.2.3 or next (empty = latest)
AGENTCORE_CLI_VERSION="${AGENTCORE_CLI_VERSION:-}"

cleanup() {
    :
}
trap cleanup EXIT

usage() {
    cat <<'EOF'
Usage: install_agentcore_cli.sh [install|uninstall]

Default: install.

Installs the Amazon Bedrock AgentCore CLI from npm (@aws/agentcore). Requires Node.js 20+
and npm on PATH. See https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/agentcore-get-started-cli.html

Optional environment variables:
  AGENTCORE_CLI_VERSION  - Pin version or dist-tag for npm (default: latest). Example: 1.0.0

Examples:
  install_agentcore_cli.sh
  install_agentcore_cli.sh install
  AGENTCORE_CLI_VERSION=1.0.0 install_agentcore_cli.sh install
  install_agentcore_cli.sh uninstall
EOF
    exit 1
}

require_node_and_npm() {
    if ! command -v node &>/dev/null; then
        echo "Error: node is not on PATH. Install Node.js 20 or later (npm is included)."
        exit 1
    fi
    if ! command -v npm &>/dev/null; then
        echo "Error: npm is not on PATH. Install Node.js with npm included."
        exit 1
    fi
    local major
    major=$(node -p 'parseInt(process.versions.node.split(".")[0], 10)' 2>/dev/null || echo 0)
    if [[ "$major" -lt 20 ]]; then
        echo "Error: Node.js 20 or later is required (found Node $(node --version 2>/dev/null || echo unknown))."
        exit 1
    fi
}

install_agentcore_cli() {
    require_node_and_npm

    if command -v agentcore &>/dev/null; then
        echo "AgentCore CLI is already installed. Skipping."
        agentcore --version 2>&1 | head -n 1 || true
        exit 0
    fi

    local spec="@aws/agentcore"
    if [[ -n "${AGENTCORE_CLI_VERSION}" ]]; then
        spec="@aws/agentcore@${AGENTCORE_CLI_VERSION}"
    fi

    echo "Installing AgentCore CLI (${spec}) via npm..."
    npm install -g "$spec"

    if ! command -v agentcore &>/dev/null; then
        echo "Error: npm install finished but agentcore was not found on PATH."
        echo "Check npm's global bin directory and your PATH."
        exit 1
    fi

    echo "AgentCore CLI version: $(agentcore --version 2>&1 | head -n 1 || echo unknown)"
}

uninstall_agentcore_cli() {
    require_node_and_npm

    if ! command -v agentcore &>/dev/null; then
        echo "AgentCore CLI is not installed. Nothing to uninstall."
        exit 0
    fi

    echo "Uninstalling @aws/agentcore via npm..."
    npm uninstall -g @aws/agentcore || true

    if command -v agentcore &>/dev/null; then
        echo "Warning: agentcore is still on PATH; you may need to remove it manually."
        exit 1
    fi

    echo "AgentCore CLI has been uninstalled."
}

case "${1:-install}" in
install)
    install_agentcore_cli
    ;;
uninstall)
    uninstall_agentcore_cli
    ;;
-h | --help | help)
    usage
    ;;
*)
    usage
    ;;
esac
