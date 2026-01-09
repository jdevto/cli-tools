#!/usr/bin/env python3
"""
bwsm_secret.py

Manage secrets in Bitwarden Secrets Manager using the Bitwarden SDK.

Subcommands:
  get     - Get a secret value
  create  - Create a new secret
  update  - Update an existing secret
  delete  - Delete secret(s)
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
import uuid
from typing import Optional, Tuple, List

from bitwarden_sdk import BitwardenClient


def eprint(*args: object, **kwargs) -> None:
    print(*args, file=sys.stderr, **kwargs)


def is_uuid(value) -> bool:
    """Check if a value is a valid UUID format (string or UUID object)."""
    # Convert UUID object to string if needed
    if isinstance(value, uuid.UUID):
        value = str(value)
    elif not isinstance(value, str):
        return False

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
            org_id = args.org_id or os.getenv("BWS_ORG_ID")
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
            org_id = args.org_id or os.getenv("BWS_ORG_ID")
            return access_token, secret_identifier, org_id, identifier_type, "cli"

    # 2) Environment
    env_token = os.getenv("BWS_ACCESS_TOKEN")
    env_secret_id = os.getenv("BWS_SECRET_ID")
    env_secret_name = os.getenv("BWS_SECRET_NAME")
    env_org_id = os.getenv("BWS_ORG_ID")

    if env_token:
        if env_secret_id:
            return env_token, env_secret_id, env_org_id, "id", "env"
        elif env_secret_name:
            return env_token, env_secret_name, env_org_id, "name", "env"

    # Partial presence can be helpful to message
    return None, None, None, None, "missing"


def read_value_from_stdin() -> str:
    """
    Read secret value from stdin if available (non-TTY).
    Returns the value as a string.
    Raises RuntimeError if stdin is empty or a TTY.
    """
    import sys

    # Check if stdin is a TTY (interactive terminal)
    if sys.stdin.isatty():
        raise RuntimeError("VALUE_REQUIRED: Secret value is required. Provide via --value or pipe to stdin.")

    # Read from stdin
    value = sys.stdin.read().strip()

    if not value:
        raise RuntimeError("VALUE_REQUIRED: Secret value is required. Provide via --value or pipe to stdin.")

    return value


def resolve_create_config(args: argparse.Namespace) -> Tuple[Optional[str], Optional[str], Optional[str], Optional[str], Optional[str], Optional[str], str]:
    """
    Resolve (access_token, org_id, key, value, note, project_ids, source_label).
    Returns None for missing required values.
    """
    # Resolve access token
    access_token = None
    if args.access_token is not None:
        if args.access_token:
            access_token = args.access_token
        else:
            # Empty string, try env var
            access_token = os.getenv("BWS_ACCESS_TOKEN")
    else:
        # Not provided, try env var
        access_token = os.getenv("BWS_ACCESS_TOKEN")

    # Resolve organization ID
    org_id = None
    if args.org_id is not None:
        if args.org_id:
            org_id = args.org_id
        else:
            # Empty string, try env vars
            org_id = os.getenv("BWS_ORG_ID")
    else:
        # Not provided, try env var
        org_id = os.getenv("BWS_ORG_ID")

    # Key is required and comes from CLI only
    key = args.key if args.key else None

    # Value can come from CLI or stdin (handled separately)
    value = args.value if args.value else None

    # Note is optional
    note = args.note if args.note else None

    # Project IDs are optional
    project_ids = args.project_ids if args.project_ids else None

    # Determine source
    source = "cli" if (args.access_token or args.org_id or args.key) else "env"

    return access_token, org_id, key, value, note, project_ids, source


def resolve_update_config(args: argparse.Namespace) -> Tuple[Optional[str], Optional[str], Optional[str], Optional[str], Optional[str], Optional[str], Optional[str], Optional[str], str]:
    """
    Resolve (access_token, secret_id, secret_name, org_id, key, value, note, project_ids, source_label).
    Returns None for missing optional values.
    """
    # Resolve access token
    access_token = None
    if args.access_token is not None:
        if args.access_token:
            access_token = args.access_token
        else:
            # Empty string, try env var
            access_token = os.getenv("BWS_ACCESS_TOKEN")
    else:
        # Not provided, try env var
        access_token = os.getenv("BWS_ACCESS_TOKEN")

    # Resolve organization ID
    org_id = None
    if args.org_id is not None:
        if args.org_id:
            org_id = args.org_id
        else:
            # Empty string, try env var
            org_id = os.getenv("BWS_ORG_ID")
    else:
        # Not provided, try env var
        org_id = os.getenv("BWS_ORG_ID")

    # Secret ID (single value)
    secret_id = args.secret_id if args.secret_id else None

    # Secret name (single value)
    secret_name = args.secret_name if args.secret_name else None

    # Update fields (all optional)
    key = args.key if args.key else None
    value = args.value if args.value else None
    note = args.note if args.note else None
    project_ids = args.project_ids if args.project_ids else None

    # Determine source
    source = "cli" if (args.access_token or args.org_id or args.secret_id or args.secret_name or args.key or args.value or args.note or args.project_ids) else "env"

    return access_token, secret_id, secret_name, org_id, key, value, note, project_ids, source


def resolve_delete_config(args: argparse.Namespace) -> Tuple[Optional[str], List[str], Optional[str], Optional[str], str]:
    """
    Resolve (access_token, secret_ids, secret_name, org_id, source_label).
    secret_ids: list of UUID strings (from --secret-id, can be comma-separated)
    secret_name: single name string (from --secret-name)
    """
    # Resolve access token
    access_token = None
    if args.access_token is not None:
        if args.access_token:
            access_token = args.access_token
        else:
            # Empty string, try env var
            access_token = os.getenv("BWS_ACCESS_TOKEN")
    else:
        # Not provided, try env var
        access_token = os.getenv("BWS_ACCESS_TOKEN")

    # Resolve organization ID
    org_id = None
    if args.org_id is not None:
        if args.org_id:
            org_id = args.org_id
        else:
            # Empty string, try env var
            org_id = os.getenv("BWS_ORG_ID")
    else:
        # Not provided, try env var
        org_id = os.getenv("BWS_ORG_ID")

    # Parse secret IDs (can be multiple --secret-id flags or comma-separated)
    secret_ids = []
    if args.secret_id:
        for sid in args.secret_id:
            # Handle comma-separated values
            for s in sid.split(","):
                s = s.strip()
                if s:
                    secret_ids.append(s)

    # Secret name (single value)
    secret_name = args.secret_name if args.secret_name else None

    # Determine source
    source = "cli" if (args.access_token or args.org_id or args.secret_id or args.secret_name) else "env"

    return access_token, secret_ids, secret_name, org_id, source


def resolve_list_config(args: argparse.Namespace) -> Tuple[Optional[str], Optional[str], Optional[str], Optional[str], str]:
    """
    Resolve (access_token, org_id, project_id, key_pattern, source_label).
    """
    # Resolve access token
    access_token = None
    if args.access_token is not None:
        if args.access_token:
            access_token = args.access_token
        else:
            # Empty string, try env var
            access_token = os.getenv("BWS_ACCESS_TOKEN")
    else:
        # Not provided, try env var
        access_token = os.getenv("BWS_ACCESS_TOKEN")

    # Resolve organization ID
    org_id = None
    if args.org_id is not None:
        if args.org_id:
            org_id = args.org_id
        else:
            # Empty string, try env var
            org_id = os.getenv("BWS_ORG_ID")
    else:
        # Not provided, try env var
        org_id = os.getenv("BWS_ORG_ID")

    # Extract project_id and key_pattern
    project_id = getattr(args, "project_id", None)
    key_pattern = getattr(args, "key_pattern", None)

    # Determine source
    source = "cli" if (args.access_token or args.org_id or project_id or key_pattern) else "env"

    return access_token, org_id, project_id, key_pattern, source


def find_secret_by_name(client, secret_name: str, org_id: Optional[str] = None, debug: bool = False) -> str:
    """
    Find a secret by name by listing all secrets and matching the key/name.
    Returns the secret ID if found.
    Raises RuntimeError with MULTIPLE_SECRETS if multiple matches found.
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

    # Find all secrets with matching key
    matching_secrets = []
    for secret in secrets:
        secret_key = getattr(secret, "key", None)
        secret_id = getattr(secret, "id", None)
        if secret_key == secret_name and secret_id:
            # Convert UUID object to string if needed
            secret_id_str = str(secret_id) if isinstance(secret_id, uuid.UUID) else secret_id
            matching_secrets.append(secret_id_str)

    if not matching_secrets:
        raise RuntimeError(f"NOT_FOUND: Secret with name/key '{secret_name}' not found")

    # If only one match, return it
    if len(matching_secrets) == 1:
        if debug:
            eprint(f"Found secret: name='{secret_name}', id='{matching_secrets[0]}'")
        return matching_secrets[0]

    # Multiple matches found
    if debug:
        eprint(f"Found {len(matching_secrets)} secrets with name/key='{secret_name}'")

    # Multiple matches - cannot disambiguate
    # Fetch project info for all matches to show in error message
    secret_details = []
    for secret_id in matching_secrets:
        try:
            secret_response = client.secrets().get(id=secret_id)
            if getattr(secret_response, "success", False) and getattr(secret_response, "data", None):
                secret_data = secret_response.data
                secret_project_id = getattr(secret_data, "project_id", None)
                project_str = str(secret_project_id) if secret_project_id else "unknown"
                secret_details.append(f"  - Secret ID: {secret_id}, Project ID: {project_str}")
        except:
            secret_details.append(f"  - Secret ID: {secret_id}, Project ID: unknown")

    error_msg = f"MULTIPLE_SECRETS: Found {len(matching_secrets)} secrets with name/key '{secret_name}':\n"
    error_msg += "\n".join(secret_details)
    error_msg += f"\n\nTo disambiguate, use --secret-id <uuid> with one of the secret IDs above."
    raise RuntimeError(error_msg)


