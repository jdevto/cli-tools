# install_lm_studio.sh

This script installs, configures, and manages LM Studio on Linux systems. LM Studio is a desktop application for running large language models (LLMs) locally. This script installs LM Studio in headless mode with an API server for programmatic access.

## Usage

```bash
./install_lm_studio.sh [install|uninstall|start|stop|status]
```

- **install** (default): Installs LM Studio AppImage, bootstraps the CLI, and creates a systemd service.
- **uninstall**: Removes LM Studio from the system.
- **start**: Starts the LM Studio service.
- **stop**: Stops the LM Studio service.
- **status**: Shows the service status.

## Optional Environment Variables

- **LM_STUDIO_VERSION**: Pin specific version (default: `0.3.34-1`)
- **LM_STUDIO_PORT**: API server port (default: `1234`)
- **LM_STUDIO_USER**: User to run service as (auto-detected if not set)

## Example Usage

To install LM Studio with default settings:

```bash
./install_lm_studio.sh install
```

To install with a custom port:

```bash
LM_STUDIO_PORT=8080 ./install_lm_studio.sh install
```

To install a specific version:

```bash
LM_STUDIO_VERSION=0.3.34-1 ./install_lm_studio.sh install
```

To install with a specific user:

```bash
LM_STUDIO_USER=myuser ./install_lm_studio.sh install
```

To start the service:

```bash
./install_lm_studio.sh start
```

To check service status:

```bash
./install_lm_studio.sh status
```

To stop the service:

```bash
./install_lm_studio.sh stop
```

To uninstall LM Studio:

```bash
./install_lm_studio.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_lm_studio.sh) install
```

## Verification

After installation, check if LM Studio CLI is installed:

```bash
lms --version
```

Check the service status:

```bash
sudo systemctl status lm-studio
```

The API server will be available at: <http://localhost:1234> (or your configured port)

## Supported Operating Systems

- **Linux** (AppImage format)
  - Ubuntu (uses `apt` for package management)
  - Red Hat / Fedora (uses `dnf` for package management)
  - CentOS / Amazon Linux (uses `yum` for package management)

**Note**: LM Studio AppImage is only available for Linux. macOS and Windows are not supported by this script.

## Supported Architectures

- **x64** (x86_64)
- **arm64** (aarch64)

## Features

- Automatically detects package manager and operating system
- Dynamically detects the current user (ec2-user, ubuntu, or current user)
- Installs required dependencies (fuse, Xvfb, GUI libraries) if missing
- Downloads LM Studio AppImage (~1GB, may take several minutes)
- Bootstraps LM Studio CLI by running AppImage in headless mode
- Creates systemd service for automatic startup
- Runs AppImage with Xvfb (virtual framebuffer) for headless operation
- Installs CLI globally at `/usr/local/bin/lms`
- Automatically starts and enables the service after installation
- Skips installation if LM Studio is already installed
- Handles version pinning for reproducible installations

## Error Handling

- If LM Studio is already installed, the script will skip reinstallation and display the current version.
- If an unsupported OS or architecture is detected, the script exits with an error message.
- The script validates that the service file and binary exist before starting the service.
- Missing dependencies are automatically installed.
- User detection handles various scenarios (root, sudo, regular user).
- Download failures are handled gracefully with resume support.

## Cleanup

- Temporary installation files are automatically removed after execution.
- The script uses `trap cleanup EXIT` to ensure cleanup even if interrupted.
- Temporary directories in `/tmp/lm-studio-install` are cleaned up.

## Configuration

The script automatically configures LM Studio with:

- **Systemd service** at `/etc/systemd/system/lm-studio.service`
- **Service wrapper script** at `/usr/local/bin/lm-studio-service.sh`
- **AppImage location** at `/opt/lm-studio/LM-Studio-{VERSION}-{ARCH}.AppImage`
- **Global CLI binary** at `/usr/local/bin/lms`
- **User CLI binary** at `~/.lmstudio/bin/lms`
- **Xvfb virtual display** on `:99` for headless operation
- **API server** on the configured port (default: 1234)

### Configuration Details

- **Installation directory**: `/opt/lm-studio`
- **AppImage binary**: `/opt/lm-studio/LM-Studio-{VERSION}-{ARCH}.AppImage`
- **Symlink**: `/usr/local/bin/lm-studio` (points to AppImage)
- **CLI binary**: `/usr/local/bin/lms` (global) and `~/.lmstudio/bin/lms` (user)
- **Service user**: Automatically detected (ec2-user, ubuntu, or current user)
- **Working directory**: User's home directory
- **Port**: Configurable via `LM_STUDIO_PORT` environment variable (default: 1234)
- **Display**: Xvfb virtual display `:99` for headless operation

## Service Management

After installation, you can manage the LM Studio service using:

```bash
sudo systemctl start lm-studio
sudo systemctl stop lm-studio
sudo systemctl restart lm-studio
sudo systemctl enable lm-studio
sudo systemctl disable lm-studio
```

