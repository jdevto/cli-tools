# install_terraform.sh

This script installs or uninstalls Terraform on Ubuntu, Red Hat, or Fedora-based systems.

## Usage

```bash
./install_terraform.sh [install|uninstall]
```

- **install** (default): Installs the latest Terraform version.
- **uninstall**: Removes Terraform from the system.

## Example Usage

To install Terraform:

```bash
./install_terraform.sh
```

To uninstall Terraform:

```bash
./install_terraform.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_terraform.sh) install
```

## Verification

After installation, check the Terraform version:

```bash
terraform version
```

## Supported Operating Systems

- Ubuntu (uses `apt` for package management)
- Red Hat / Fedora (uses `dnf` for package management)

## Error Handling

- If Terraform is already installed, the script will skip reinstallation.
- If an unsupported OS is detected, the script exits with an error message.

## Cleanup

- Temporary installation files are automatically removed after execution.
