# install_ssm_plugin.sh

This script installs or uninstalls the AWS SSM Session Manager Plugin on various Linux distributions and macOS.

## Usage

```bash
./install_ssm_plugin.sh [install|uninstall]
```

- **install** (default): Installs the AWS SSM Session Manager Plugin.
- **uninstall**: Removes the AWS SSM Session Manager Plugin from the system.

## Example Usage

To install the AWS SSM Session Manager Plugin:

```bash
./install_ssm_plugin.sh
```

To uninstall the AWS SSM Session Manager Plugin:

```bash
./install_ssm_plugin.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_ssm_plugin.sh) install
```

## Verification

After installation, check if the plugin is installed:

```bash
session-manager-plugin --version
```

## Supported Operating Systems

- **Debian/Ubuntu** (uses `apt` or `apt-get` for package management)
- **Red Hat / Fedora / Amazon Linux 2** (uses `yum` for package management)
- **Amazon Linux 2023 / RHEL 8/9** (uses `dnf` for package management)
- **Alpine Linux** (uses `apk` for package management)
- **macOS** (downloads and installs the bundled zip package)

## Error Handling

- If the AWS SSM Session Manager Plugin is already installed, the script will skip reinstallation.
- If an unsupported OS is detected, the script exits with an error message.
- The script will automatically clean up temporary installation files.

## Cleanup

- Temporary installation files (`.deb`, `.rpm`, `.zip`) are automatically removed after execution.
