# bwsm_secret.sh

This script manages secrets in Bitwarden Secrets Manager using the Bitwarden SDK. It handles prerequisite installation (Python and bitwarden_sdk) and works both locally and when executed from a GitHub URL.

## Usage

```bash
./bwsm_secret.sh [subcommand] [options]
```

### Subcommands

- `get` - Get a secret value (default if no subcommand provided)
- `create` - Create a new secret
- `update` - Update an existing secret
- `delete` - Delete secret(s)
- `list` - List all secrets

**Note**: For backward compatibility, if no subcommand is provided, `get` is assumed.

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/bwsm_secret.sh) get --secret-id <uuid> --access-token "$BWS_ACCESS_TOKEN"
```

Or without explicit subcommand (defaults to `get`):

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/bwsm_secret.sh) --secret-id <uuid> --access-token "$BWS_ACCESS_TOKEN"
```

## Get Subcommand

The `get` subcommand retrieves a secret value from Bitwarden Secrets Manager.

### Get Configuration Sources

The script supports multiple configuration sources (checked in priority order):

#### 1. Get: Command-Line Arguments (Highest Priority)

```bash
./bwsm_secret.sh get --secret-id <uuid> --access-token "$BWS_ACCESS_TOKEN"
```

#### 2. Get: Environment Variables

```bash
export BWS_ACCESS_TOKEN="..."
export BWS_SECRET_ID="..."
export BWS_ORG_ID="..."  # Optional, for organization-level secrets
./bwsm_secret.sh get
```

**Note**: The script uses `BWS_ORG_ID` environment variable for organization ID.

### Options (Get Subcommand)

- `--secret-id <uuid>`: Secret ID (UUID format required) to fetch
- `--secret-name <name>`: Secret name/key to fetch (requires `--org-id`)
- `--access-token <token>`: Bitwarden Secrets Manager access token (prefer env var `BWS_ACCESS_TOKEN`)
- `--org-id <uuid>`: Organization ID (UUID) - required when using `--secret-name`, optional otherwise (prefer env var `BWS_ORG_ID`)
- `--json`: Print JSON output (includes secret_id/secret_name, source, value)
- `--debug`: Print debug logs to stderr

**Note**: Use `--secret-id` for UUIDs and `--secret-name` for names. `--secret-id` must be a valid UUID format.

### Example Usage (Get)

#### Using Secret ID (UUID)

```bash
./bwsm_secret.sh get --secret-id "123e4567-e89b-12d3-a456-426614174000" --access-token "$BWS_ACCESS_TOKEN"
```

Or without explicit subcommand (backward compatible):

```bash
./bwsm_secret.sh --secret-id "123e4567-e89b-12d3-a456-426614174000" --access-token "$BWS_ACCESS_TOKEN"
```

#### Using Secret Name

```bash
./bwsm_secret.sh get --secret-name "bw-example-secret" --access-token "$BWS_ACCESS_TOKEN" --org-id "$BWS_ORG_ID"
```

#### Using Environment Variables

```bash
export BWS_ACCESS_TOKEN="your-access-token"
export BWS_SECRET_ID="123e4567-e89b-12d3-a456-426614174000"
export BWS_ORG_ID="123e4567-e89b-12d3-a456-426614174000"  # Optional
./bwsm_secret.sh get
```

**Note**: Organization ID is optional and is only used for reference/debugging. The organization is scoped via the access token.

#### Get: JSON Output

```bash
./bwsm_secret.sh get --secret-id <uuid> --access-token "$BWS_ACCESS_TOKEN" --json
```

Output:

```json
{"secret_id":"123e4567-e89b-12d3-a456-426614174000","source":"cli","value":"secret-value"}
```

#### Debug Mode

```bash
./bwsm_secret.sh get --secret-id <uuid> --access-token "$BWS_ACCESS_TOKEN" --debug
```

## Create Subcommand

The `create` subcommand creates a new secret in Bitwarden Secrets Manager.

### Create Configuration Sources

The script supports multiple configuration sources (checked in priority order):