def check_duplicate_secret(client, secret_key: str, org_id: str, project_ids: list, debug: bool = False) -> Optional[str]:
    """
    Check if a secret with the same key already exists in any of the specified projects.
    Returns the secret ID if found, None otherwise.

    Note: The list() API doesn't return project associations, so we need to fetch
    each matching secret individually to check its projects.
    """
    if debug:
        eprint(f"Checking for duplicate secret with key='{secret_key}' in organization id={org_id}...")

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
        eprint(f"Found {len(secrets)} secrets, checking for key='{secret_key}' in projects {[str(p) for p in project_ids]}...")

    # Convert project_ids to strings for comparison
    project_id_strs = {str(pid) for pid in project_ids}

    # Find all secrets with matching key
    matching_secret_ids = []
    for secret in secrets:
        secret_key_attr = getattr(secret, "key", None)
        secret_id = getattr(secret, "id", None)

        if secret_key_attr == secret_key and secret_id:
            matching_secret_ids.append(secret_id)

    if not matching_secret_ids:
        if debug:
            eprint(f"No secrets found with key='{secret_key}'")
        return None

    if debug:
        eprint(f"Found {len(matching_secret_ids)} secret(s) with key='{secret_key}', checking project associations...")

    # Fetch each matching secret to check its project associations
    # The list() API doesn't include project info, so we need to get() each one
    for secret_id in matching_secret_ids:
        try:
            secret_response = client.secrets().get(id=secret_id)
            if not getattr(secret_response, "success", False):
                if debug:
                    eprint(f"Warning: Failed to fetch secret id={secret_id}")
                continue

            secret_data = getattr(secret_response, "data", None)
            if not secret_data:
                if debug:
                    eprint(f"Warning: No data returned for secret id={secret_id}")
                continue

            # Get project_id from the secret object
            # The SDK uses 'project_id' (singular) as a single UUID value
            secret_project_id = getattr(secret_data, "project_id", None)

            if secret_project_id is None:
                # Try alternative attribute names (for backward compatibility)
                for attr_name in ["project_ids", "projects", "projectId"]:
                    secret_project_id = getattr(secret_data, attr_name, None)
                    if secret_project_id is not None:
                        break

            if secret_project_id is None:
                if debug:
                    eprint(f"Warning: Secret '{secret_key}' (id={secret_id}) has no project_id attribute")
                continue

            # Convert project_id to string for comparison
            # It could be a UUID object, a string, or a list (though SDK seems to use single value)
            if isinstance(secret_project_id, uuid.UUID):
                secret_project_id_str = str(secret_project_id)
            elif isinstance(secret_project_id, list):
                # Handle list case (if SDK ever returns multiple projects)
                secret_project_ids = [str(p) if isinstance(p, uuid.UUID) else str(p) for p in secret_project_id]
                if any(pid in project_id_strs for pid in secret_project_ids):
                    if debug:
                        eprint(f"Found duplicate secret: key='{secret_key}', id='{secret_id}', projects={secret_project_ids}")
                    return str(secret_id)
                continue
            else:
                secret_project_id_str = str(secret_project_id)

            # Check if this secret's project_id matches any of the specified projects
            if secret_project_id_str in project_id_strs:
                if debug:
                    eprint(f"Found duplicate secret: key='{secret_key}', id='{secret_id}', project='{secret_project_id_str}'")
                return str(secret_id)

        except Exception as exc:
            if debug:
                eprint(f"Warning: Error checking secret id={secret_id}: {exc}")
                import traceback
                eprint(f"Traceback: {traceback.format_exc()}")
            continue

    if debug:
        eprint(f"No duplicate found for key='{secret_key}' in the specified projects")
    return None


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
            raise RuntimeError("ORG_ID_REQUIRED: Organization ID is required when using secret name (provide via --org-id or BWS_ORG_ID environment variable)")
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


def create_secret(
    access_token: str,
    organization_id: str,
    key: str,
    value: str,
    note: Optional[str] = None,
    project_ids: Optional[str] = None,
    allow_duplicate: bool = False,
    debug: bool = False,
) -> str:
    """
    Authenticate with access token and create a new secret.
    Returns the created secret ID.
    Raises RuntimeError with a categorized message on failures.
    """
    client = BitwardenClient()

    if debug:
        eprint("Authenticating with access token...")

    login_response = client.auth().login_access_token(access_token=access_token)
    if not getattr(login_response, "success", False):
        msg = getattr(login_response, "error_message", "Unknown authentication error")
        raise RuntimeError(f"AUTH_ERROR: {msg}")

    # Validate organization_id is a UUID
    if not is_uuid(organization_id):
        raise RuntimeError(f"INVALID_ID: Organization ID must be a valid UUID format. Got: '{organization_id}'.")

    # Convert organization_id to UUID object
    try:
        org_uuid = uuid.UUID(organization_id)
    except ValueError:
        raise RuntimeError(f"INVALID_ID: Organization ID must be a valid UUID format. Got: '{organization_id}'.")

    # Parse and validate project_ids (required)
    if not project_ids:
        raise RuntimeError("PROJECT_ID_REQUIRED: At least one project ID is required. Secrets must be created within a project, not at the organization level.")

    project_id_list = [pid.strip() for pid in project_ids.split(",") if pid.strip()]
    if not project_id_list:
        raise RuntimeError("PROJECT_ID_REQUIRED: At least one project ID is required. Secrets must be created within a project, not at the organization level.")

    project_uuid_list = []
    for pid in project_id_list:
        if not is_uuid(pid):
            raise RuntimeError(f"INVALID_ID: Project ID must be a valid UUID format. Got: '{pid}'.")
        try:
            project_uuid_list.append(uuid.UUID(pid))
        except ValueError:
            raise RuntimeError(f"INVALID_ID: Project ID must be a valid UUID format. Got: '{pid}'.")

    # Check for duplicate secret (unless --allow-duplicate is set)
    if not allow_duplicate:
        existing_secret_id = check_duplicate_secret(client, key, organization_id, project_uuid_list, debug=debug)
        if existing_secret_id:
            raise RuntimeError(f"DUPLICATE_SECRET: A secret with key '{key}' already exists in one or more of the specified projects (secret ID: {existing_secret_id}). Use --allow-duplicate to create anyway.")

    if debug:
        eprint(f"Creating secret with key='{key}' in organization id={organization_id}...")
        if note:
            eprint(f"  Note: {note}")
        if project_uuid_list:
            eprint(f"  Project IDs: {[str(p) for p in project_uuid_list]}")

    # Call SDK create method
    create_response = client.secrets().create(
        organization_id=org_uuid,
        key=key,
        value=value,
        note=note,
        project_ids=project_uuid_list,
    )

    if getattr(create_response, "success", False) and getattr(create_response, "data", None):
        secret_data = create_response.data
        secret_id = getattr(secret_data, "id", None)
        if secret_id is None:
            raise RuntimeError("SDK_ERROR: Secret created but ID is empty/null")
        return str(secret_id)

    msg = getattr(create_response, "error_message", "Unknown error")

    # Check for 404 errors (organization not found, invalid org ID, or permission issues)
    if "404" in msg or "not found" in msg.lower() or "Resource not found" in msg:
        raise RuntimeError(f"NOT_FOUND: {msg}. This may indicate an invalid organization ID or insufficient permissions.")

    raise RuntimeError(f"SDK_ERROR: {msg}")


