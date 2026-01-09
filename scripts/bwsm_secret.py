#!/usr/bin/env python3
"""
bwsm_secret.py

Manage secrets in Bitwarden Secrets Manager using the Bitwarden SDK.

Subcommands:
  get     - Get a secret value
  create  - Create a new secret (coming soon)
  update  - Update an existing secret (coming soon)
  delete  - Delete secret(s) (coming soon)
  list    - List all secrets (coming soon)

Usage:
  bwsm_secret.py <subcommand> [options]

Examples:
  # Get secret by ID
  ./bwsm_secret.py get --secret-id <uuid> --access-token "$BWS_ACCESS_TOKEN"

  # Get secret by name (requires org-id)
  ./bwsm_secret.py get --secret-name "my-secret" --access-token "$BWS_ACCESS_TOKEN" --org-id <uuid>

  # Using environment variables
  export BWS_ACCESS_TOKEN="..."
  export BWS_SECRET_ID="..."  # or BWS_SECRET_NAME="..."
  export BWS_ORG_ID="..."  # Required for name lookup
  ./bwsm_secret.py get

Config sources (highest priority first):
1) CLI args:        --access-token, --secret-id or --secret-name, --org-id
2) Environment:     BWS_ACCESS_TOKEN, BWS_SECRET_ID or BWS_SECRET_NAME, BWS_ORG_ID

Output:
  - By default prints ONLY the secret value to stdout.
  - Use --json for structured output.
  - Use --debug for extra stderr logs.

Exit codes:
  0 success
  2 config/usage error
  3 auth error
  4 not found
  5 sdk/runtime error
"""

import argparse
import os
import re
import sys
from typing import Optional, Tuple

from bitwarden_sdk import BitwardenClient


def eprint(*args: object) -> None:
    print(*args, file=sys.stderr)


def is_uuid(value: str) -> bool:
    """Check if a string is a valid UUID format."""
    uuid_pattern = re.compile(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        re.IGNORECASE
    )
    return bool(uuid_pattern.match(value))


def resolve_config(args: argparse.Namespace) -> Tuple[Optional[str], Optional[str], Optional[str], Optional[str], str]:
    """
    Resolve (access_token, secret_identifier, org_id, identifier_type, source_label).
    identifier_type: 'id' or 'name'
    """
    # Determine secret identifier (ID or name)
    secret_identifier = None
    identifier_type = None

    if args.secret_id:
        secret_identifier = args.secret_id
        identifier_type = "id"
    elif args.secret_name:
        secret_identifier = args.secret_name
        identifier_type = "name"

    # 1) CLI args (check if both are provided and non-empty)
    if args.access_token is not None and secret_identifier:
        # If CLI args are provided but empty, fall through to env vars
        if args.access_token and secret_identifier:
            # Support both BWS_ORG_ID (standard) and BW_ORGANIZATION_ID (legacy)
            org_id = args.org_id or os.getenv("BWS_ORG_ID") or os.getenv("BW_ORGANIZATION_ID")
            return args.access_token, secret_identifier, org_id, identifier_type, "cli"
        # If one is empty, try to fill from env
        access_token = args.access_token if args.access_token else os.getenv("BWS_ACCESS_TOKEN")
        if not secret_identifier:
            # Try environment variables, but don't auto-detect type
            if os.getenv("BWS_SECRET_ID"):
                secret_identifier = os.getenv("BWS_SECRET_ID")
                identifier_type = "id"
            elif os.getenv("BWS_SECRET_NAME"):
                secret_identifier = os.getenv("BWS_SECRET_NAME")
                identifier_type = "name"
        if access_token and secret_identifier:
            # Support both BWS_ORG_ID (standard) and BW_ORGANIZATION_ID (legacy)
            org_id = args.org_id or os.getenv("BWS_ORG_ID") or os.getenv("BW_ORGANIZATION_ID")
            return access_token, secret_identifier, org_id, identifier_type, "cli"

    # 2) Environment
    env_token = os.getenv("BWS_ACCESS_TOKEN")
    env_secret_id = os.getenv("BWS_SECRET_ID")
    env_secret_name = os.getenv("BWS_SECRET_NAME")
    # Support both BWS_ORG_ID (standard) and BW_ORGANIZATION_ID (legacy)
    env_org_id = os.getenv("BWS_ORG_ID") or os.getenv("BW_ORGANIZATION_ID")

    if env_token:
        if env_secret_id:
            return env_token, env_secret_id, env_org_id, "id", "env"
        elif env_secret_name:
            return env_token, env_secret_name, env_org_id, "name", "env"

    # Partial presence can be helpful to message
    return None, None, None, None, "missing"


