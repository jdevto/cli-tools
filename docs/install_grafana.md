# install_grafana.sh

This script installs, uninstalls, or manages Grafana on Ubuntu, Red Hat, or Fedora-based systems. Grafana is a web-based analytics and monitoring platform that provides visualization and alerting capabilities.

## Usage

```bash
./install_grafana.sh [install|uninstall|start|stop|status] [--version VERSION] [--start] [--force]
```

- **install** (default): Installs the latest Grafana version.
- **uninstall**: Removes Grafana from the system.
- **start**: Starts the Grafana service.
- **stop**: Stops the Grafana service.
- **status**: Shows the service status.
- **--version VERSION**: Install a specific version (e.g., 11.0.0).
- **--start**: Automatically start the service after installation.
- **--force**: Force uninstall without prompts (removes all data and configuration).

## Example Usage

To install the latest Grafana version:

```bash
./install_grafana.sh
```

To install a specific version:

```bash
./install_grafana.sh install --version 11.0.0
```

To install and automatically start the service:

```bash
./install_grafana.sh install --start
```

To start the Grafana service:

```bash
./install_grafana.sh start
```

To check service status:

```bash
./install_grafana.sh status
```

To uninstall Grafana:

```bash
./install_grafana.sh uninstall
```

To force uninstall without prompts (removes all data):

```bash
./install_grafana.sh uninstall --force
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_grafana.sh) install
```

## Verification

After installation, check the Grafana version:

```bash
grafana --version
```

Check the service status:

```bash
sudo systemctl status grafana
```

Grafana will be available at: <http://localhost:3000>

Default credentials: **admin/admin**

## Supported Operating Systems

- Ubuntu (uses `apt` for package management)
- Red Hat / Fedora (uses `dnf` for package management)
- CentOS (uses `yum` for package management)

## Error Handling

- If Grafana is already installed with the requested version, the script will skip reinstallation.
- If an unsupported OS is detected, the script exits with an error message.
- The script creates a dedicated `grafana` user for security.
- Missing dependencies (curl, tar, jq) are automatically installed.
- Service management commands validate that Grafana is properly installed before attempting operations.

## Cleanup

- Temporary installation files are automatically removed after execution.
- The script uses `trap cleanup EXIT` to ensure cleanup even if interrupted.

## Configuration

The script uses Grafana's official default configuration as a base, ensuring compatibility with the latest version. The configuration is located at `/etc/grafana/grafana.ini` and includes:

- **HTTP server** on port 3000
- **SQLite database** for data storage
- **Admin credentials** set to admin/admin
- **File-based sessions** for security
- **No analytics** or update checking
- **Proper directory paths** for data, logs, plugins, and provisioning

### Configuration Details

- **Database**: Uses SQLite3 with database file at `/var/lib/grafana/grafana.db`
- **Security**: Runs as dedicated `grafana` user with restricted permissions
- **Sessions**: File-based session storage for security
- **Paths**: All Grafana directories properly configured and owned by grafana user
- **Admin Access**: Default admin user with password 'admin' (change in production)

## Service Management

After installation, you can manage the Grafana service using:

```bash
sudo systemctl start grafana
sudo systemctl stop grafana
sudo systemctl restart grafana
sudo systemctl enable grafana
```

### Service Commands

- **Start**: `sudo systemctl start grafana` or `./install_grafana.sh start`
- **Stop**: `sudo systemctl stop grafana` or `./install_grafana.sh stop`
- **Status**: `sudo systemctl status grafana` or `./install_grafana.sh status`
- **Enable**: `sudo systemctl enable grafana` (starts automatically on boot)
- **Disable**: `sudo systemctl disable grafana` (prevents auto-start on boot)

## Prerequisites

The script automatically installs required dependencies:

- `curl` - for downloading Grafana
- `tar` - for extracting the archive
- `jq` - for parsing version information

## Troubleshooting

### Common Issues

1. **Service fails to start**: Check logs with `sudo journalctl -u grafana.service -f`
2. **Permission denied**: Ensure the script is run with `sudo`
3. **Port already in use**: Check if another service is using port 3000
4. **Login fails**: The script ensures clean admin credentials (admin/admin), but you can modify `/etc/grafana/grafana.ini` if needed
5. **Database errors**: The script removes existing database to ensure clean admin credentials

### Logs and Debugging

- **Service logs**: `sudo journalctl -u grafana.service`
- **Configuration validation**: `grafana --config=/etc/grafana/grafana.ini --pidfile=/var/lib/grafana/grafana-server.pid --dry-run`
- **Check if running**: `sudo systemctl is-active grafana`
- **Web interface**: Access <http://localhost:3000> and login with admin/admin

### Data Sources

To add Loki as a data source for log visualization:

1. Login to Grafana at <http://localhost:3000>
2. Go to Configuration → Data Sources
3. Add Loki data source with URL: <http://localhost:3100>
4. Save and test the connection