#### 1. Create: Command-Line Arguments (Highest Priority)

```bash
./bwsm_secret.sh create --key "my-secret" --value "secret-value" --org-id "$BWS_ORG_ID" --access-token "$BWS_ACCESS_TOKEN"
```

#### 2. Create: Environment Variables

```bash
export BWS_ACCESS_TOKEN="..."
export BWS_ORG_ID="..."
./bwsm_secret.sh create --key "my-secret" --value "secret-value" --project-ids "$PROJECT_ID"
```

**Note**: `--project-ids` is always required, even when using environment variables for other parameters.

**Note**: The script uses `BWS_ORG_ID` environment variable for organization ID.

### Options (Create Subcommand)

- `--key <name>`: Secret key/name (required)
- `--value <value>`: Secret value (optional, will read from stdin if not provided)
- `--org-id <uuid>`: Organization ID (UUID format, required) (prefer env var `BWS_ORG_ID`)
- `--project-ids <uuid1[,uuid2,...]>`: Comma-separated list of project IDs (UUIDs, **required**). Secrets must be created within a project, not at the organization level.
- `--note <text>`: Note/description for the secret (optional)
- `--access-token <token>`: Bitwarden Secrets Manager access token (prefer env var `BWS_ACCESS_TOKEN`)
- `--allow-duplicate`: Allow creating a secret even if one with the same key already exists in the project(s). By default, duplicate keys are not allowed.
- `--json`: Print JSON output (includes secret_id, key, org_id, note, project_ids) instead of just secret ID
- `--debug`: Print debug logs to stderr

### Example Usage (Create)

**Important**: Secrets must be created within a project, not at the organization level. The `--project-ids` parameter is **required** for all create operations.

#### Basic Create

```bash
./bwsm_secret.sh create --key "my-secret" --value "secret-value" --org-id "$BWS_ORG_ID" --project-ids "$PROJECT_ID" --access-token "$BWS_ACCESS_TOKEN"
```

#### Using Stdin Value

```bash
echo "secret-value" | ./bwsm_secret.sh create --key "my-secret" --org-id "$BWS_ORG_ID" --project-ids "$PROJECT_ID" --access-token "$BWS_ACCESS_TOKEN"
```

#### With Note

```bash
./bwsm_secret.sh create --key "api-key" --value "key-value" --org-id "$BWS_ORG_ID" --project-ids "$PROJECT_ID" --note "API key for production service" --access-token "$BWS_ACCESS_TOKEN"
```

#### With Multiple Project IDs

```bash
./bwsm_secret.sh create --key "db-password" --value "password123" --org-id "$BWS_ORG_ID" --project-ids "proj-id-1,proj-id-2" --access-token "$BWS_ACCESS_TOKEN"
```

#### Allow Duplicate Keys

By default, the script prevents creating secrets with duplicate keys in the same project(s). Use `--allow-duplicate` to override:

```bash
./bwsm_secret.sh create --key "my-secret" --value "new-value" --org-id "$BWS_ORG_ID" --project-ids "$PROJECT_ID" --allow-duplicate --access-token "$BWS_ACCESS_TOKEN"
```

#### Create: JSON Output

```bash
./bwsm_secret.sh create --key "my-secret" --value "value" --org-id "$BWS_ORG_ID" --project-ids "$PROJECT_ID" --json --access-token "$BWS_ACCESS_TOKEN"
```

Output:

```json
{"secret_id":"123e4567-e89b-12d3-a456-426614174000","key":"my-secret","org_id":"...","note":"Optional note","project_ids":["..."]}
```

#### Create: Using Environment Variables

```bash
export BWS_ACCESS_TOKEN="your-access-token"
export BWS_ORG_ID="123e4567-e89b-12d3-a456-426614174000"
echo "secret-value" | ./bwsm_secret.sh create --key "my-secret" --project-ids "$PROJECT_ID"
```

**Note**: `--project-ids` is always required, even when using environment variables for other parameters.

### Output (Create)

By default, the `create` subcommand prints **only the secret ID** to stdout (suitable for piping):