def resolve_secret_ids(
    access_token: str,
    secret_ids: List[str],
    secret_name: Optional[str],
    org_id: Optional[str],
    debug: bool = False,
) -> List[str]:
    """
    Resolve all secret identifiers to a list of secret IDs (UUIDs).
    Handles both --secret-id (direct) and --secret-name (resolved) inputs.
    Returns a list of secret IDs ready for deletion.
    """
    client = BitwardenClient()

    if debug:
        eprint("Authenticating with access token...")

    login_response = client.auth().login_access_token(access_token=access_token)
    if not getattr(login_response, "success", False):
        msg = getattr(login_response, "error_message", "Unknown authentication error")
        raise RuntimeError(f"AUTH_ERROR: {msg}")

    resolved_ids = []

    # Add direct secret IDs (validate they're UUIDs)
    for sid in secret_ids:
        if not is_uuid(sid):
            raise RuntimeError(f"INVALID_ID: Secret ID must be a valid UUID format. Got: '{sid}'.")
        resolved_ids.append(sid)

    # Resolve secret name to ID(s)
    if secret_name:
        if not org_id:
            raise RuntimeError("ORG_ID_REQUIRED: Organization ID is required when using --secret-name (provide via --org-id or BWS_ORG_ID environment variable)")

        if debug:
            eprint(f"Resolving secret name '{secret_name}' to ID(s)...")

        try:
            # Check if there are multiple secrets with this name
            # We'll use find_secret_by_name but it will raise MULTIPLE_SECRETS if duplicates exist
            # For safety, we don't allow deletion by name if duplicates exist
            secret_id = find_secret_by_name(client, secret_name, org_id=org_id, debug=debug)
            # If we get here, there's exactly one match - safe to delete
            # Ensure it's a string (not UUID object)
            secret_id_str = str(secret_id) if isinstance(secret_id, uuid.UUID) else secret_id
            resolved_ids.append(secret_id_str)
        except RuntimeError as exc:
            msg = str(exc)
            if msg.startswith("MULTIPLE_SECRETS:"):
                # For safety, don't allow deletion by name when duplicates exist
                # User must use --secret-id explicitly
                raise RuntimeError(f"MULTIPLE_SECRETS_DELETE: Cannot delete by name when multiple secrets share the same name. {msg[len('MULTIPLE_SECRETS: '):]}\n\nFor safety, use --secret-id <uuid> to explicitly specify which secret to delete.")
            raise

    # Remove duplicates while preserving order
    seen = set()
    unique_ids = []
    for sid in resolved_ids:
        if sid not in seen:
            seen.add(sid)
            unique_ids.append(sid)

    if debug:
        eprint(f"Resolved {len(unique_ids)} unique secret ID(s) for deletion")

    return unique_ids


def delete_secret(
    access_token: str,
    secret_ids: List[str],
    debug: bool = False,
) -> List[str]:
    """
    Authenticate with access token and delete secrets by their IDs.
    First checks if each secret exists before attempting deletion.
    Returns the list of deleted secret IDs.
    Raises RuntimeError with a categorized message on failures.
    """
    if not secret_ids:
        raise RuntimeError("INVALID_ID: No secret IDs provided for deletion")

    client = BitwardenClient()

    if debug:
        eprint("Authenticating with access token...")

    login_response = client.auth().login_access_token(access_token=access_token)
    if not getattr(login_response, "success", False):
        msg = getattr(login_response, "error_message", "Unknown authentication error")
        raise RuntimeError(f"AUTH_ERROR: {msg}")

    # Validate all secret IDs are UUIDs
    for sid in secret_ids:
        if not is_uuid(sid):
            raise RuntimeError(f"INVALID_ID: Secret ID must be a valid UUID format. Got: '{sid}'.")

    # Check if secrets exist before attempting deletion
    if debug:
        eprint(f"Checking if {len(secret_ids)} secret(s) exist before deletion...")

    existing_secret_ids = []
    missing_secret_ids = []

    for sid in secret_ids:
        try:
            secret_response = client.secrets().get(id=sid)
            if getattr(secret_response, "success", False) and getattr(secret_response, "data", None):
                existing_secret_ids.append(sid)
                if debug:
                    eprint(f"Secret {sid} exists")
            else:
                missing_secret_ids.append(sid)
                if debug:
                    eprint(f"Secret {sid} not found")
        except Exception as exc:
            # If get() fails, assume secret doesn't exist
            missing_secret_ids.append(sid)
            if debug:
                eprint(f"Error checking secret {sid}: {exc}")

    # If any secrets don't exist, report error
    if missing_secret_ids:
        if len(missing_secret_ids) == 1:
            raise RuntimeError(f"NOT_FOUND: Secret with ID '{missing_secret_ids[0]}' does not exist or you may not have permission to access it.")
        else:
            missing_list = ", ".join([f"'{sid}'" for sid in missing_secret_ids])
            raise RuntimeError(f"NOT_FOUND: Secrets with IDs {missing_list} do not exist or you may not have permission to access them.")

    # If no secrets exist to delete, return empty list
    if not existing_secret_ids:
        if debug:
            eprint("No secrets found to delete")
        return []

    if debug:
        eprint(f"Deleting {len(existing_secret_ids)} secret(s)...")

    # Call SDK delete method (accepts list of IDs)
    delete_response = client.secrets().delete(ids=existing_secret_ids)

    if getattr(delete_response, "success", False):
        # SDK delete returns success, return the IDs that were deleted
        if debug:
            eprint(f"Successfully deleted {len(existing_secret_ids)} secret(s)")
        return existing_secret_ids

    msg = getattr(delete_response, "error_message", "Unknown error")

    # Check for 404 errors (secrets not found)
    if "404" in msg or "not found" in msg.lower() or "Resource not found" in msg:
        raise RuntimeError(f"NOT_FOUND: {msg}. One or more secrets may not exist or you may not have permission to delete them.")

    raise RuntimeError(f"SDK_ERROR: {msg}")


def get_secret_for_update(client, secret_id: str, debug: bool = False) -> dict:
    """
    Fetch the current secret data for update operations.
    Returns a dict with current secret fields: key, value, note, project_id, organization_id.
    Raises RuntimeError with NOT_FOUND if secret doesn't exist.
    """
    if debug:
        eprint(f"Fetching current secret data for id={secret_id}...")

    secret_response = client.secrets().get(id=secret_id)
    if not getattr(secret_response, "success", False):
        msg = getattr(secret_response, "error_message", "Unknown error")
        raise RuntimeError(f"NOT_FOUND: Secret with ID '{secret_id}' does not exist or you may not have permission to access it. {msg}")

    secret_data = getattr(secret_response, "data", None)
    if not secret_data:
        raise RuntimeError(f"NOT_FOUND: Secret with ID '{secret_id}' not found or has no data.")

    # Extract current values
    current_key = getattr(secret_data, "key", None)
    current_value = getattr(secret_data, "value", None)
    current_note = getattr(secret_data, "note", None)
    current_project_id = getattr(secret_data, "project_id", None)
    current_organization_id = getattr(secret_data, "organization_id", None)

    # Convert UUID objects to strings
    if current_project_id:
        current_project_id = str(current_project_id) if isinstance(current_project_id, uuid.UUID) else current_project_id
    if current_organization_id:
        current_organization_id = str(current_organization_id) if isinstance(current_organization_id, uuid.UUID) else current_organization_id

    return {
        "key": current_key,
        "value": current_value,
        "note": current_note,
        "project_id": current_project_id,
        "organization_id": current_organization_id,
    }


