# install_ssm_agent.sh

This script installs or uninstalls the AWS Systems Manager (SSM) Agent on various Linux distributions, macOS, and Windows.

## Usage

```bash
./install_ssm_agent.sh [install|uninstall]
```

- **install** (default): Installs the AWS SSM Agent.
- **uninstall**: Removes the AWS SSM Agent from the system.

## Example Usage

To install the AWS SSM Agent:

```bash
./install_ssm_agent.sh
```

To uninstall the AWS SSM Agent:

```bash
./install_ssm_agent.sh uninstall
```

## ⚠️ Important Warning

**If you are currently connected via SSM Session Manager**, uninstalling the SSM agent will **disconnect your session**.

- If you need to uninstall the SSM agent, ensure you have an alternative connection method (SSH, EC2 Instance Connect, or console access)
- The uninstall process stops and removes the SSM agent service, which will terminate any active SSM Session Manager connections

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_ssm_agent.sh) install
```

## Verification

After installation, check if the SSM agent is installed and running:

```bash
amazon-ssm-agent --version
```

On Linux systems, verify the service status:

```bash
systemctl status amazon-ssm-agent
```

## Supported Operating Systems

- **Debian/Ubuntu** (uses `apt` or `apt-get` for package management)
- **Amazon Linux 2023, RHEL 8/9, Fedora** (uses `dnf` for package management, attempts repository installation first)
- **Amazon Linux 2, RHEL 7, CentOS 7** (uses `yum` for package management, attempts repository installation first)
- **Alpine Linux** (uses `apk` for package management)
- **macOS** (downloads and installs the `.pkg` package)
- **Windows** (downloads and installs the `.msi` package via MSI installer)

## Supported Architectures

- **Linux**: x86_64 (amd64), aarch64 (arm64)
- **macOS**: x86_64 (amd64), arm64
- **Windows**: x86_64 (amd64)

## Features

- Automatically detects package manager and operating system
- Installs `curl` as a dependency if not present
- For RPM-based systems (dnf/yum), attempts to install from repository first, then falls back to manual installation
- Automatically starts and enables the SSM agent service on Linux systems
- Handles both systemd and init.d service management
- Skips installation if SSM agent is already installed

## Error Handling

- If the AWS SSM Agent is already installed, the script will skip reinstallation and display the current version.
- If an unsupported OS or architecture is detected, the script exits with an error message.
- The script will automatically clean up temporary installation files.
- Service start/enable operations are handled gracefully for systems without systemd.

## Cleanup

- Temporary installation files (`.deb`, `.rpm`, `.msi`, `.pkg`) are automatically removed after execution using a trap handler.