```bash
SECRET_ID=$(./bwsm_secret.sh create --key "my-secret" --value "value" --org-id "$BWS_ORG_ID" --project-ids "$PROJECT_ID" --access-token "$BWS_ACCESS_TOKEN")
echo "Created secret: $SECRET_ID"
```

Use `--json` for structured output with metadata.

### Error Handling (Create)

#### Missing Required Parameters

```bash
$ ./bwsm_secret.sh create --key "my-secret"
Config error: missing organization ID.
Provide organization ID via one of:
  - CLI:  --org-id <uuid>
  - Env:  BWS_ORG_ID
```

#### Missing Project IDs

```bash
$ ./bwsm_secret.sh create --key "my-secret" --org-id "$BWS_ORG_ID" --access-token "$BWS_ACCESS_TOKEN"
Config error: missing project IDs.
Secrets must be created within a project, not at the organization level.
Provide at least one project ID via:
  - CLI:  --project-ids <uuid1>[,uuid2,...]
Note: Multiple project IDs can be provided as a comma-separated list.
```

#### Missing Value

```bash
$ ./bwsm_secret.sh create --key "my-secret" --org-id "$BWS_ORG_ID" --project-ids "$PROJECT_ID" --access-token "$BWS_ACCESS_TOKEN"
Error: Secret value is required. Provide via --value or pipe to stdin.
```

#### Invalid UUID Format

```bash
$ ./bwsm_secret.sh create --key "my-secret" --value "value" --org-id "invalid-uuid" --project-ids "$PROJECT_ID" --access-token "$BWS_ACCESS_TOKEN"
Error: Organization ID must be a valid UUID format. Got: 'invalid-uuid'.
```

#### Duplicate Secret Key

By default, the script prevents creating secrets with duplicate keys in the same project(s):

```bash
$ ./bwsm_secret.sh create --key "my-secret" --value "value" --org-id "$BWS_ORG_ID" --project-ids "$PROJECT_ID" --access-token "$BWS_ACCESS_TOKEN"
Error: A secret with key 'my-secret' already exists in one or more of the specified projects (secret ID: 123e4567-e89b-12d3-a456-426614174000). Use --allow-duplicate to create anyway.
```

To allow duplicates, use the `--allow-duplicate` flag:

```bash
./bwsm_secret.sh create --key "my-secret" --value "value" --org-id "$BWS_ORG_ID" --project-ids "$PROJECT_ID" --allow-duplicate --access-token "$BWS_ACCESS_TOKEN"
```

#### Resource Not Found (404)

If you get a 404 error, it typically means:

- The organization ID or project ID is invalid or doesn't exist
- The access token doesn't have permission for the organization/project
- **Most commonly**: You're trying to create a secret at the organization level instead of within a project

```bash
$ ./bwsm_secret.sh create --key "my-secret" --value "value" --org-id "$BWS_ORG_ID" --access-token "$BWS_ACCESS_TOKEN"
Error: Resource not found. [error details]
This may indicate:
  - Invalid organization ID or project ID
  - Organization or project doesn't exist
  - Access token doesn't have permission
  - Note: Secrets must be created within a project, not at the organization level
```

## Delete Subcommand

The `delete` subcommand removes secrets from Bitwarden Secrets Manager.

### Delete Configuration Sources

The script supports multiple configuration sources (checked in priority order):

#### 1. Delete: Command-Line Arguments (Highest Priority)

```bash
./bwsm_secret.sh delete --secret-id <uuid> --access-token "$BWS_ACCESS_TOKEN" --force
```

#### 2. Delete: Environment Variables

```bash
export BWS_ACCESS_TOKEN="..."
export BWS_SECRET_ID="..."
./bwsm_secret.sh delete --force
```

**Note**: The script uses `BWS_ORG_ID` environment variable for organization ID when using `--secret-name`.

### Options (Delete Subcommand)

