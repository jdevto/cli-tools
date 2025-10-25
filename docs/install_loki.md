# install_loki.sh

This script installs, uninstalls, or manages Grafana Loki on Ubuntu, Red Hat, or Fedora-based systems. Loki is a horizontally-scalable, highly-available log aggregation system inspired by Prometheus.

## Usage

```bash
./install_loki.sh [install|uninstall|start|stop|status] [--version VERSION] [--start] [--force]
```

- **install** (default): Installs the latest Loki version.
- **uninstall**: Removes Loki from the system.
- **start**: Starts the Loki service.
- **stop**: Stops the Loki service.
- **status**: Shows the service status.
- **--version VERSION**: Install a specific version (e.g., 2.9.0).
- **--start**: Automatically start the service after installation.
- **--force**: Force uninstall without prompts (removes all data and configuration).

## Example Usage

To install the latest Loki version:

```bash
./install_loki.sh
```

To install a specific version:

```bash
./install_loki.sh install --version 2.9.0
```

To install and automatically start the service:

```bash
./install_loki.sh install --start
```

To start the Loki service:

```bash
./install_loki.sh start
```

To check service status:

```bash
./install_loki.sh status
```

To uninstall Loki:

```bash
./install_loki.sh uninstall
```

To force uninstall without prompts (removes all data):

```bash
./install_loki.sh uninstall --force
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_loki.sh) install
```

## Verification

After installation, check the Loki version:

```bash
loki --version
```

Check the service status:

```bash
sudo systemctl status loki
```

Loki will be available at: <http://localhost:3100>

## Supported Operating Systems

- Ubuntu (uses `apt` for package management)
- Red Hat / Fedora (uses `dnf` for package management)
- CentOS (uses `yum` for package management)

## Error Handling

- If Loki is already installed with the requested version, the script will skip reinstallation.
- If an unsupported OS is detected, the script exits with an error message.
- The script creates a dedicated `loki` user for security.
- Missing dependencies (curl, unzip, jq) are automatically installed.
- Service management commands validate that Loki is properly installed before attempting operations.

## Cleanup

- Temporary installation files are automatically removed after execution.
- The script uses `trap cleanup EXIT` to ensure cleanup even if interrupted.

## Configuration

The script uses Loki's official default configuration as a base, ensuring compatibility with the latest version. The configuration is located at `/etc/loki/loki.yml` and includes:

- **HTTP server** on port 3100
- **Filesystem storage** in `/var/lib/loki`
- **Basic retention and limits** configuration
- **No authentication** (suitable for local development)
- **Automatic configuration updates** to match the installed Loki version

### Configuration Details

- **Storage**: Uses filesystem-based storage with chunks and rules directories
- **Schema**: Configured for boltdb-shipper with 24-hour index periods
- **Limits**: Reasonable defaults for ingestion rate, query parallelism, and retention
- **Security**: Runs as dedicated `loki` user with restricted permissions

## Service Management

After installation, you can manage the Loki service using:

```bash
sudo systemctl start loki
sudo systemctl stop loki
sudo systemctl restart loki
sudo systemctl enable loki
```

### Service Commands

- **Start**: `sudo systemctl start loki` or `./install_loki.sh start`
- **Stop**: `sudo systemctl stop loki` or `./install_loki.sh stop`
- **Status**: `sudo systemctl status loki` or `./install_loki.sh status`
- **Enable**: `sudo systemctl enable loki` (starts automatically on boot)
- **Disable**: `sudo systemctl disable loki` (prevents auto-start on boot)

## Prerequisites

The script automatically installs required dependencies:

- `curl` - for downloading Loki
- `unzip` - for extracting the archive
- `jq` - for parsing version information

## Troubleshooting

### Common Issues

1. **Service fails to start**: Check logs with `sudo journalctl -u loki.service -f`
2. **Permission denied**: Ensure the script is run with `sudo`
3. **Port already in use**: Check if another service is using port 3100
4. **Configuration errors**: The script uses Loki's official config, but you can modify `/etc/loki/loki.yml` if needed

### Logs and Debugging

- **Service logs**: `sudo journalctl -u loki.service`
- **Configuration validation**: `loki -config.file=/etc/loki/loki.yml -config.expand-env=true -dry-run`
- **Check if running**: `sudo systemctl is-active loki`
