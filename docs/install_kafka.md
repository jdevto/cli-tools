# install_kafka.sh

This script installs or uninstalls Apache Kafka on various Linux distributions.

## Usage

```bash
./install_kafka.sh [install|uninstall] [--set-permissions [username]]
```

- **install** (default): Installs or updates Kafka to the latest version.
- **uninstall**: Removes Kafka from the system.
- **--set-permissions [username]**: Sets ownership of the Kafka installation directory to the specified user.

## Example Usage

To install Apache Kafka:

```bash
./install_kafka.sh
```

To install and set permissions for a specific user:

```bash
./install_kafka.sh install --set-permissions kafka-user
```

To uninstall Apache Kafka:

```bash
./install_kafka.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_kafka.sh) install
```

## Verification

After installation, check if Kafka is installed:

```bash
ls /opt/kafka/
```

Check the installed Kafka version:

```bash
/opt/kafka/bin/kafka-topics.sh --version
```

## Supported Operating Systems

- **Debian/Ubuntu** (installs dependencies using `apt`)
- **Red Hat / Fedora / Amazon Linux** (installs dependencies using `dnf` or `yum`)
- **Any Linux distribution with Kafka installed in `/opt/kafka/`**

## Error Handling

- If the latest Kafka version is already installed, the script will skip reinstallation.
- If an unsupported OS is detected, the script exits with an error message.
- If Kafka is not installed, `uninstall` will exit without performing any action.

## Cleanup

- The script automatically removes temporary installation files (`.tgz`).
- If `uninstall` is run, all Kafka files will be removed from `/opt/kafka/`.