- `--secret-id <uuid>`: Secret ID (UUID format) to delete. Can be specified multiple times or comma-separated for batch deletion.
- `--secret-name <name>`: Secret name/key to delete (requires `--org-id`, only works if name is unique)
- `--access-token <token>`: Bitwarden Secrets Manager access token (prefer env var `BWS_ACCESS_TOKEN`)
- `--org-id <uuid>`: Organization ID (UUID) - required when using `--secret-name` (prefer env var `BWS_ORG_ID`)
- `--force`: Skip confirmation prompt (required for non-interactive use)
- `--json`: Print JSON output (includes deleted_secret_ids, count) instead of just IDs
- `--debug`: Print debug logs to stderr

**Important**: The `--force` flag is required for non-interactive deletion to prevent accidental deletions in scripts.

### Example Usage (Delete)

#### Delete by Secret ID

```bash
./bwsm_secret.sh delete --secret-id "123e4567-e89b-12d3-a456-426614174000" --access-token "$BWS_ACCESS_TOKEN" --force
```

#### Delete Multiple Secrets by ID

```bash
./bwsm_secret.sh delete --secret-id "uuid1" --secret-id "uuid2" --access-token "$BWS_ACCESS_TOKEN" --force
```

Or comma-separated:

```bash
./bwsm_secret.sh delete --secret-id "uuid1,uuid2,uuid3" --access-token "$BWS_ACCESS_TOKEN" --force
```

#### Delete by Secret Name

```bash
./bwsm_secret.sh delete --secret-name "my-secret" --org-id "$BWS_ORG_ID" --access-token "$BWS_ACCESS_TOKEN" --force
```

#### Delete: JSON Output

```bash
./bwsm_secret.sh delete --secret-id "uuid" --access-token "$BWS_ACCESS_TOKEN" --force --json
```

Output:

```json
{"deleted_secret_ids":["123e4567-e89b-12d3-a456-426614174000"],"count":1}
```

#### Delete: Interactive Confirmation

When running interactively (TTY), you'll be prompted for confirmation unless `--force` is used:

```bash
./bwsm_secret.sh delete --secret-id "uuid" --access-token "$BWS_ACCESS_TOKEN"
# Prompts: Delete 1 secret? [y/N]:
```

### Output (Delete)

By default, the `delete` subcommand prints **only the deleted secret IDs** to stdout (one per line, suitable for piping):

```bash
DELETED_IDS=$(./bwsm_secret.sh delete --secret-id "uuid1" --secret-id "uuid2" --access-token "$BWS_ACCESS_TOKEN" --force)
echo "Deleted: $DELETED_IDS"
```

Use `--json` for structured output with metadata.

### Error Handling (Delete)

#### Delete: Missing Required Parameters

```bash
$ ./bwsm_secret.sh delete
Config error: missing secret identifier.
Provide at least one secret identifier via:
  - CLI:  --secret-id <uuid> [--secret-id <uuid> ...] (can specify multiple)
  - CLI:  --secret-name <name> --org-id <uuid> (only works if name is unique)
  - Env:  BWS_ACCESS_TOKEN and BWS_SECRET_ID (or BWS_SECRET_NAME)
  - Env:  BWS_ORG_ID (required for --secret-name)
```

#### Missing Force Flag (Non-Interactive)

```bash
$ echo "test" | ./bwsm_secret.sh delete --secret-id "uuid" --access-token "$BWS_ACCESS_TOKEN"
Error: --force flag is required for non-interactive deletion.
This prevents accidental deletions in scripts.
```

#### Delete: Invalid UUID Format

```bash
$ ./bwsm_secret.sh delete --secret-id "invalid-uuid" --access-token "$BWS_ACCESS_TOKEN" --force
Error: Secret ID must be a valid UUID format. Got: 'invalid-uuid'.
```

#### Secret Not Found (404)

```bash
$ ./bwsm_secret.sh delete --secret-id "00000000-0000-0000-0000-000000000000" --access-token "$BWS_ACCESS_TOKEN" --force
Error: Secret(s) not found. [error details]
```

#### Multiple Secrets with Same Name (Safety)

