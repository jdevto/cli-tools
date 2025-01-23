# install_aws_vault.sh

This script installs or uninstalls AWS Vault while ensuring AWS CLI is installed as a prerequisite. It also supports backend configuration for `file` or `pass`.

## Usage

```bash
./install_aws_vault.sh [install|uninstall] [backend: pass|file]
```

- **install** (default): Installs or updates AWS Vault.
- **uninstall**: Removes AWS Vault and dependencies.
- **backend**: (Optional) Specify `pass` or `file` as the AWS Vault backend (default: `pass`).

## Example Usage

To install AWS Vault with the default backend (`pass`):

```bash
./install_aws_vault.sh install
```

To install AWS Vault using the `file` backend:

```bash
./install_aws_vault.sh install file
```

To uninstall AWS Vault and dependencies:

```bash
./install_aws_vault.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_aws_vault.sh) install
```

## Verification

After installation, check the AWS Vault version:

```bash
aws-vault --version
```

## Backend Configuration

AWS Vault supports two backends for credential storage:

- **Pass Backend (Default)**: Uses `pass` with GPG encryption.
- **File Backend**: Stores credentials in an encrypted file.

To configure the file backend:

```bash
echo "export AWS_VAULT_BACKEND=file" >> "$HOME/.bashrc"
source "$HOME/.bashrc"
```

For the pass backend, `pinentry` and `pass` must be installed, and GPG must be initialized.

## Error Handling

- If AWS Vault is already installed, the script will skip reinstallation.
- If an unsupported OS is detected, the script exits with an error message.

## Cleanup

- Dependencies and temporary installation files are removed when uninstalled.
- Runs `apt autoremove` to clean up unused packages after uninstallation on Debian-based systems.
