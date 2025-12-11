# install_uv.sh

This script installs or uninstalls UV (an extremely fast Python package installer and resolver) on Linux, macOS, and Windows systems. UV is written in Rust and provides a drop-in replacement for pip, pip-tools, pipx, poetry, pyenv, twine, virtualenv, and more.

## Usage

```bash
./install_uv.sh [install|uninstall]
```

- **install** (default): Installs the latest UV version.
- **uninstall**: Removes UV from the system.

## Example Usage

To install UV:

```bash
./install_uv.sh
```

Or explicitly:

```bash
./install_uv.sh install
```

To uninstall UV:

```bash
./install_uv.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_uv.sh) install
```

## Verification

After installation, check the UV version:

```bash
uv --version
```

Test UV functionality:

```bash
uv --help
```

## Supported Operating Systems

- **Linux** (all distributions)
- **macOS** (Intel and Apple Silicon)
- **Windows** (via PowerShell)

## Supported Architectures

- **x86_64** (amd64) - Intel/AMD 64-bit
- **aarch64** (arm64) - ARM 64-bit (Apple Silicon, ARM servers)

## Features

- Automatically detects platform and architecture
- Uses official UV installation script from astral.sh
- Falls back to pip installation if official script fails
- Automatically adds UV to PATH for Linux/macOS installations
- Updates shell profiles (`.bashrc`, `.zshrc`) for persistent PATH
- Skips installation if UV is already installed
- Supports multiple installation methods (official script, pip fallback)

## Installation Methods

The script attempts installation in the following order:

1. **Official install script** (preferred): Downloads and runs the official UV installer from astral.sh
   - Linux/macOS: Uses bash script (`curl | sh`)
   - Windows: Uses PowerShell script (`irm | iex`)

2. **Pip fallback**: If the official script fails, attempts to install via pip
   - Linux/macOS: Uses `pip3` or `python3 -m pip`
   - Windows: Uses `pip` or `python -m pip`

## Error Handling

- If UV is already installed, the script will skip reinstallation and display the current version.
- If an unsupported platform or architecture is detected, the script exits with an error message.
- The script checks for required dependencies (`curl`) before attempting installation.
- If installation fails, the script attempts fallback methods before exiting with an error.

## Prerequisites

- **curl**: Required for downloading the installation script (automatically checked)
- **Python/pip**: Optional, used as fallback installation method if official script fails

## Installation Locations

UV is typically installed to:

- **Linux/macOS**: `$HOME/.cargo/bin/uv` (via official installer) or `$HOME/.local/bin/uv` (via pip)
- **Windows**: User's local bin directory (varies by installation method)

## PATH Configuration

For Linux/macOS installations, the script automatically:

- Adds `$HOME/.cargo/bin` to PATH for the current session
- Updates `~/.bashrc` and `~/.zshrc` to include UV in PATH permanently
- Ensures PATH entries are not duplicated

**Note**: You may need to restart your shell or run `source ~/.bashrc` (or `source ~/.zshrc`) for PATH changes to take effect.

## Uninstallation

The uninstall process:

- Removes UV binary from common installation locations
- Attempts to uninstall via pip if installed via pip
- Does not remove PATH entries from shell profiles (manual cleanup may be needed)

**Note**: If UV was installed via the official PowerShell script on Windows, you may need to remove it manually.

## Troubleshooting

### Common Issues

1. **UV not found after installation**:
   - Restart your shell or run `source ~/.bashrc` (or `source ~/.zshrc`)
   - Verify PATH: `echo $PATH | grep cargo`
   - Check installation: `ls -la $HOME/.cargo/bin/uv` or `ls -la $HOME/.local/bin/uv`

2. **Installation fails**:
   - Ensure `curl` is installed: `curl --version`
   - Check internet connectivity
   - Try fallback pip installation manually: `pip3 install uv`

3. **Permission denied**:
   - Ensure you have write permissions to `$HOME/.cargo/bin` or `$HOME/.local/bin`
   - On Linux/macOS, you may need to create directories: `mkdir -p $HOME/.cargo/bin`

4. **Windows PowerShell execution policy**:
   - If PowerShell script fails, you may need to adjust execution policy
   - Run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### Manual PATH Configuration

If PATH is not automatically configured, add UV to your PATH manually:

**Linux/macOS (Bash)**:

```bash
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**Linux/macOS (Zsh)**:

```bash
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Windows (PowerShell)**:

```powershell
$env:Path += ";$env:USERPROFILE\.cargo\bin"
[Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::User)
```

## Usage Examples

After installation, you can use UV as a replacement for various Python tools:

```bash
# Install a package (replaces pip install)
uv pip install requests

# Create a virtual environment (replaces venv/virtualenv)
uv venv

# Install and run a package (replaces pipx)
uv tool install black

# Manage dependencies (replaces pip-tools, poetry)
uv pip compile requirements.in
uv pip sync requirements.txt
```

## Additional Resources

- **Official Documentation**: <https://docs.astral.sh/uv/>
- **GitHub Repository**: <https://github.com/astral-sh/uv>
- **Installation Guide**: <https://docs.astral.sh/uv/getting-started/installation/>

## Cleanup

- No temporary files are created (installation scripts are piped directly)
- The cleanup function is included for consistency but performs no operations