For safety, deletion by name is only allowed when the secret name is unique. If multiple secrets share the same name, you must use `--secret-id` explicitly:

```bash
$ ./bwsm_secret.sh delete --secret-name "my-secret" --org-id "$BWS_ORG_ID" --access-token "$BWS_ACCESS_TOKEN" --force
Error: Cannot delete by name when multiple secrets share the same name. Found 12 secrets with name/key 'my-secret':
  - Secret ID: <uuid1>, Project ID: <project1>
  - Secret ID: <uuid2>, Project ID: <project2>
  ...

For safety, use --secret-id <uuid> to explicitly specify which secret to delete.
```

**Note**: Deletion by name is only allowed when the secret name is unique. If multiple secrets share the same name, you must use `--secret-id` explicitly. This prevents accidental deletion of the wrong secret.

## Update Subcommand

The `update` subcommand modifies existing secrets in Bitwarden Secrets Manager. You can update the secret key, value, note, and project associations. Only provided fields are updated; existing values are preserved for omitted fields.

### Update Configuration Sources

The script supports multiple configuration sources (checked in priority order):

#### 1. Update: Command-Line Arguments (Highest Priority)

```bash
./bwsm_secret.sh update --secret-id <uuid> --key "new-key" --value "new-value" --access-token "$BWS_ACCESS_TOKEN"
```

#### 2. Update: Environment Variables

```bash
export BWS_ACCESS_TOKEN="..."
export BWS_SECRET_ID="..."
./bwsm_secret.sh update --key "new-key" --value "new-value"
```

**Note**: The script uses `BWS_ORG_ID` environment variable for organization ID.

### Options (Update Subcommand)

- `--secret-id <uuid>`: Secret ID (UUID format) to update
- `--secret-name <name>`: Secret name/key to update (requires `--org-id`, only works if name is unique)
- `--key <name>`: New secret key/name (optional, only updates if provided)
- `--value <value>`: New secret value (optional, can read from stdin if not provided)
- `--note <note>`: New note/description (optional, only updates if provided)
- `--project-ids <uuid1>[,uuid2,...]`: New project IDs (comma-separated, optional, only updates if provided)
- `--project-id-filter <uuid>`: Project ID to disambiguate when multiple secrets share the same name (for --secret-name lookup only)
- `--access-token <token>`: Bitwarden Secrets Manager access token (prefer env var `BWS_ACCESS_TOKEN`)
- `--org-id <uuid>`: Organization ID (UUID) - required when using `--secret-name` (prefer env var `BWS_ORG_ID`)
- `--json`: Print JSON output (includes secret_id, key, value, note, project_id) instead of just secret ID
- `--debug`: Print debug logs to stderr

### Update Examples

#### Update by Secret ID

```bash
# Update only the value
./bwsm_secret.sh update --secret-id <uuid> --value "new-value" --access-token "$BWS_ACCESS_TOKEN"

# Update key and value
./bwsm_secret.sh update --secret-id <uuid> --key "new-key" --value "new-value" --access-token "$BWS_ACCESS_TOKEN"

# Update note only
./bwsm_secret.sh update --secret-id <uuid> --note "Updated description" --access-token "$BWS_ACCESS_TOKEN"

# Update project IDs
./bwsm_secret.sh update --secret-id <uuid> --project-ids <uuid1>,<uuid2> --access-token "$BWS_ACCESS_TOKEN"

# Update multiple fields
./bwsm_secret.sh update --secret-id <uuid> --key "new-key" --value "new-value" --note "New note" --access-token "$BWS_ACCESS_TOKEN"
```

#### Update by Secret Name (Unique Name Only)

```bash
# Update value by name (only works if name is unique)
./bwsm_secret.sh update --secret-name "my-secret" --org-id "$BWS_ORG_ID" --value "new-value" --access-token "$BWS_ACCESS_TOKEN"
```

**Note**: Update by name is only allowed when the secret name is unique. If multiple secrets share the same name, you must use `--secret-id` explicitly.

#### Update with Value from Stdin

