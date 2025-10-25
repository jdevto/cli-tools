# install_promtail.sh

This script installs, uninstalls, or manages Grafana Promtail on Ubuntu, Red Hat, or Fedora-based systems. Promtail is a log shipper that ships logs to Loki and other destinations.

## Usage

```bash
./install_promtail.sh [install|uninstall|start|stop|status] [--version VERSION] [--loki] [--start] [--force]
```

- **install** (default): Installs the latest Promtail version.
- **uninstall**: Removes Promtail from the system.
- **start**: Starts the Promtail service.
- **stop**: Stops the Promtail service.
- **status**: Shows the service status.
- **--version VERSION**: Install a specific version (e.g., 2.9.0).
- **--loki**: Enable Loki-compatible configuration (default: false).
- **--start**: Automatically start the service after installation.
- **--force**: Force uninstall without prompts (removes all data and configuration).

## Example Usage

To install the latest Promtail version with generic configuration:

```bash
./install_promtail.sh
```

To install with Loki-compatible configuration:

```bash
./install_promtail.sh install --loki
```

To install and automatically start the service:

```bash
./install_promtail.sh install --start
```

To install a specific version with Loki config and start:

```bash
./install_promtail.sh install --version 2.9.0 --loki --start
```

To start the Promtail service:

```bash
./install_promtail.sh start
```

To check service status:

```bash
./install_promtail.sh status
```

To uninstall Promtail:

```bash
./install_promtail.sh uninstall
```

To force uninstall without prompts (removes all data):

```bash
./install_promtail.sh uninstall --force
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_promtail.sh) install
```

## Verification

After installation, check the Promtail version:

```bash
promtail --version
```

Check the service status:

```bash
sudo systemctl status promtail
```

Promtail will be available at: <http://localhost:9080>

## Supported Operating Systems

- Ubuntu (uses `apt` for package management)
- Red Hat / Fedora (uses `dnf` for package management)
- CentOS (uses `yum` for package management)

## Error Handling

- If Promtail is already installed with the requested version, the script will skip reinstallation.
- If an unsupported OS is detected, the script exits with an error message.
- The script creates a dedicated `promtail` user for security.
- Missing dependencies (curl, unzip, jq) are automatically installed.
- Service management commands validate that Promtail is properly installed before attempting operations.

## Cleanup

- Temporary installation files are automatically removed after execution.
- The script uses `trap cleanup EXIT` to ensure cleanup even if interrupted.

## Configuration

The script creates a Promtail configuration at `/etc/promtail/config.yml` with two modes:

### Generic Configuration (default)

- No destination configured (`clients: []`)
- Scrapes `/var/log/*log` files
- Includes log parsing pipeline with regex and timestamp extraction
- Suitable for custom destinations (Elasticsearch, InfluxDB, Kafka, HTTP endpoints)

### Loki Configuration (`--loki` flag)

- Pre-configured for Loki at `http://localhost:3100`
- Same log scraping and parsing as generic mode
- Ready to work with local Loki installation

## Service Management

After installation, you can manage the Promtail service using:

```bash
sudo systemctl start promtail
sudo systemctl stop promtail
sudo systemctl restart promtail
sudo systemctl enable promtail
```

### Service Commands

- **Start**: `sudo systemctl start promtail` or `./install_promtail.sh start`
- **Stop**: `sudo systemctl stop promtail` or `./install_promtail.sh stop`
- **Status**: `sudo systemctl status promtail` or `./install_promtail.sh status`
- **Enable**: `sudo systemctl enable promtail` (starts automatically on boot)
- **Disable**: `sudo systemctl disable promtail` (prevents auto-start on boot)

## Prerequisites

The script automatically installs required dependencies:

- `curl` - for downloading Promtail
- `unzip` - for extracting the archive
- `jq` - for parsing version information

## Integration with Loki

When using the `--loki` flag, the script:

- Checks for local Loki installation
- Tests Loki connectivity at `http://localhost:3100`
- Provides helpful messages if Loki is not running
- Configures Promtail to send logs to the local Loki instance

## Troubleshooting

### Common Issues

1. **Service fails to start**: Check logs with `sudo journalctl -u promtail.service -f`
2. **Permission denied**: Ensure the script is run with `sudo`
3. **Port already in use**: Check if another service is using port 9080
4. **Configuration errors**: Edit `/etc/promtail/config.yml` to customize destination
5. **Loki not reachable**: Ensure Loki is running at `http://localhost:3100`

### Logs and Debugging

- **Service logs**: `sudo journalctl -u promtail.service`
- **Configuration validation**: `promtail -config.file=/etc/promtail/config.yml -config.expand-env=true -dry-run`
- **Check if running**: `sudo systemctl is-active promtail`
- **Test configuration**: `promtail -config.file=/etc/promtail/config.yml -print-config-stderr`

### Configuration Examples

#### Send to Remote Loki

```yaml
clients:
  - url: http://your-loki-server:3100/loki/api/v1/push
    basic_auth:
      username: your-username
      password: your-password
```

#### Send to Multiple Destinations

```yaml
clients:
  - url: http://localhost:3100/loki/api/v1/push
  - url: http://elasticsearch:9200/_bulk
```
