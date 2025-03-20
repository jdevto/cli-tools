# install_kubectl.sh

This script installs or uninstalls `kubectl` on Ubuntu, Red Hat, or Fedora-based systems.

## Usage

```bash
./install_kubectl.sh [install|uninstall]
```

- **install** (default): Installs the latest `kubectl` version.
- **uninstall**: Removes `kubectl` from the system.

## Example Usage

To install `kubectl`:

```bash
./install_kubectl.sh
```

To uninstall `kubectl`:

```bash
./install_kubectl.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_kubectl.sh) install
```

## Verification

After installation, check the `kubectl` version:

```bash
kubectl version --client
```

## Supported Operating Systems

- Ubuntu (uses `apt` for package management)
- Red Hat / Fedora (uses `dnf` for package management)

## Error Handling

- If `kubectl` is already installed and up to date, the script will skip reinstallation.
- If an unsupported OS is detected, the script exits with an error message.

## Cleanup

- Temporary installation files are automatically removed after execution.