```bash
# Read value from stdin
echo "new-value" | ./bwsm_secret.sh update --secret-id <uuid> --access-token "$BWS_ACCESS_TOKEN"

# Or pipe from another command
cat secret.txt | ./bwsm_secret.sh update --secret-id <uuid> --access-token "$BWS_ACCESS_TOKEN"
```

#### Update: JSON Output

```bash
./bwsm_secret.sh update --secret-id <uuid> --key "new-key" --value "new-value" --access-token "$BWS_ACCESS_TOKEN" --json
```

Output:

```json
{"secret_id":"<uuid>","key":"new-key","value":"new-value","org_id":"<uuid>","note":"...","project_id":"<uuid>"}
```

### Partial Updates

The update command supports partial updates. Only fields that are explicitly provided are updated; all other fields remain unchanged:

```bash
# Only update the value, keep key and note unchanged
./bwsm_secret.sh update --secret-id <uuid> --value "new-value" --access-token "$BWS_ACCESS_TOKEN"

# Only update the key, keep value and note unchanged
./bwsm_secret.sh update --secret-id <uuid> --key "new-key" --access-token "$BWS_ACCESS_TOKEN"
```

### Update Error Handling

#### Update: Missing Required Parameters

```bash
$ ./bwsm_secret.sh update
Config error: missing secret identifier.
Provide at least one secret identifier via:
  - CLI:  --secret-id <uuid>
  - CLI:  --secret-name <name> --org-id <uuid>
```

#### Update: No Update Fields Provided

```bash
$ ./bwsm_secret.sh update --secret-id <uuid> --access-token "$BWS_ACCESS_TOKEN"
Config error: no update fields provided.
Provide at least one field to update via:
  - CLI:  --key <new-key>
  - CLI:  --value <new-value> (or pipe to stdin)
  - CLI:  --note <new-note>
  - CLI:  --project-ids <uuid1>[,uuid2,...]
```

### Update: Invalid UUID Format

```bash
$ ./bwsm_secret.sh update --secret-id "invalid-uuid" --key "new-key" --access-token "$BWS_ACCESS_TOKEN"
Error: Secret ID must be a valid UUID format. Got: 'invalid-uuid'.
```

### Update: Secret Not Found (404)

```bash
$ ./bwsm_secret.sh update --secret-id "00000000-0000-0000-0000-000000000000" --key "new-key" --access-token "$BWS_ACCESS_TOKEN"
Error: Secret not found. [error details]
```

#### Update: Multiple Secrets with Same Name (Safety)

For safety, update by name is only allowed when the secret name is unique. If multiple secrets share the same name, you must use `--secret-id` explicitly:

```bash
$ ./bwsm_secret.sh update --secret-name "my-secret" --org-id "$BWS_ORG_ID" --value "new-value" --access-token "$BWS_ACCESS_TOKEN"
Error: Cannot update by name when multiple secrets share the same name. Found 12 secrets with name/key 'my-secret':
  - Secret ID: <uuid1>, Project ID: <project1>
  - Secret ID: <uuid2>, Project ID: <project2>
  ...

For safety, use --secret-id <uuid> to explicitly specify which secret to update.
```

**Note**: Even with `--project-id-filter`, update by name is not allowed when duplicates exist. This prevents accidental update of the wrong secret. Always use `--secret-id` when multiple secrets share the same name.

## List Subcommand

The `list` subcommand displays all secrets in a Bitwarden organization. You can filter by project ID and/or key pattern, and output in table (default) or JSON format.

### List Configuration Sources

The script supports multiple configuration sources (checked in priority order):

#### 1. List: Command-Line Arguments (Highest Priority)

```bash
./bwsm_secret.sh list --org-id <uuid> --access-token "$BWS_ACCESS_TOKEN"
```

#### 2. List: Environment Variables

```bash
export BWS_ACCESS_TOKEN="..."
export BWS_ORG_ID="..."
./bwsm_secret.sh list
```

### Options (List Subcommand)