def find_secret_by_name(client, secret_name: str, org_id: Optional[str] = None, debug: bool = False) -> str:
    """
    Find a secret by name by listing all secrets and matching the key/name.
    Returns the secret ID if found.
    """
    if debug:
        eprint(f"Listing secrets to find secret with name/key='{secret_name}'...")

    # Get organization ID from access token response or use provided org_id
    # We need org_id to list secrets
    if not org_id:
        # Try to get org_id from the client state if available
        # For now, we'll need org_id to be provided
        raise RuntimeError("ORG_ID_REQUIRED: Organization ID is required when searching by name")

    list_response = client.secrets().list(organization_id=org_id)
    if not getattr(list_response, "success", False):
        msg = getattr(list_response, "error_message", "Unknown error")
        raise RuntimeError(f"LIST_ERROR: {msg}")

    data = getattr(list_response, "data", None)
    if not data:
        raise RuntimeError("LIST_ERROR: No data returned from secrets list")

    # Get the list of secrets
    secrets = getattr(data, "data", []) or []

    if debug:
        eprint(f"Found {len(secrets)} secrets, searching for name/key='{secret_name}'...")

    # Search for secret by key (name)
    for secret in secrets:
        secret_key = getattr(secret, "key", None)
        secret_id = getattr(secret, "id", None)
        if secret_key == secret_name:
            if debug:
                eprint(f"Found secret: name='{secret_name}', id='{secret_id}'")
            return secret_id

    raise RuntimeError(f"NOT_FOUND: Secret with name/key '{secret_name}' not found")


def get_secret_value(access_token: str, secret_identifier: str, identifier_type: Optional[str], org_id: Optional[str] = None, debug: bool = False) -> str:
    """
    Authenticate with access token and retrieve a secret value by ID or name.
    Raises RuntimeError with a categorized message on failures.
    """
    client = BitwardenClient()

    if debug:
        eprint("Authenticating with access token...")

    login_response = client.auth().login_access_token(access_token=access_token)
    if not getattr(login_response, "success", False):
        msg = getattr(login_response, "error_message", "Unknown authentication error")
        raise RuntimeError(f"AUTH_ERROR: {msg}")

    # If searching by name, first find the secret ID
    secret_id = secret_identifier

    if identifier_type == "name":
        # Search by name
        if debug:
            if org_id:
                eprint(f"Searching for secret name='{secret_identifier}' (organization id={org_id})...")
            else:
                eprint(f"Searching for secret name='{secret_identifier}'...")
        if not org_id:
            raise RuntimeError("ORG_ID_REQUIRED: Organization ID is required when using secret name (provide via --org-id or BWS_ORG_ID)")
        secret_id = find_secret_by_name(client, secret_identifier, org_id=org_id, debug=debug)
    elif identifier_type == "id":
        # Validate that it's a UUID
        if not is_uuid(secret_identifier):
            raise RuntimeError(f"INVALID_ID: Secret ID must be a valid UUID format. Got: '{secret_identifier}'. Use --secret-name for name-based lookup.")

    if debug:
        if org_id:
            eprint(f"Fetching secret id={secret_id} (organization id={org_id})...")
        else:
            eprint(f"Fetching secret id={secret_id}...")

    # Note: organization_id is not a parameter for secrets().get()
    # The organization is scoped via the access token
    secret_response = client.secrets().get(id=secret_id)
    if getattr(secret_response, "success", False) and getattr(secret_response, "data", None):
        value = getattr(secret_response.data, "value", None)
        if value is None:
            raise RuntimeError("SDK_ERROR: Secret returned but value is empty/null")
        return value

    msg = getattr(secret_response, "error_message", "Unknown error")
    raise RuntimeError(f"NOT_FOUND_OR_ERROR: {msg}")


