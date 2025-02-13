# setup-msk-iam-auth.sh

This script installs or uninstalls the AWS MSK IAM Authentication plugin for Kafka and configures the required authentication settings.

## Usage

```bash
./setup-msk-iam-auth.sh [install|uninstall] [--enable-debug-logs]
```

- **install** (default): Installs the AWS MSK IAM Authentication plugin.
- **uninstall**: Removes the AWS MSK IAM Authentication plugin.
- **--enable-debug-logs**: Enables Kafka log level to DEBUG.

## Example Usage

To install the AWS MSK IAM Authentication plugin:

```bash
./setup-msk-iam-auth.sh
```

To install and enable Kafka debug logging:

```bash
./setup-msk-iam-auth.sh install --enable-debug-logs
```

To uninstall the AWS MSK IAM Authentication plugin:

```bash
./setup-msk-iam-auth.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/setup-msk-iam-auth.sh) install
```

## Verification

After installation, check if the IAM authentication JAR is installed:

```bash
ls /opt/kafka/libs/ | grep aws-msk-iam-auth
```

Check if authentication properties are configured:

```bash
cat /opt/kafka/iam-auth-client.properties
```

Check if debug logging is enabled:

```bash
grep -E "INFO|WARN|ERROR|DEBUG" /opt/kafka/config/tools-log4j.properties
```

## Supported Operating Systems

- **Debian/Ubuntu** (installs dependencies using `apt`)
- **Red Hat / Fedora / Amazon Linux** (installs dependencies using `dnf` or `yum`)
- **Any Linux distribution with Kafka installed in `/opt/kafka/`**

## Error Handling

- If the AWS MSK IAM Authentication plugin is already installed, the script will skip reinstallation.
- If an unsupported OS is detected, the script exits with an error message.
- If `--enable-debug-logs` is not passed but logs are set to DEBUG, they will be reverted to their original level.

## Cleanup

- If the script is uninstalled, all authentication files and log configurations will be removed.
- Log4j configuration backups (`.bak` files) are kept for recovery if needed.