def list_secrets(
    access_token: str,
    organization_id: str,
    project_id: Optional[str] = None,
    key_pattern: Optional[str] = None,
    debug: bool = False,
) -> List[dict]:
    """
    Authenticate with access token and list all secrets in the organization.
    Optionally filter by project_id and/or key_pattern.
    Returns a list of secret dictionaries with fields: id, key, note, project_id.
    Raises RuntimeError with a categorized message on failures.

    Note: The SDK's list() API doesn't return project associations, so filtering
    by project_id requires individual get() calls for each secret, which is slower.
    """
    client = BitwardenClient()

    if debug:
        eprint("Authenticating with access token...")

    login_response = client.auth().login_access_token(access_token=access_token)
    if not getattr(login_response, "success", False):
        msg = getattr(login_response, "error_message", "Unknown authentication error")
        raise RuntimeError(f"AUTH_ERROR: {msg}")

    # Validate organization_id is a UUID
    if not is_uuid(organization_id):
        raise RuntimeError(f"INVALID_ID: Organization ID must be a valid UUID format. Got: '{organization_id}'.")

    # Convert organization_id to UUID object
    try:
        org_uuid = uuid.UUID(organization_id)
    except ValueError:
        raise RuntimeError(f"INVALID_ID: Organization ID must be a valid UUID format. Got: '{organization_id}'.")

    # Validate project_id if provided
    if project_id:
        if not is_uuid(project_id):
            raise RuntimeError(f"INVALID_ID: Project ID must be a valid UUID format. Got: '{project_id}'.")

    if debug:
        eprint(f"Listing secrets in organization id={organization_id}...")
        if project_id:
            eprint(f"Filtering by project_id='{project_id}' (this requires fetching each secret individually, which is slower)...")
        if key_pattern:
            eprint(f"Filtering by key_pattern='{key_pattern}'...")

    # Call SDK list method
    list_response = client.secrets().list(organization_id=org_uuid)
    if not getattr(list_response, "success", False):
        msg = getattr(list_response, "error_message", "Unknown error")
        raise RuntimeError(f"LIST_ERROR: {msg}")

    data = getattr(list_response, "data", None)
    if not data:
        raise RuntimeError("LIST_ERROR: No data returned from secrets list")

    # Get the list of secrets
    secrets = getattr(data, "data", []) or []

    if debug:
        eprint(f"Found {len(secrets)} secret(s) in organization")

    # Apply key_pattern filter first (if provided)
    filtered_secrets = []
    for secret in secrets:
        secret_key = getattr(secret, "key", None)
        secret_id = getattr(secret, "id", None)

        if not secret_id:
            if debug:
                eprint(f"Warning: Secret has no ID, skipping")
            continue

        # Apply key_pattern filter
        if key_pattern:
            if not secret_key or key_pattern not in secret_key:
                continue

        # Convert UUID object to string if needed
        secret_id_str = str(secret_id) if isinstance(secret_id, uuid.UUID) else secret_id
        filtered_secrets.append({
            "id": secret_id_str,
            "key": secret_key,
        })

    if debug:
        eprint(f"After key_pattern filter: {len(filtered_secrets)} secret(s)")

    # Apply project_id filter if provided (requires fetching each secret)
    if project_id:
        project_id_str = str(project_id)
        matching_secrets = []

        if debug:
            eprint(f"Fetching project info for {len(filtered_secrets)} secret(s) to filter by project_id...")

        for secret_info in filtered_secrets:
            secret_id = secret_info["id"]
            try:
                secret_response = client.secrets().get(id=secret_id)
                if not getattr(secret_response, "success", False):
                    if debug:
                        eprint(f"Warning: Failed to fetch secret id={secret_id}")
                    continue

                secret_data = getattr(secret_response, "data", None)
                if not secret_data:
                    if debug:
                        eprint(f"Warning: No data returned for secret id={secret_id}")
                    continue

                # Get project_id from the secret object
                secret_project_id = getattr(secret_data, "project_id", None)

                if secret_project_id is None:
                    # Try alternative attribute names (for backward compatibility)
                    for attr_name in ["project_ids", "projects", "projectId"]:
                        secret_project_id = getattr(secret_data, attr_name, None)
                        if secret_project_id is not None:
                            break

                if secret_project_id is None:
                    # Secret has no project_id (removed from project)
                    continue

                # Convert project_id to string for comparison
                if isinstance(secret_project_id, uuid.UUID):
                    secret_project_id_str = str(secret_project_id)
                elif isinstance(secret_project_id, list):
                    # Handle list case (if SDK ever returns multiple projects)
                    secret_project_ids = [str(p) if isinstance(p, uuid.UUID) else str(p) for p in secret_project_id]
                    if project_id_str in secret_project_ids:
                        secret_info["project_id"] = secret_project_id_str
                        secret_info["note"] = getattr(secret_data, "note", None)
                        matching_secrets.append(secret_info)
                    continue
                else:
                    secret_project_id_str = str(secret_project_id)

                # Check if this secret's project_id matches
                if secret_project_id_str == project_id_str:
                    secret_info["project_id"] = secret_project_id_str
                    secret_info["note"] = getattr(secret_data, "note", None)
                    matching_secrets.append(secret_info)

            except Exception as exc:
                if debug:
                    eprint(f"Warning: Error checking secret id={secret_id}: {exc}")
                continue

        filtered_secrets = matching_secrets

        if debug:
            eprint(f"After project_id filter: {len(filtered_secrets)} secret(s)")

    # If project_id filter was not applied, we still need to get note for each secret
    # But to avoid too many API calls, we'll only fetch notes if not filtering by project
    # For now, we'll leave note as None if project_id filter wasn't used
    # (The list API doesn't return notes, so we'd need to fetch each secret anyway)

    return filtered_secrets


def format_secrets_table(secrets: List[dict]) -> str:
    """
    Format a list of secret dictionaries as a human-readable table.
    Returns the formatted table as a string.
    """
    if not secrets:
        return "No secrets found."

    # Calculate column widths
    id_width = max(len("ID"), max(len(s.get("id", "") or "") for s in secrets), 36)  # UUID is 36 chars
    key_width = max(len("Key"), max(len(s.get("key", "") or "") for s in secrets), 20)
    project_width = max(len("Project ID"), max(len(s.get("project_id", "") or "") for s in secrets), 36)
    note_width = max(len("Note"), max(len(s.get("note", "") or "") for s in secrets), 30)

    # Limit column widths to reasonable maximums
    id_width = min(id_width, 36)
    key_width = min(key_width, 50)
    project_width = min(project_width, 36)
    note_width = min(note_width, 50)

    # Build header
    header = f"{'ID':<{id_width}}  {'Key':<{key_width}}  {'Project ID':<{project_width}}  {'Note':<{note_width}}"
    separator = "-" * len(header)

    # Build rows
    rows = [header, separator]
    for secret in secrets:
        secret_id = secret.get("id", "") or ""
        secret_key = secret.get("key", "") or ""
        secret_project_id = secret.get("project_id", "") or ""
        secret_note = secret.get("note", "") or ""

        # Truncate long values
        if len(secret_key) > key_width:
            secret_key = secret_key[:key_width-3] + "..."
        if len(secret_note) > note_width:
            secret_note = secret_note[:note_width-3] + "..."

        row = f"{secret_id:<{id_width}}  {secret_key:<{key_width}}  {secret_project_id:<{project_width}}  {secret_note:<{note_width}}"
        rows.append(row)

    return "\n".join(rows)


def format_secrets_json(secrets: List[dict]) -> str:
    """
    Format a list of secret dictionaries as a JSON array.
    Returns the formatted JSON as a string.
    """
    if not secrets:
        return "[]"

    json_objects = []
    for secret in secrets:
        secret_id = secret.get("id", "") or ""
        secret_key = secret.get("key", "") or ""
        secret_project_id = secret.get("project_id", "") or ""
        secret_note = secret.get("note", "") or ""

        # Escape special characters
        escaped_key = secret_key.replace("\\", "\\\\").replace('"', '\\"')
        escaped_note = secret_note.replace("\\", "\\\\").replace('"', '\\"')

        # Build JSON object
        project_json = f',"project_id":"{secret_project_id}"' if secret_project_id else ',"project_id":null'
        note_json = f',"note":"{escaped_note}"' if secret_note else ',"note":null'

        json_obj = f'{{"secret_id":"{secret_id}","key":"{escaped_key}"{project_json}{note_json}}}'
        json_objects.append(json_obj)

    return "[" + ",".join(json_objects) + "]"