def build_parser(subcommand: str) -> argparse.ArgumentParser:
    """Build argument parser for the given subcommand."""
    if subcommand == "get":
        p = argparse.ArgumentParser(
            description="Get a specific secret value from Bitwarden Secrets Manager (Bitwarden SDK)."
        )
        p.add_argument("--secret-id", help="Secret ID (UUID format required) to fetch")
        p.add_argument("--secret-name", help="Secret name/key to fetch (requires --org-id)")
        p.add_argument(
            "--access-token",
            help="Bitwarden Secrets Manager access token (prefer env var BWS_ACCESS_TOKEN)",
        )
        p.add_argument(
            "--org-id",
            help="Organization ID (UUID) - required when using --secret-name, optional otherwise (prefer env var BWS_ORG_ID or BW_ORGANIZATION_ID)",
        )
        p.add_argument(
            "--json",
            action="store_true",
            help="Print JSON output (includes secret_id, source). Value still included.",
        )
        p.add_argument(
            "--debug",
            action="store_true",
            help="Print debug logs to stderr.",
        )
    elif subcommand in ("create", "update", "delete", "list"):
        # Placeholder parsers for future subcommands
        p = argparse.ArgumentParser(
            description=f"{subcommand.capitalize()} secret(s) in Bitwarden Secrets Manager (coming soon)."
        )
        p.add_argument(
            "--access-token",
            help="Bitwarden Secrets Manager access token (prefer env var BWS_ACCESS_TOKEN)",
        )
        p.add_argument(
            "--org-id",
            help="Organization ID (UUID) (prefer env var BWS_ORG_ID or BW_ORGANIZATION_ID)",
        )
        p.add_argument(
            "--debug",
            action="store_true",
            help="Print debug logs to stderr.",
        )
    else:
        p = argparse.ArgumentParser(
            description="Manage secrets in Bitwarden Secrets Manager (Bitwarden SDK)."
        )
    return p