- `--access-token <token>`: Bitwarden Secrets Manager access token (prefer env var `BWS_ACCESS_TOKEN`)
- `--org-id <uuid>`: Organization ID (UUID, required) (prefer env var `BWS_ORG_ID`)
- `--project-id <uuid>`: Filter by project ID (UUID, optional). Note: Requires fetching each secret individually, which is slower.
- `--key-pattern <pattern>`: Filter by key name pattern (substring match, case-sensitive, optional)
- `--json`: Print JSON output (array of secret objects) instead of table format
- `--debug`: Print debug logs to stderr

### List Examples

#### Basic List

```bash
# List all secrets in the organization
./bwsm_secret.sh list --org-id "$BWS_ORG_ID" --access-token "$BWS_ACCESS_TOKEN"
```

Output (table format):

```table
ID                                    Key                    Project ID                            Note
------------------------------------  --------------------  ------------------------------------  ------------------------------
550e8400-e29b-41d4-a716-446655440000  my-secret             a1b2c3d4-e5f6-7890-abcd-ef1234567890  Production secret
660e8400-e29b-41d4-a716-446655440001  another-secret        b2c3d4e5-f6a7-8901-bcde-f12345678901  Development secret
```

#### Filter by Project ID

```bash
# List only secrets in a specific project
./bwsm_secret.sh list --org-id "$BWS_ORG_ID" --project-id "$PROJECT_ID" --access-token "$BWS_ACCESS_TOKEN"
```

**Note**: Filtering by `--project-id` requires fetching each secret individually to check its project association, which is slower than listing all secrets. This is because the Bitwarden SDK's `list()` API doesn't return project information.

#### Filter by Key Pattern

```bash
# List secrets whose keys contain "api"
./bwsm_secret.sh list --org-id "$BWS_ORG_ID" --key-pattern "api" --access-token "$BWS_ACCESS_TOKEN"
```

#### Combine Filters

```bash
# List secrets in a project whose keys contain "prod"
./bwsm_secret.sh list --org-id "$BWS_ORG_ID" --project-id "$PROJECT_ID" --key-pattern "prod" --access-token "$BWS_ACCESS_TOKEN"
```

#### List: JSON Output

```bash
./bwsm_secret.sh list --org-id "$BWS_ORG_ID" --access-token "$BWS_ACCESS_TOKEN" --json
```

Output:

```json
[
  {"secret_id":"550e8400-e29b-41d4-a716-446655440000","key":"my-secret","project_id":"a1b2c3d4-e5f6-7890-abcd-ef1234567890","note":"Production secret"},
  {"secret_id":"660e8400-e29b-41d4-a716-446655440001","key":"another-secret","project_id":"b2c3d4e5-f6a7-8901-bcde-f12345678901","note":"Development secret"}
]
```

### List Error Handling

#### List: Missing Required Parameters

```bash
$ ./bwsm_secret.sh list
Config error: missing organization ID.
Provide organization ID via one of:
  - CLI:  --org-id <uuid>
  - Env:  BWS_ORG_ID
```

#### List: Invalid UUID Format

```bash
$ ./bwsm_secret.sh list --org-id "invalid-uuid" --access-token "$BWS_ACCESS_TOKEN"
Error: Organization ID must be a valid UUID format. Got: 'invalid-uuid'.
```

#### List: Authentication Error

```bash
$ ./bwsm_secret.sh list --org-id "$BWS_ORG_ID" --access-token "invalid"
Error: Authentication failed. Invalid access token
```

#### List: Empty Results

If filtering results in no secrets, the command returns exit code 0 (success) with empty output:

```bash
$ ./bwsm_secret.sh list --org-id "$BWS_ORG_ID" --key-pattern "nonexistent" --access-token "$BWS_ACCESS_TOKEN"
No secrets found.
```

### Performance Note

Filtering by `--project-id` requires fetching each secret individually via `get()` calls to check its project association, as the SDK's `list()` API doesn't return project information. This means:

- **Without `--project-id` filter**: Fast - single API call to list all secrets
- **With `--project-id` filter**: Slower - one API call per secret to check project association

