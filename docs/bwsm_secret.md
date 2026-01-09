# bwsm_secret.sh

This script manages secrets in Bitwarden Secrets Manager using the Bitwarden SDK. It handles prerequisite installation (Python and bitwarden_sdk) and works both locally and when executed from a GitHub URL.

## Usage

```bash
./bwsm_secret.sh [subcommand] [options]
```

### Subcommands

- `get` - Get a secret value (default if no subcommand provided)
- `create` - Create a new secret (coming soon)
- `update` - Update an existing secret (coming soon)
- `delete` - Delete secret(s) (coming soon)
- `list` - List all secrets (coming soon)

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

### Configuration Sources

The script supports multiple configuration sources (checked in priority order):

#### 1. Command-Line Arguments (Highest Priority)

```bash
./bwsm_secret.sh get --secret-id <uuid> --access-token "$BWS_ACCESS_TOKEN"
```

#### 2. Environment Variables

```bash
export BWS_ACCESS_TOKEN="..."
export BWS_SECRET_ID="..."
export BWS_ORG_ID="..."  # Optional, for organization-level secrets (or use BW_ORGANIZATION_ID)
./bwsm_secret.sh get
```

**Note**: The script supports both `BWS_ORG_ID` (standard) and `BW_ORGANIZATION_ID` (legacy) for organization ID.

### Options (Get Subcommand)

- `--secret-id <uuid>`: Secret ID (UUID format required) to fetch
- `--secret-name <name>`: Secret name/key to fetch (requires `--org-id`)
- `--access-token <token>`: Bitwarden Secrets Manager access token (prefer env var `BWS_ACCESS_TOKEN`)
- `--org-id <uuid>`: Organization ID (UUID) - required when using `--secret-name`, optional otherwise (prefer env var `BWS_ORG_ID` or `BW_ORGANIZATION_ID`)
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

#### JSON Output

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

## Exit Codes

- `0`: Success
- `2`: Configuration/usage error (missing credentials, invalid subcommand)
- `3`: Authentication error
- `4`: Secret not found
- `5`: SDK/runtime error

## Error Handling

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
- Future subcommands (`create`, `update`, `delete`, `list`) will be added in upcoming releases
