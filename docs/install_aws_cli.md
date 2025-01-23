# install_aws_cli.sh

This script installs or uninstalls the AWS CLI on Ubuntu, Red Hat, or Fedora-based systems.

## Usage

```bash
./install_aws_cli.sh [install|uninstall]
```

- **install** (default): Installs the latest AWS CLI version.
- **uninstall**: Removes the AWS CLI from the system.

## Example Usage

To install AWS CLI:

```bash
./install_aws_cli.sh
```

To uninstall AWS CLI:

```bash
./install_aws_cli.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_aws_cli.sh) install
```

## Verification

After installation, check the AWS CLI version:

```bash
aws --version
```

## Supported Operating Systems

- Ubuntu (uses `apt` for package management)
- Red Hat / Fedora (uses `dnf` for package management)

## Error Handling

- If AWS CLI is already installed, the script will skip reinstallation.
- If an unsupported OS is detected, the script exits with an error message.

## Cleanup

- Temporary installation files are automatically removed after execution.