For large organizations with many secrets, consider using `--key-pattern` first to reduce the number of secrets before applying the project filter.

## Direct Python Usage

You can also run the Python script directly:

```bash
python3 scripts/bwsm_secret.py get --secret-id <uuid> --access-token "$BWS_ACCESS_TOKEN"
```

## Prerequisites

The bash wrapper automatically handles prerequisites:

- **Python 3**: Automatically installed via `install_python.sh` if not found
- **bitwarden_sdk**: Automatically installed via pip if not found

### Manual Installation

If automatic installation fails, install manually:

```bash
# Install Python (if needed)
./scripts/install_python.sh install

# Install bitwarden_sdk
python3 -m pip install bitwarden-sdk
```

## Output

By default, the `get` subcommand prints **only the secret value** to stdout (suitable for piping):

```bash
SECRET=$(./bwsm_secret.sh get --secret-id <uuid> --access-token "$BWS_ACCESS_TOKEN")
echo "Secret: $SECRET"
```

Use `--json` for structured output with metadata.

## Exit Codes (All Subcommands)

- `0`: Success
- `2`: Configuration/usage error (missing credentials, invalid subcommand)
- `3`: Authentication error
- `4`: Secret not found
- `5`: SDK/runtime error

## Error Handling (Get Subcommand)

### Missing Credentials

```bash
$ ./bwsm_secret.sh get
Config error: missing Bitwarden credentials.
Provide both access token and secret id via one of:
  - CLI:  --access-token ... --secret-id ...
  - Env:  BWS_ACCESS_TOKEN and BWS_SECRET_ID
```

### Invalid Subcommand

```bash
$ ./bwsm_secret.sh invalid
Error: Invalid subcommand 'invalid'.
Valid subcommands: get, create, update, delete, list
```

### Authentication Error

```bash
$ ./bwsm_secret.sh get --secret-id <uuid> --access-token "invalid"
Error: Authentication failed. Invalid access token
```

### Secret Not Found

```bash
$ ./bwsm_secret.sh get --secret-id "invalid-uuid" --access-token "$BWS_ACCESS_TOKEN"
Error: Secret fetch failed. Secret not found
```

## Troubleshooting

### Python Not Found

If Python installation fails:

```bash
# Check if Python is installed
python3 --version

# Manually install Python
./scripts/install_python.sh install

# Verify installation
which python3
```

### bitwarden_sdk Installation Fails

If bitwarden_sdk installation fails:

```bash
# Try manual installation
python3 -m pip install bitwarden-sdk

# Or with pip3
pip3 install bitwarden-sdk

# Verify installation
python3 -c "import bitwarden_sdk; print('OK')"
```

### Script Not Found When Running from URL

If running from GitHub URL and Python script download fails:

- Check internet connectivity
- Verify GitHub URL is accessible: `curl -I https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/bwsm_secret.py`
- Try running locally instead

### Permission Denied

Ensure scripts are executable:

```bash
chmod +x scripts/bwsm_secret.sh
chmod +x scripts/bwsm_secret.py
```

## URL Execution

The script detects when it's being run from a URL and automatically downloads the Python script:

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/bwsm_secret.sh) get --secret-id <uuid> --access-token "$BWS_ACCESS_TOKEN"
```

When executed from URL:

- Python script is downloaded to `/tmp/bwsm_secret.py`
- `install_python.sh` is downloaded if Python is missing
- Temporary files are cleaned up on exit

## Additional Resources

- **Bitwarden Secrets Manager**: <https://bitwarden.com/products/secrets-manager/>
- **Bitwarden SDK**: <https://github.com/bitwarden/sdk>
- **Bitwarden SDK Python**: <https://pypi.org/project/bitwarden-sdk/>

## Notes

- The script preserves all command-line arguments when passing to Python
- Environment variables are inherited by the Python process
- The script uses `exec` to replace the bash process with Python (preserves exit codes)
- Temporary files are automatically cleaned up on exit
- The script works in both local and URL execution contexts
- For backward compatibility, omitting the subcommand defaults to `get`
