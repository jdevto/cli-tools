#!/bin/bash

set -e

GITHUB_BASE="https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts"
TMP_PYTHON_SCRIPT="/tmp/bwsm_secret.py"
TMP_INSTALL_SCRIPT="/tmp/install_python.sh"

# Valid subcommands
VALID_SUBCOMMANDS="get create update delete list"

# Global variables
PYTHON_SCRIPT=""
IS_URL_EXECUTION=false
SCRIPT_DIR=""
SUBCOMMAND=""
REMAINING_ARGS=()

usage() {
    echo "Usage: $0 [subcommand] [options]"
    echo ""
    echo "Subcommands:"
    echo "  get     - Get a secret value (default if no subcommand provided)"
    echo "  create  - Create a new secret (coming soon)"
    echo "  update  - Update an existing secret (coming soon)"
    echo "  delete  - Delete secret(s) (coming soon)"
    echo "  list    - List all secrets (coming soon)"
    echo ""
    echo "For backward compatibility, if no subcommand is provided, 'get' is assumed."
    echo "Examples:"
    echo "  $0 --secret-id <uuid> --access-token <token>  # Uses 'get' subcommand"
    echo "  $0 get --secret-id <uuid> --access-token <token>"
    exit 1
}

# Parse subcommand from arguments
parse_subcommand() {
    # Handle --help before parsing subcommand
    if [[ $# -gt 0 ]] && [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        usage
        exit 0
    fi

    # Check if first argument is a valid subcommand
    if [[ $# -gt 0 ]] && [[ " $VALID_SUBCOMMANDS " =~ " $1 " ]]; then
        SUBCOMMAND="$1"
        # Store remaining arguments (skip the first one which is the subcommand)
        REMAINING_ARGS=("${@:2}")
    else
        # No subcommand provided, default to 'get' for backward compatibility
        SUBCOMMAND="get"
        # All arguments are remaining (no subcommand to skip)
        REMAINING_ARGS=("$@")
    fi
}

cleanup() {
    rm -f "$TMP_PYTHON_SCRIPT" "$TMP_INSTALL_SCRIPT"
}
trap cleanup EXIT

# Detect execution context (URL vs local file)
detect_execution_context() {
    # Check if script is being run from URL (piped via curl) or local file
    if [[ "${BASH_SOURCE[0]}" == *"/dev/fd/"* ]] || [[ ! -f "${BASH_SOURCE[0]}" ]]; then
        # Running from URL - download Python script from GitHub
        echo "Detected execution from URL. Downloading Python script..."
        if ! curl -fsSL "$GITHUB_BASE/bwsm_secret.py" -o "$TMP_PYTHON_SCRIPT"; then
            echo "Error: Failed to download Python script from GitHub" >&2
            exit 1
        fi
        chmod +x "$TMP_PYTHON_SCRIPT"
        PYTHON_SCRIPT="$TMP_PYTHON_SCRIPT"
        IS_URL_EXECUTION=true
    else
        # Running locally - use local Python script
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        PYTHON_SCRIPT="$SCRIPT_DIR/bwsm_secret.py"
        IS_URL_EXECUTION=false

        if [[ ! -f "$PYTHON_SCRIPT" ]]; then
            echo "Error: Python script not found at $PYTHON_SCRIPT" >&2
            exit 1
        fi
    fi
}

# Check for Python 3 and install if needed
ensure_python() {
    if command -v python3 >/dev/null 2>&1; then
        return 0
    fi

    echo "Python 3 not found. Installing..."

    if [[ "$IS_URL_EXECUTION" == "true" ]]; then
        # Download install_python.sh from GitHub
        if ! curl -fsSL "$GITHUB_BASE/install_python.sh" -o "$TMP_INSTALL_SCRIPT"; then
            echo "Error: Failed to download install_python.sh from GitHub" >&2
            exit 1
        fi
        chmod +x "$TMP_INSTALL_SCRIPT"
        bash "$TMP_INSTALL_SCRIPT" install
    else
        # Use local install_python.sh
        INSTALL_SCRIPT="$SCRIPT_DIR/install_python.sh"
        if [[ ! -f "$INSTALL_SCRIPT" ]]; then
            echo "Error: install_python.sh not found at $INSTALL_SCRIPT" >&2
            exit 1
        fi
        bash "$INSTALL_SCRIPT" install
    fi

    # Verify Python is now available
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Error: Python 3 installation failed or python3 not in PATH" >&2
        exit 1
    fi
}

# Check for bitwarden_sdk and install if needed
ensure_bitwarden_sdk() {
    if python3 -c "import bitwarden_sdk" 2>/dev/null; then
        return 0
    fi

    echo "bitwarden_sdk not found. Installing..."

    # Try python3 -m pip first, then pip3
    if python3 -m pip install bitwarden-sdk 2>/dev/null; then
        return 0
    elif pip3 install bitwarden-sdk 2>/dev/null; then
        return 0
    else
        echo "Error: Failed to install bitwarden-sdk. Please install manually:" >&2
        echo "  python3 -m pip install bitwarden-sdk" >&2
        exit 1
    fi
}

# Main execution
main() {
    # Parse subcommand from arguments
    parse_subcommand "$@"

    detect_execution_context
    ensure_python
    ensure_bitwarden_sdk

    # Pass subcommand and remaining arguments to Python script
    exec python3 "$PYTHON_SCRIPT" "$SUBCOMMAND" "${REMAINING_ARGS[@]}"
}

main "$@"
