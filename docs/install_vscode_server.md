# install_vscode_server.sh

This script installs, uninstalls, or manages VS Code Server on Ubuntu, Red Hat, or Fedora-based systems. VS Code Server allows you to run VS Code on a remote machine and access it through your browser.

## Usage

```bash
./install_vscode_server.sh [install|uninstall]
```

- **install** (default): Installs VS Code Server and starts the service.
- **uninstall**: Removes VS Code Server from the system.

## Required Environment Variables

- **VSCODE_TOKEN**: Authentication password for VS Code Server (required)

## Optional Environment Variables

- **VSCODE_SERVER_PORT**: Port for VS Code Server (default: 8000)
- **VSCODE_THEME**: VS Code theme (default: 'Default Dark Modern')
  - Examples: 'Default Dark Modern', 'Default Light Modern', 'Default High Contrast'
- **VSCODE_VERSION**: Pin specific version (e.g., v4.106.3) or leave empty for latest

## Example Usage

To install VS Code Server with default settings:

```bash
VSCODE_TOKEN='mytoken123' ./install_vscode_server.sh install
```

To install with a custom port:

```bash
VSCODE_TOKEN='mytoken123' VSCODE_SERVER_PORT=8080 ./install_vscode_server.sh install
```

To install with a custom theme:

```bash
VSCODE_TOKEN='mytoken123' VSCODE_THEME='Default Light Modern' ./install_vscode_server.sh install
```

To install a specific version:

```bash
VSCODE_TOKEN='mytoken123' VSCODE_VERSION='v4.106.3' ./install_vscode_server.sh install
```

To uninstall VS Code Server:

```bash
./install_vscode_server.sh uninstall
```

## Running Without Cloning

```bash
VSCODE_TOKEN='mytoken123' bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_vscode_server.sh) install
```

## Verification

After installation, check the VS Code Server version:

```bash
code-server --version
```

Check the service status:

```bash
sudo systemctl status code-server
```

VS Code Server will be available at: <http://localhost:8000> (or your configured port)

Access the web interface using the password set in `VSCODE_TOKEN`.

## Supported Operating Systems

- Ubuntu (uses `apt` for package management)
- Red Hat / Fedora (uses `dnf` for package management)
- CentOS / Amazon Linux (uses `yum` for package management)

## Features

- Automatically detects package manager and operating system
- Dynamically detects the current user (ec2-user, ubuntu, or current user)
- Installs required dependencies (wget, tar, gzip, net-tools) if missing
- Downloads latest version from GitHub releases (or uses pinned version)
- Creates systemd service for automatic startup
- Configures VS Code Server with customizable theme
- Automatically starts and enables the service after installation
- Skips installation if VS Code Server is already installed

## Error Handling

- If VS Code Server is already installed, the script will skip reinstallation and display the current version.
- If an unsupported OS is detected, the script exits with an error message.
- The script validates that the service file and binary exist before starting the service.
- Missing dependencies are automatically installed.
- User detection handles various scenarios (root, sudo, regular user).

## Cleanup

- Temporary installation files are automatically removed after execution.
- The script uses `trap cleanup EXIT` to ensure cleanup even if interrupted.
- Extracted directories in `/tmp/vscode-server-install` are cleaned up.

## Configuration

The script automatically configures VS Code Server with:

- **Systemd service** at `/etc/systemd/system/code-server.service`
- **User settings** at `~/.local/share/code-server/User/settings.json`
- **Custom theme** (configurable via `VSCODE_THEME` environment variable)
- **Password authentication** using the `VSCODE_TOKEN` environment variable
- **Port binding** to `0.0.0.0` on the configured port (default: 8000)
- **Automatic restart** on failure with 10-second delay

### Configuration Details

- **Installation directory**: `/opt/code-server`
- **Binary location**: `/opt/code-server/bin/code-server`
- **Service user**: Automatically detected (ec2-user, ubuntu, or current user)
- **Working directory**: User's home directory (`/home/$USER`)
- **Theme**: Configurable via `VSCODE_THEME` environment variable
- **Port**: Configurable via `VSCODE_SERVER_PORT` environment variable (default: 8000)

## Service Management

After installation, you can manage the VS Code Server service using:

```bash
sudo systemctl start code-server
sudo systemctl stop code-server
sudo systemctl restart code-server
sudo systemctl enable code-server
sudo systemctl disable code-server
```

### Service Commands

- **Start**: `sudo systemctl start code-server`
- **Stop**: `sudo systemctl stop code-server`
- **Restart**: `sudo systemctl restart code-server`
- **Status**: `sudo systemctl status code-server`
- **Enable**: `sudo systemctl enable code-server` (starts automatically on boot)
- **Disable**: `sudo systemctl disable code-server` (prevents auto-start on boot)

## Prerequisites

The script automatically installs required dependencies:

- `wget` - for downloading VS Code Server
- `tar` - for extracting the archive
- `gzip` - for decompressing the archive
- `net-tools` or `ss` - for port verification (optional)

## User Detection

The script automatically detects the appropriate user to run VS Code Server:

- If running as root, it checks for `ec2-user`, `ubuntu`, or uses `$SUDO_USER`
- If running as a regular user, it uses the current user (`whoami`)
- The detected user's home directory is used for VS Code Server configuration

## Troubleshooting

### Common Issues

1. **Service fails to start**: Check logs with `sudo journalctl -u code-server.service -f`
2. **Permission denied**: Ensure the script is run with appropriate permissions (may require sudo)
3. **Port already in use**: Check if another service is using the configured port (default: 8000)
4. **VSCODE_TOKEN not set**: The script requires `VSCODE_TOKEN` environment variable to be set
5. **User detection issues**: The script will default to `ec2-user` if no suitable user is found

### Logs and Debugging

- **Service logs**: `sudo journalctl -u code-server.service`
- **Check if running**: `sudo systemctl is-active code-server`
- **Check port**: `netstat -tlnp | grep :8000` or `ss -tlnp | grep :8000`
- **Web interface**: Access <http://localhost:8000> (or your configured port) and login with the password set in `VSCODE_TOKEN`

### Accessing VS Code Server

1. Ensure the service is running: `sudo systemctl status code-server`
2. Open your browser and navigate to `http://<server-ip>:<port>` (default: 8000)
3. Enter the password set in `VSCODE_TOKEN` environment variable
4. You should now have access to VS Code Server in your browser

### Security Considerations

- **Change the password**: After first login, consider changing the password in the VS Code Server settings
- **Firewall**: Ensure the configured port is open in your firewall if accessing remotely
- **HTTPS**: For production use, consider setting up a reverse proxy with HTTPS (nginx, Apache, etc.)
- **Token security**: Use a strong password for `VSCODE_TOKEN` and keep it secure