Or use the script commands:

```bash
./install_lm_studio.sh start
./install_lm_studio.sh stop
./install_lm_studio.sh status
```

### Service Commands

- **Start**: `sudo systemctl start lm-studio` or `./install_lm_studio.sh start`
- **Stop**: `sudo systemctl stop lm-studio` or `./install_lm_studio.sh stop`
- **Status**: `sudo systemctl status lm-studio` or `./install_lm_studio.sh status`
- **Enable**: `sudo systemctl enable lm-studio` (starts automatically on boot)
- **Disable**: `sudo systemctl disable lm-studio` (prevents auto-start on boot)

## Prerequisites

The script automatically installs required dependencies:

- **wget or curl** - for downloading the AppImage
- **fuse** - for mounting AppImage files
- **Xvfb** - virtual framebuffer for headless operation
- **GUI libraries** - required for AppImage bootstrap (gtk3, atk, nss, etc.)
- **nodejs and npm** - for CLI functionality

### Dependencies by Package Manager

**dnf/yum (RHEL/Fedora/Amazon Linux):**

- fuse, fuse-libs
- xorg-x11-server-Xvfb
- xdg-utils, atk, at-spi2-atk, gtk3, nss, cups-libs
- libXScrnSaver, gdk-pixbuf2, alsa-lib
- nodejs, npm

**apt/apt-get (Ubuntu/Debian):**

- libfuse2
- xvfb
- xdg-utils, libatk1.0-0, libatk-bridge2.0-0, libgtk-3-0
- libnss3, libcups2, libxss1, libgdk-pixbuf2.0-0, libasound2
- nodejs, npm

## User Detection

The script automatically detects the appropriate user to run LM Studio:

- If `LM_STUDIO_USER` is set and the user exists, it uses that user
- If running as root, it checks for `ec2-user`, `ubuntu`, or uses `$SUDO_USER`
- If running as a regular user, it uses the current user (`whoami`)
- The detected user's home directory is used for LM Studio configuration

## Troubleshooting

### Common Issues

1. **Service fails to start**: Check logs with `sudo journalctl -u lm-studio -f`
2. **Permission denied**: Ensure the script is run with appropriate permissions (may require sudo)
3. **CLI bootstrap fails**: The AppImage may need to be run interactively to install the CLI
4. **Xvfb fails to start**: Check if Xvfb is installed and accessible
5. **Download fails**: The AppImage is large (~1GB), ensure you have sufficient disk space and network bandwidth
6. **Port already in use**: Check if another service is using the configured port (default: 1234)

### Logs and Debugging

- **Service logs**: `sudo journalctl -u lm-studio -f`
- **Check if running**: `sudo systemctl is-active lm-studio`
- **Check port**: `netstat -tlnp | grep :1234` or `ss -tlnp | grep :1234`
- **API endpoint**: Access <http://localhost:1234/v1> (or your configured port)
- **Bootstrap logs**: Check `/tmp/lmstudio-bootstrap.log` during installation

### Manual CLI Bootstrap

If the automatic CLI bootstrap fails, you can manually bootstrap the CLI:

```bash
# Start Xvfb
sudo -u $USER Xvfb :99 -screen 0 1024x768x16 -ac -nolisten tcp &

# Run AppImage briefly to install CLI
sudo -u $USER DISPLAY=:99 /usr/local/bin/lm-studio --no-sandbox

# Stop after a few seconds once CLI is installed (Ctrl+C)
# CLI should now be available at ~/.lmstudio/bin/lms
```

### Download Issues

The AppImage download is large (~1GB) and may take several minutes:

- The script supports resume if download is interrupted
- Partial downloads are preserved and resumed on retry
- Check disk space: `df -h`
- Check network connectivity: `ping installers.lmstudio.ai`

### API Server

The API server starts automatically when the service starts. To interact with it:

```bash
# Check if API is responding
curl http://localhost:1234/v1/models

# Start a chat completion (example)
curl -X POST http://localhost:1234/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "your-model",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

**Note**: You need to download a model first using the CLI:

```bash
lms get <model-name>
```

## Security Considerations

- **User permissions**: LM Studio runs as a non-root user
- **Firewall**: Ensure the configured port is open in your firewall if accessing remotely
- **Network security**: For production use, consider setting up a reverse proxy with HTTPS
- **API access**: The API server is accessible on all interfaces (0.0.0.0) by default

## Limitations

- **Linux only**: LM Studio AppImage is only available for Linux
- **Large download**: The AppImage is approximately 1GB in size
- **GUI dependencies**: Requires GUI libraries even for headless operation (for AppImage bootstrap)
- **Model downloads**: Models must be downloaded separately using the CLI
- **Resource intensive**: Running LLMs requires significant CPU/GPU resources and memory

## Additional Resources

- **LM Studio Documentation**: <https://lmstudio.ai/docs>
- **LM Studio GitHub**: <https://github.com/lmstudio-ai>
- **API Documentation**: <https://lmstudio.ai/docs/api>