def update_secret(
    access_token: str,
    secret_id: str,
    organization_id: str,
    key: Optional[str] = None,
    value: Optional[str] = None,
    note: Optional[str] = None,
    project_ids: Optional[str] = None,
    debug: bool = False,
) -> str:
    """
    Authenticate with access token and update an existing secret.
    Only provided fields are updated; existing values are preserved for omitted fields.
    Returns the updated secret ID.
    Raises RuntimeError with a categorized message on failures.
    """
    client = BitwardenClient()

    if debug:
        eprint("Authenticating with access token...")

    login_response = client.auth().login_access_token(access_token=access_token)
    if not getattr(login_response, "success", False):
        msg = getattr(login_response, "error_message", "Unknown authentication error")
        raise RuntimeError(f"AUTH_ERROR: {msg}")

    # Validate secret ID is a UUID
    if not is_uuid(secret_id):
        raise RuntimeError(f"INVALID_ID: Secret ID must be a valid UUID format. Got: '{secret_id}'.")

    # Validate organization_id is a UUID
    if not is_uuid(organization_id):
        raise RuntimeError(f"INVALID_ID: Organization ID must be a valid UUID format. Got: '{organization_id}'.")

    # Convert organization_id to UUID object
    try:
        org_uuid = uuid.UUID(organization_id)
    except ValueError:
        raise RuntimeError(f"INVALID_ID: Organization ID must be a valid UUID format. Got: '{organization_id}'.")

    # Fetch current secret to get existing values
    current_secret = get_secret_for_update(client, secret_id, debug=debug)

    # Merge provided update fields with current values
    # Only update fields that are explicitly provided
    final_key = key if key is not None else current_secret["key"]
    final_value = value if value is not None else current_secret["value"]
    final_note = note if note is not None else current_secret["note"]

    # Handle project_ids
    if project_ids is not None:
        # Parse and validate project_ids
        project_id_list = [pid.strip() for pid in project_ids.split(",") if pid.strip()]
        if not project_id_list:
            raise RuntimeError("INVALID_ID: Project IDs cannot be empty. Provide at least one valid UUID.")

        project_uuid_list = []
        for pid in project_id_list:
            if not is_uuid(pid):
                raise RuntimeError(f"INVALID_ID: Project ID must be a valid UUID format. Got: '{pid}'.")
            try:
                project_uuid_list.append(uuid.UUID(pid))
            except ValueError:
                raise RuntimeError(f"INVALID_ID: Project ID must be a valid UUID format. Got: '{pid}'.")
    else:
        # Use current project_id if available
        # Note: If secret was removed from project, project_id might be None
        if current_secret.get("project_id"):
            try:
                project_uuid_list = [uuid.UUID(current_secret["project_id"])]
            except (ValueError, TypeError):
                # If current project_id is invalid, we need to provide one
                raise RuntimeError("INVALID_ID: Current secret has no valid project_id. You must provide --project-ids when updating.")
        else:
            # Secret has no project_id (may have been removed from project)
            # The SDK update() requires project_ids, so we must require it
            raise RuntimeError("INVALID_ID: Current secret has no project_id (it may have been removed from its project). You must provide --project-ids when updating to assign it to a project.")

    if debug:
        eprint(f"Updating secret id={secret_id} in organization id={organization_id}...")
        eprint(f"  Key: {final_key}")
        if final_note:
            eprint(f"  Note: {final_note}")
        eprint(f"  Project IDs: {[str(p) for p in project_uuid_list]}")

    # Call SDK update method
    update_response = client.secrets().update(
        organization_id=org_uuid,
        id=secret_id,
        key=final_key,
        value=final_value,
        note=final_note,
        project_ids=project_uuid_list,
    )

    if getattr(update_response, "success", False) and getattr(update_response, "data", None):
        secret_data = update_response.data
        updated_secret_id = getattr(secret_data, "id", None)
        if updated_secret_id is None:
            raise RuntimeError("SDK_ERROR: Secret updated but ID is empty/null")
        return str(updated_secret_id)

    msg = getattr(update_response, "error_message", "Unknown error")

    # Check for 404 errors (secret not found, invalid org ID, or permission issues)
    if "404" in msg or "not found" in msg.lower() or "Resource not found" in msg:
        raise RuntimeError(f"NOT_FOUND: {msg}. This may indicate the secret doesn't exist, invalid organization ID, or insufficient permissions.")

    raise RuntimeError(f"SDK_ERROR: {msg}")


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
            help="Organization ID (UUID) - required when using --secret-name, optional otherwise (prefer env var BWS_ORG_ID)",
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
    elif subcommand == "create":
        p = argparse.ArgumentParser(
            description="Create a new secret in Bitwarden Secrets Manager (Bitwarden SDK)."
        )
        p.add_argument(
            "--key",
            required=True,
            help="Secret key/name (required)",
        )
        p.add_argument(
            "--value",
            help="Secret value (optional, will read from stdin if not provided)",
        )
        p.add_argument(
            "--org-id",
            required=True,
            help="Organization ID (UUID format, required) (prefer env var BWS_ORG_ID)",
        )
        p.add_argument(
            "--note",
            help="Note/description for the secret (optional)",
        )
        p.add_argument(
            "--project-ids",
            dest="project_ids",
            required=True,
            help="Comma-separated list of project IDs (UUIDs, required). Secrets must be created within a project, not at the organization level.",
        )
        p.add_argument(
            "--access-token",
            help="Bitwarden Secrets Manager access token (prefer env var BWS_ACCESS_TOKEN)",
        )
        p.add_argument(
            "--json",
            action="store_true",
            help="Print JSON output (includes secret_id, key, org_id, etc.) instead of just secret ID.",
        )
        p.add_argument(
            "--allow-duplicate",
            action="store_true",
            help="Allow creating a secret even if one with the same key already exists in the project(s). By default, duplicate keys are not allowed.",
        )
        p.add_argument(
            "--debug",
            action="store_true",
            help="Print debug logs to stderr.",
        )
    elif subcommand == "delete":
        p = argparse.ArgumentParser(
            description="Delete secret(s) from Bitwarden Secrets Manager (Bitwarden SDK)."
        )
        p.add_argument(
            "--secret-id",
            action="append",
            help="Secret ID (UUID format) to delete. Can be specified multiple times or comma-separated.",
        )
        p.add_argument(
            "--secret-name",
            help="Secret name/key to delete (requires --org-id, only works if name is unique)",
        )
        p.add_argument(
            "--access-token",
            help="Bitwarden Secrets Manager access token (prefer env var BWS_ACCESS_TOKEN)",
        )
        p.add_argument(
            "--org-id",
            help="Organization ID (UUID) - required when using --secret-name (prefer env var BWS_ORG_ID)",
        )
        p.add_argument(
            "--force",
            action="store_true",
            help="Skip confirmation prompt (required for non-interactive use)",
        )
        p.add_argument(
            "--json",
            action="store_true",
            help="Print JSON output (includes deleted_secret_ids, count) instead of just IDs.",
        )
        p.add_argument(
            "--debug",
            action="store_true",
            help="Print debug logs to stderr.",
        )
    elif subcommand == "update":
        p = argparse.ArgumentParser(
            description="Update an existing secret in Bitwarden Secrets Manager (Bitwarden SDK)."
        )
        p.add_argument(
            "--secret-id",
            help="Secret ID (UUID format) to update",
        )
        p.add_argument(
            "--secret-name",
            help="Secret name/key to update (requires --org-id, only works if name is unique)",
        )
        p.add_argument(
            "--key",
            help="New secret key/name (optional, only updates if provided)",
        )
        p.add_argument(
            "--value",
            help="New secret value (optional, can read from stdin if not provided)",
        )
        p.add_argument(
            "--note",
            help="New note/description (optional, only updates if provided)",
        )
        p.add_argument(
            "--project-ids",
            dest="project_ids",
            help="New project IDs (comma-separated list of UUIDs, optional, only updates if provided)",
        )
        p.add_argument(
            "--access-token",
            help="Bitwarden Secrets Manager access token (prefer env var BWS_ACCESS_TOKEN)",
        )
        p.add_argument(
            "--org-id",
            help="Organization ID (UUID) - required when using --secret-name (prefer env var BWS_ORG_ID)",
        )
        p.add_argument(
            "--json",
            action="store_true",
            help="Print JSON output (includes secret_id, key, value, note, project_ids) instead of just secret ID.",
        )
        p.add_argument(
            "--force",
            action="store_true",
            help="Skip confirmation prompt when updating a secret that was removed from its project (requires --project-ids).",
        )
        p.add_argument(
            "--debug",
            action="store_true",
            help="Print debug logs to stderr.",
        )
    elif subcommand == "list":
        p = argparse.ArgumentParser(
            description="List all secrets in Bitwarden Secrets Manager (Bitwarden SDK)."
        )
        p.add_argument(
            "--access-token",
            help="Bitwarden Secrets Manager access token (prefer env var BWS_ACCESS_TOKEN)",
        )
        p.add_argument(
            "--org-id",
            help="Organization ID (UUID, required) (prefer env var BWS_ORG_ID)",
        )
        p.add_argument(
            "--project-id",
            help="Filter by project ID (UUID, optional). Note: Requires fetching each secret individually, which is slower.",
        )
        p.add_argument(
            "--key-pattern",
            help="Filter by key name pattern (substring match, case-sensitive, optional)",
        )
        p.add_argument(
            "--json",
            action="store_true",
            help="Print JSON output (array of secret objects) instead of table format.",
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
        eprint("  - Env:  BWS_ORG_ID (required for --secret-name)")
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

        if msg.startswith("MULTIPLE_SECRETS:"):
            eprint(f"Error: {msg[len('MULTIPLE_SECRETS: '):]}")
            return 2

        if msg.startswith("SDK_ERROR:"):
            eprint(f"Error: SDK returned unexpected data. {msg[len('SDK_ERROR: '):]}")
            return 5

        eprint(f"Error: {msg}")
        return 5

    except Exception as exc:
        eprint(f"Unexpected error: {exc}")
        return 5


def handle_create(args: argparse.Namespace) -> int:
    """Handle the 'create' subcommand."""
    access_token, org_id, key, value, note, project_ids, source = resolve_create_config(args)

    # Validate required parameters
    if not access_token:
        eprint("Config error: missing access token.")
        eprint("Provide access token via one of:")
        eprint("  - CLI:  --access-token <token>")
        eprint("  - Env:  BWS_ACCESS_TOKEN")
        return 2

    if not org_id:
        eprint("Config error: missing organization ID.")
        eprint("Provide organization ID via one of:")
        eprint("  - CLI:  --org-id <uuid>")
        eprint("  - Env:  BWS_ORG_ID")
        return 2

    if not key:
        eprint("Config error: missing secret key.")
        eprint("Provide secret key via:")
        eprint("  - CLI:  --key <key-name>")
        return 2

    if not project_ids:
        eprint("Config error: missing project IDs.")
        eprint("Secrets must be created within a project, not at the organization level.")
        eprint("Provide at least one project ID via:")
        eprint("  - CLI:  --project-ids <uuid1>[,uuid2,...]")
        eprint("Note: Multiple project IDs can be provided as a comma-separated list.")
        return 2

    # Handle value: CLI takes precedence, fallback to stdin
    secret_value = value
    if not secret_value:
        try:
            secret_value = read_value_from_stdin()
        except RuntimeError as exc:
            msg = str(exc)
            if msg.startswith("VALUE_REQUIRED:"):
                eprint(f"Error: {msg[len('VALUE_REQUIRED: '):]}")
                return 2
            raise

    try:
        secret_id = create_secret(
            access_token=access_token,
            organization_id=org_id,
            key=key,
            value=secret_value,
            note=note,
            project_ids=project_ids,
            allow_duplicate=getattr(args, "allow_duplicate", False),
            debug=args.debug,
        )

        if args.json:
            # JSON output with all details
            note_json = f",\"note\":\"{note.replace('\"', '\\\\\"')}\"" if note else ""
            project_ids_json = ""
            if project_ids:
                project_id_list = [pid.strip() for pid in project_ids.split(",") if pid.strip()]
                project_ids_array = ",".join([f'"{pid}"' for pid in project_id_list])
                project_ids_json = f",\"project_ids\":[{project_ids_array}]"
            out = (
                "{"
                f"\"secret_id\":\"{secret_id}\","
                f"\"key\":\"{key.replace('\"', '\\\\\"')}\","
                f"\"org_id\":\"{org_id}\"{note_json}{project_ids_json}"
                "}"
            )
            print(out)
        else:
            # secret ID only for easy piping
            print(secret_id)

        return 0

    except RuntimeError as exc:
        msg = str(exc)

        if msg.startswith("AUTH_ERROR:"):
            eprint(f"Error: Authentication failed. {msg[len('AUTH_ERROR: '):]}")
            return 3

        if msg.startswith("PROJECT_ID_REQUIRED:"):
            eprint(f"Error: {msg[len('PROJECT_ID_REQUIRED: '):]}")
            return 2

        if msg.startswith("DUPLICATE_SECRET:"):
            eprint(f"Error: {msg[len('DUPLICATE_SECRET: '):]}")
            return 2

        if msg.startswith("LIST_ERROR:"):
            eprint(f"Error: Failed to check for duplicates. {msg[len('LIST_ERROR: '):]}")
            return 5

        if msg.startswith("INVALID_ID:"):
            eprint(f"Error: {msg[len('INVALID_ID: '):]}")
            return 2

        if msg.startswith("NOT_FOUND:"):
            error_detail = msg[len('NOT_FOUND: '):]
            eprint(f"Error: Resource not found. {error_detail}")
            eprint("This may indicate:")
            eprint("  - Invalid organization ID or project ID")
            eprint("  - Organization or project doesn't exist")
            eprint("  - Access token doesn't have permission")
            eprint("  - Note: Secrets must be created within a project, not at the organization level")
            return 4

        if msg.startswith("SDK_ERROR:"):
            eprint(f"Error: SDK error. {msg[len('SDK_ERROR: '):]}")
            return 5

        eprint(f"Error: {msg}")
        return 5

    except Exception as exc:
        # Check if it's a 404 error in the exception message
        exc_msg = str(exc)
        if "404" in exc_msg or "not found" in exc_msg.lower() or "Resource not found" in exc_msg:
            eprint(f"Error: Resource not found. {exc_msg}")
            eprint("This may indicate:")
            eprint("  - Invalid organization ID or project ID")
            eprint("  - Organization or project doesn't exist")
            eprint("  - Access token doesn't have permission")
            eprint("  - Note: Secrets must be created within a project, not at the organization level")
            return 4
        eprint(f"Unexpected error: {exc}")
        return 5


def handle_update(args: argparse.Namespace) -> int:
    """Handle the 'update' subcommand."""
    # Validate that only one of --secret-id or --secret-name is provided
    if args.secret_id and args.secret_name:
        eprint("Error: Cannot specify both --secret-id and --secret-name. Use only one.")
        return 2

    # Validate that at least one identifier is provided
    if not args.secret_id and not args.secret_name:
        eprint("Config error: missing secret identifier.")
        eprint("Provide at least one secret identifier via:")
        eprint("  - CLI:  --secret-id <uuid>")
        eprint("  - CLI:  --secret-name <name> --org-id <uuid>")
        return 2

    access_token, secret_id, secret_name, org_id, key, value, note, project_ids, source = resolve_update_config(args)

    # Validate required parameters
    if not access_token:
        eprint("Config error: missing access token.")
        eprint("Provide access token via one of:")
        eprint("  - CLI:  --access-token <token>")
        eprint("  - Env:  BWS_ACCESS_TOKEN")
        return 2

    if secret_name and not org_id:
        eprint("Config error: missing organization ID.")
        eprint("Organization ID is required when using --secret-name.")
        eprint("Provide organization ID via one of:")
        eprint("  - CLI:  --org-id <uuid>")
        eprint("  - Env:  BWS_ORG_ID")
        return 2

    # Validate that at least one update field is provided
    if not key and not value and not note and not project_ids:
        eprint("Config error: no update fields provided.")
        eprint("Provide at least one field to update via:")
        eprint("  - CLI:  --key <new-key>")
        eprint("  - CLI:  --value <new-value> (or pipe to stdin)")
        eprint("  - CLI:  --note <new-note>")
        eprint("  - CLI:  --project-ids <uuid1>[,uuid2,...]")
        return 2

    try:
        # Resolve secret ID
        resolved_secret_id = secret_id
        resolved_org_id = org_id

        if secret_name:
            # Resolve secret name to ID (only works if unique, like delete)
            if not org_id:
                raise RuntimeError("ORG_ID_REQUIRED: Organization ID is required when using --secret-name (provide via --org-id or BWS_ORG_ID environment variable)")

            debug_flag = getattr(args, "debug", False)
            if debug_flag:
                eprint(f"Resolving secret name '{secret_name}' to ID...")

            # For safety, only allow update by name if the name is unique
            client = BitwardenClient()
            login_response = client.auth().login_access_token(access_token=access_token)
            if not getattr(login_response, "success", False):
                msg = getattr(login_response, "error_message", "Unknown authentication error")
                raise RuntimeError(f"AUTH_ERROR: {msg}")

            try:
                resolved_secret_id = find_secret_by_name(client, secret_name, org_id=org_id, debug=args.debug)
                # Ensure it's a string (not UUID object)
                resolved_secret_id = str(resolved_secret_id) if isinstance(resolved_secret_id, uuid.UUID) else resolved_secret_id
            except RuntimeError as exc:
                msg = str(exc)
                if msg.startswith("MULTIPLE_SECRETS:"):
                    # For safety, don't allow update by name when duplicates exist
                    raise RuntimeError(f"MULTIPLE_SECRETS_UPDATE: Cannot update by name when multiple secrets share the same name. {msg[len('MULTIPLE_SECRETS: '):]}\n\nFor safety, use --secret-id <uuid> to explicitly specify which secret to update.")
                raise

        # Validate secret ID is present
        if not resolved_secret_id:
            eprint("Error: Could not resolve secret ID.")
            return 2

        # Get organization_id from current secret if not provided, and check if secret was removed from project
        current_secret = None
        if not resolved_org_id:
            # Fetch current secret to get organization_id
            client = BitwardenClient()
            login_response = client.auth().login_access_token(access_token=access_token)
            if not getattr(login_response, "success", False):
                msg = getattr(login_response, "error_message", "Unknown authentication error")
                raise RuntimeError(f"AUTH_ERROR: {msg}")

            try:
                current_secret = get_secret_for_update(client, resolved_secret_id, debug=getattr(args, "debug", False))
                resolved_org_id = current_secret["organization_id"]
                if not resolved_org_id:
                    eprint("Error: Could not determine organization ID from secret. Please provide --org-id.")
                    return 2
            except RuntimeError as exc:
                msg = str(exc)
                if msg.startswith("NOT_FOUND:"):
                    # Secret doesn't exist or can't be accessed - provide helpful error message
                    eprint(f"Error: Secret not found. {msg[len('NOT_FOUND: '):]}")
                    eprint("This may indicate:")
                    eprint("  - The secret ID is incorrect")
                    eprint("  - The secret doesn't exist")
                    eprint("  - The secret was removed from its project and may need --org-id to be accessed")
                    eprint("  - You don't have permission to access this secret")
                    eprint("")
                    eprint("Try providing --org-id explicitly:")
                    eprint("  ./bwsm_secret.sh update --secret-id <uuid> --org-id <org-uuid> [update-fields] --access-token <token>")
                    return 4
                raise
        else:
            # Org ID provided, but we still need to fetch current secret to check if it was removed from project
            client = BitwardenClient()
            login_response = client.auth().login_access_token(access_token=access_token)
            if not getattr(login_response, "success", False):
                msg = getattr(login_response, "error_message", "Unknown authentication error")
                raise RuntimeError(f"AUTH_ERROR: {msg}")

            try:
                current_secret = get_secret_for_update(client, resolved_secret_id, debug=getattr(args, "debug", False))
            except RuntimeError as exc:
                msg = str(exc)
                if msg.startswith("NOT_FOUND:"):
                    eprint(f"Error: Secret not found. {msg[len('NOT_FOUND: '):]}")
                    eprint("This may indicate:")
                    eprint("  - The secret ID is incorrect")
                    eprint("  - The secret doesn't exist")
                    eprint("  - You don't have permission to access this secret")
                    return 4
                raise

        # Check if secret was removed from project (no project_id)
        if current_secret and not current_secret.get("project_id"):
            # Secret was removed from its project - warn user and require confirmation
            eprint("Warning: This secret was removed from its project (has no project_id).")
            eprint("Updating a secret without a project may fail due to Bitwarden API limitations.")
            eprint("")
            eprint("To update this secret, you must:")
            eprint("  1. Provide --project-ids to assign it to a project")
            eprint("  2. Confirm this operation (or use --force to skip confirmation)")
            eprint("")

            # Require --project-ids if secret has no project_id
            if not project_ids:
                eprint("Error: Secret has no project_id. You must provide --project-ids to update it.")
                eprint("Example:")
                eprint("  ./bwsm_secret.sh update --secret-id <uuid> --project-ids <project-uuid> [other-fields] --force")
                return 2

            # Require confirmation (unless --force)
            if not getattr(args, "force", False):
                if sys.stdin.isatty():
                    eprint("This will attempt to update a secret that was removed from its project.")
                    eprint("Continue? [y/N]: ", end="", flush=True)
                    try:
                        response = input().strip().lower()
                        if response not in ("y", "yes"):
                            eprint("Update cancelled.")
                            return 2
                    except (EOFError, KeyboardInterrupt):
                        eprint("\nUpdate cancelled.")
                        return 2
                else:
                    # Non-interactive, require --force
                    eprint("Error: --force flag is required for non-interactive update of secrets removed from projects.")
                    eprint("This prevents accidental operations that may fail due to API limitations.")
                    return 2

        # Handle value: CLI takes precedence, fallback to stdin
        secret_value = value
        if value is None:
            # Check if we need to update value (if other fields are being updated, we might want to preserve value)
            # But if user explicitly wants to update value, they should provide it
            # For now, if value is None, we'll use current value (from get_secret_for_update in update_secret)
            pass
        elif not value:
            # Empty string provided, try stdin
            try:
                secret_value = read_value_from_stdin()
            except RuntimeError as exc:
                msg = str(exc)
                if msg.startswith("VALUE_REQUIRED:"):
                    # If stdin is empty, we'll use current value
                    secret_value = None
                else:
                    raise

        # Update secret
        updated_secret_id = update_secret(
            access_token=access_token,
            secret_id=resolved_secret_id,
            organization_id=resolved_org_id,
            key=key,
            value=secret_value,
            note=note,
            project_ids=project_ids,
            debug=getattr(args, "debug", False),
        )

        # Output
        if args.json:
            # Fetch updated secret to get all fields for JSON output
            client = BitwardenClient()
            login_response = client.auth().login_access_token(access_token=access_token)
            if getattr(login_response, "success", False):
                updated_secret = get_secret_for_update(client, updated_secret_id, debug=False)
                note_json = f",\"note\":\"{updated_secret['note'].replace('\"', '\\\\\"')}\"" if updated_secret['note'] else ""
                project_id_json = f",\"project_id\":\"{updated_secret['project_id']}\"" if updated_secret['project_id'] else ""
                out = (
                    "{"
                    f"\"secret_id\":\"{updated_secret_id}\","
                    f"\"key\":\"{updated_secret['key'].replace('\"', '\\\\\"')}\","
                    f"\"value\":\"{updated_secret['value'].replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"')}\","
                    f"\"org_id\":\"{resolved_org_id}\"{note_json}{project_id_json}"
                    "}"
                )
                print(out)
            else:
                # Fallback: just print secret ID
                print(f'{{"secret_id":"{updated_secret_id}"}}')
        else:
            # secret ID only for easy piping
            print(updated_secret_id)

        return 0

    except RuntimeError as exc:
        msg = str(exc)

        if msg.startswith("AUTH_ERROR:"):
            eprint(f"Error: Authentication failed. {msg[len('AUTH_ERROR: '):]}")
            return 3

        if msg.startswith("ORG_ID_REQUIRED:"):
            eprint(f"Error: {msg[len('ORG_ID_REQUIRED: '):]}")
            eprint("When using --secret-name, --org-id is required.")
            return 2

        if msg.startswith("INVALID_ID:"):
            eprint(f"Error: {msg[len('INVALID_ID: '):]}")
            return 2

        if msg.startswith("NOT_FOUND:"):
            error_detail = msg[len('NOT_FOUND: '):]
            eprint(f"Error: Secret not found. {error_detail}")
            return 4

        if msg.startswith("LIST_ERROR:"):
            eprint(f"Error: Failed to list secrets. {msg[len('LIST_ERROR: '):]}")
            return 5

        if msg.startswith("MULTIPLE_SECRETS:") or msg.startswith("MULTIPLE_SECRETS_UPDATE:"):
            error_msg = msg[len('MULTIPLE_SECRETS_UPDATE: '):] if msg.startswith('MULTIPLE_SECRETS_UPDATE:') else msg[len('MULTIPLE_SECRETS: '):]
            eprint(f"Error: {error_msg}")
            return 2

        if msg.startswith("SDK_ERROR:"):
            eprint(f"Error: SDK error. {msg[len('SDK_ERROR: '):]}")
            return 5

        eprint(f"Error: {msg}")
        return 5

    except Exception as exc:
        # Check if it's a 404 error in the exception message
        exc_msg = str(exc)
        if "404" in exc_msg or "not found" in exc_msg.lower() or "Resource not found" in exc_msg:
            eprint(f"Error: Secret not found. {exc_msg}")
            return 4
        eprint(f"Unexpected error: {exc}")
        return 5


def handle_delete(args: argparse.Namespace) -> int:
    """Handle the 'delete' subcommand."""
    # Validate that at least one identifier is provided
    if not args.secret_id and not args.secret_name:
        eprint("Config error: missing secret identifier.")
        eprint("Provide at least one secret identifier via:")
        eprint("  - CLI:  --secret-id <uuid> [--secret-id <uuid> ...] (can specify multiple)")
        eprint("  - CLI:  --secret-name <name> --org-id <uuid> (only works if name is unique)")
        eprint("  - Env:  BWS_ACCESS_TOKEN and BWS_SECRET_ID (or BWS_SECRET_NAME)")
        eprint("  - Env:  BWS_ORG_ID (required for --secret-name)")
        return 2

    access_token, secret_ids, secret_name, org_id, source = resolve_delete_config(args)

    # Validate required parameters
    if not access_token:
        eprint("Config error: missing access token.")
        eprint("Provide access token via one of:")
        eprint("  - CLI:  --access-token <token>")
        eprint("  - Env:  BWS_ACCESS_TOKEN")
        return 2

    if secret_name and not org_id:
        eprint("Config error: missing organization ID.")
        eprint("Organization ID is required when using --secret-name.")
        eprint("Provide organization ID via one of:")
        eprint("  - CLI:  --org-id <uuid>")
        eprint("  - Env:  BWS_ORG_ID")
        return 2

    if not secret_ids and not secret_name:
        eprint("Config error: missing secret identifier.")
        eprint("Provide at least one secret identifier via:")
        eprint("  - CLI:  --secret-id <uuid> [--secret-id <uuid> ...]")
        eprint("  - CLI:  --secret-name <name> --org-id <uuid>")
        return 2

    try:
        # Resolve all secret identifiers to IDs
        resolved_secret_ids = resolve_secret_ids(
            access_token=access_token,
            secret_ids=secret_ids,
            secret_name=secret_name,
            org_id=org_id,
            debug=args.debug,
        )

        if not resolved_secret_ids:
            eprint("Error: No secrets resolved for deletion.")
            return 2

        # Confirmation prompt (unless --force)
        if not getattr(args, "force", False):
            if sys.stdin.isatty():
                count = len(resolved_secret_ids)
                secret_word = "secret" if count == 1 else "secrets"
                eprint(f"Delete {count} {secret_word}? [y/N]: ", end="", flush=True)
                try:
                    response = input().strip().lower()
                    if response not in ("y", "yes"):
                        eprint("Deletion cancelled.")
                        return 2
                except (EOFError, KeyboardInterrupt):
                    eprint("\nDeletion cancelled.")
                    return 2
            else:
                # Non-interactive, require --force
                eprint("Error: --force flag is required for non-interactive deletion.")
                eprint("This prevents accidental deletions in scripts.")
                return 2

        # Delete secrets
        # Ensure all IDs are strings (not UUID objects)
        resolved_secret_ids_str = [str(sid) if isinstance(sid, uuid.UUID) else sid for sid in resolved_secret_ids]

        deleted_ids = delete_secret(
            access_token=access_token,
            secret_ids=resolved_secret_ids_str,
            debug=args.debug,
        )

        # Output
        if args.json:
            # JSON output with deleted IDs and count
            ids_array = ",".join([f'"{did}"' for did in deleted_ids])
            out = (
                "{"
                f"\"deleted_secret_ids\":[{ids_array}],"
                f"\"count\":{len(deleted_ids)}"
                "}"
            )
            print(out)
        else:
            # Print deleted IDs, one per line (for easy piping)
            for did in deleted_ids:
                print(did)

        return 0

    except RuntimeError as exc:
        msg = str(exc)

        if msg.startswith("AUTH_ERROR:"):
            eprint(f"Error: Authentication failed. {msg[len('AUTH_ERROR: '):]}")
            return 3

        if msg.startswith("ORG_ID_REQUIRED:"):
            eprint(f"Error: {msg[len('ORG_ID_REQUIRED: '):]}")
            eprint("When using --secret-name, --org-id is required.")
            return 2

        if msg.startswith("INVALID_ID:"):
            eprint(f"Error: {msg[len('INVALID_ID: '):]}")
            return 2

        if msg.startswith("NOT_FOUND:"):
            error_detail = msg[len('NOT_FOUND: '):]
            eprint(f"Error: Secret(s) not found. {error_detail}")
            return 4

        if msg.startswith("LIST_ERROR:"):
            eprint(f"Error: Failed to list secrets. {msg[len('LIST_ERROR: '):]}")
            return 5

        if msg.startswith("MULTIPLE_SECRETS:") or msg.startswith("MULTIPLE_SECRETS_DELETE:"):
            error_msg = msg[len('MULTIPLE_SECRETS_DELETE: '):] if msg.startswith('MULTIPLE_SECRETS_DELETE:') else msg[len('MULTIPLE_SECRETS: '):]
            eprint(f"Error: {error_msg}")
            return 2

        if msg.startswith("SDK_ERROR:"):
            eprint(f"Error: SDK error. {msg[len('SDK_ERROR: '):]}")
            return 5

        eprint(f"Error: {msg}")
        return 5

    except Exception as exc:
        # Check if it's a 404 error in the exception message
        exc_msg = str(exc)
        if "404" in exc_msg or "not found" in exc_msg.lower() or "Resource not found" in exc_msg:
            eprint(f"Error: Secret(s) not found. {exc_msg}")
            return 4
        eprint(f"Unexpected error: {exc}")
        return 5


def handle_list(args: argparse.Namespace) -> int:
    """Handle the 'list' subcommand."""
    access_token, org_id, project_id, key_pattern, source = resolve_list_config(args)

    # Validate required parameters
    if not access_token:
        eprint("Config error: missing access token.")
        eprint("Provide access token via one of:")
        eprint("  - CLI:  --access-token <token>")
        eprint("  - Env:  BWS_ACCESS_TOKEN")
        return 2

    if not org_id:
        eprint("Config error: missing organization ID.")
        eprint("Provide organization ID via one of:")
        eprint("  - CLI:  --org-id <uuid>")
        eprint("  - Env:  BWS_ORG_ID")
        return 2

    try:
        secrets = list_secrets(
            access_token=access_token,
            organization_id=org_id,
            project_id=project_id,
            key_pattern=key_pattern,
            debug=args.debug,
        )

        # Format output
        if args.json:
            output = format_secrets_json(secrets)
            print(output)
        else:
            output = format_secrets_table(secrets)
            print(output)

        return 0

    except RuntimeError as exc:
        msg = str(exc)

        if msg.startswith("AUTH_ERROR:"):
            eprint(f"Error: Authentication failed. {msg[len('AUTH_ERROR: '):]}")
            return 3

        if msg.startswith("LIST_ERROR:"):
            eprint(f"Error: Failed to list secrets. {msg[len('LIST_ERROR: '):]}")
            return 5

        if msg.startswith("INVALID_ID:"):
            eprint(f"Error: {msg[len('INVALID_ID: '):]}")
            return 2

        if msg.startswith("SDK_ERROR:"):
            eprint(f"Error: SDK error. {msg[len('SDK_ERROR: '):]}")
            return 5

        eprint(f"Error: {msg}")
        return 5

    except Exception as exc:
        eprint(f"Unexpected error: {exc}")
        return 5


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
