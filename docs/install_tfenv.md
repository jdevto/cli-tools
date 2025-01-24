# install_tfenv.sh

This script installs or uninstalls tfenv on Ubuntu, Red Hat, or Fedora-based systems.

## Usage

```bash
./install_tfenv.sh [install|uninstall]
```

- **install** (default): Installs the latest tfenv version and sets it up.
- **uninstall**: Removes tfenv from the system.

## Example Usage

To install tfenv:

```bash
./install_tfenv.sh
```

To uninstall tfenv:

```bash
./install_tfenv.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_tfenv.sh) install
```

## Verification

After installation, check the tfenv version:

```bash
tfenv --version
```

## Supported Operating Systems

- Ubuntu (uses `apt` for package management)
- Red Hat / Fedora (uses `dnf` for package management)

## Error Handling

- If tfenv is already installed, the script will skip reinstallation.
- If an unsupported OS is detected, the script exits with an error message.

## Cleanup

- Any temporary installation files are automatically removed after execution.