def handle_get(args: argparse.Namespace) -> int:
    """Handle the 'get' subcommand."""
    # Validate that only one of --secret-id or --secret-name is provided
    if args.secret_id and args.secret_name:
        eprint("Error: Cannot specify both --secret-id and --secret-name. Use only one.")
        return 2

    access_token, secret_identifier, org_id, identifier_type, source = resolve_config(args)

    if not access_token or not secret_identifier:
        eprint("Config error: missing Bitwarden credentials.")
        eprint("Provide both access token and secret identifier via one of:")
        eprint("  - CLI:  --access-token ... --secret-id <uuid> [--org-id ...]")
        eprint("  - CLI:  --access-token ... --secret-name <name> --org-id <uuid>")
        eprint("  - Env:  BWS_ACCESS_TOKEN and BWS_SECRET_ID (or BWS_SECRET_NAME)")
        eprint("  - Env:  BWS_ORG_ID or BW_ORGANIZATION_ID (required for --secret-name)")
        eprint("")
        # Debug info
        if args.debug:
            eprint("Debug info:")
            eprint(f"  CLI --access-token: {'provided' if args.access_token is not None else 'not provided'} ({'empty' if args.access_token == '' else 'has value'})")
            eprint(f"  CLI --secret-id: {'provided' if args.secret_id is not None else 'not provided'} ({'empty' if args.secret_id == '' else 'has value'})")
            eprint(f"  CLI --secret-name: {'provided' if args.secret_name is not None else 'not provided'} ({'empty' if args.secret_name == '' else 'has value'})")
            eprint(f"  Env BWS_ACCESS_TOKEN: {'set' if os.getenv('BWS_ACCESS_TOKEN') else 'not set'}")
            eprint(f"  Env BWS_SECRET_ID: {'set' if os.getenv('BWS_SECRET_ID') else 'not set'}")
            eprint(f"  Env BWS_SECRET_NAME: {'set' if os.getenv('BWS_SECRET_NAME') else 'not set'}")
        return 2

    try:
        value = get_secret_value(access_token, secret_identifier, identifier_type, org_id=org_id, debug=args.debug)

        if args.json:
            # Minimal JSON, no extra deps
            org_json = f",\"org_id\":\"{org_id}\"" if org_id else ""
            identifier_json = f"\"secret_{identifier_type}\":\"{secret_identifier}\","
            out = (
                "{"
                f"{identifier_json}"
                f"\"source\":\"{source}\"{org_json},"
                f"\"value\":\"{value.replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"')}\""
                "}"
            )
            print(out)
        else:
            # value-only output for easy piping
            print(value)

        return 0

    except RuntimeError as exc:
        msg = str(exc)

        if msg.startswith("AUTH_ERROR:"):
            eprint(f"Error: Authentication failed. {msg[len('AUTH_ERROR: '):]}")
            return 3

        if msg.startswith("NOT_FOUND_OR_ERROR:") or msg.startswith("NOT_FOUND:"):
            error_detail = msg[len('NOT_FOUND_OR_ERROR: '):] if msg.startswith('NOT_FOUND_OR_ERROR:') else msg[len('NOT_FOUND: '):]
            eprint(f"Error: Secret not found. {error_detail}")
            return 4

        if msg.startswith("ORG_ID_REQUIRED:"):
            eprint(f"Error: {msg[len('ORG_ID_REQUIRED: '):]}")
            eprint("When using --secret-name, --org-id is required.")
            return 2

        if msg.startswith("INVALID_ID:"):
            eprint(f"Error: {msg[len('INVALID_ID: '):]}")
            return 2

        if msg.startswith("LIST_ERROR:"):
            eprint(f"Error: Failed to list secrets. {msg[len('LIST_ERROR: '):]}")
            return 5

        if msg.startswith("SDK_ERROR:"):
            eprint(f"Error: SDK returned unexpected data. {msg[len('SDK_ERROR: '):]}")
            return 5

        eprint(f"Error: {msg}")
        return 5

    except Exception as exc:
        eprint(f"Unexpected error: {exc}")
        return 5


def handle_create(args: argparse.Namespace) -> int:
    """Handle the 'create' subcommand (coming soon)."""
    eprint("Error: 'create' subcommand is not yet implemented.")
    return 2


def handle_update(args: argparse.Namespace) -> int:
    """Handle the 'update' subcommand (coming soon)."""
    eprint("Error: 'update' subcommand is not yet implemented.")
    return 2


def handle_delete(args: argparse.Namespace) -> int:
    """Handle the 'delete' subcommand (coming soon)."""
    eprint("Error: 'delete' subcommand is not yet implemented.")
    return 2


def handle_list(args: argparse.Namespace) -> int:
    """Handle the 'list' subcommand (coming soon)."""
    eprint("Error: 'list' subcommand is not yet implemented.")
    return 2


def main() -> int:
    """Main entry point with subcommand routing."""
    # Parse subcommand from first argument
    if len(sys.argv) < 2:
        eprint("Error: Missing subcommand.")
        eprint("Usage: bwsm_secret.py <subcommand> [options]")
        eprint("Subcommands: get, create, update, delete, list")
        return 2

    subcommand = sys.argv[1]
    valid_subcommands = ["get", "create", "update", "delete", "list"]

    if subcommand not in valid_subcommands:
        eprint(f"Error: Invalid subcommand '{subcommand}'.")
        eprint(f"Valid subcommands: {', '.join(valid_subcommands)}")
        return 2

    # Build parser for this subcommand and parse remaining arguments
    parser = build_parser(subcommand)
    # Skip the subcommand when parsing (sys.argv[0] is script name, sys.argv[1] is subcommand)
    args = parser.parse_args(sys.argv[2:])

    # Route to appropriate handler
    if subcommand == "get":
        return handle_get(args)
    elif subcommand == "create":
        return handle_create(args)
    elif subcommand == "update":
        return handle_update(args)
    elif subcommand == "delete":
        return handle_delete(args)
    elif subcommand == "list":
        return handle_list(args)
    else:
        eprint(f"Error: Unhandled subcommand '{subcommand}'.")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
