# install_python.sh

This script installs or uninstalls Python on Linux, macOS, and Windows systems. It supports version pinning and automatically installs the latest version when no version is specified.

## Usage

```bash
./install_python.sh [install|uninstall]
```

- **install** (default): Installs Python (latest version if not specified).
- **uninstall**: Removes Python from the system.

## Optional Environment Variables

- **PYTHON_VERSION**: Pin specific version (e.g., `3.12` or `3.12.5`) or leave empty for latest
- **PYTHON_SET_ALIASES**: Set aliases for `python` and `python3` to point to the installed version (default: `true`)
  - Set to `false`, `0`, or `no` to disable alias creation

## Example Usage

To install the latest Python version:

```bash
./install_python.sh install
```

To install a specific major.minor version:

```bash
PYTHON_VERSION=3.12 ./install_python.sh install
```

To install a specific full version:

```bash
PYTHON_VERSION=3.11.5 ./install_python.sh install
```

To install without setting aliases:

```bash
PYTHON_SET_ALIASES=false ./install_python.sh install
```

To uninstall Python:

```bash
./install_python.sh uninstall
```

## Running Without Cloning

To install the latest Python version:

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_python.sh) install
```

To install a specific version:

```bash
PYTHON_VERSION=3.13 bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_python.sh) install
```

To install without setting aliases:

```bash
PYTHON_SET_ALIASES=false bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_python.sh) install
```

**Note**: On RHEL/CentOS/Fedora systems, installing a specific Python version (e.g., `python3.13`) creates a versioned binary (`python3.13`) rather than replacing `python3`. The script automatically creates aliases for `python` and `python3` to point to the installed version (unless `PYTHON_SET_ALIASES=false`).

## Verification

After installation, check the Python version:

**If aliases are enabled (default)**: The `python` and `python3` commands will point to the installed version:

```bash
python --version
python3 --version
```

**On Linux (RHEL/CentOS/Fedora) without aliases**: When installing a specific version (e.g., `python3.13`), use the versioned binary:

```bash
python3.13 --version
```

**On Linux (Ubuntu/Debian) or macOS**: The default `python3` command should work:

```bash
python3 --version
```

**Note**: After installation with aliases enabled, restart your shell or run `source ~/.bashrc` (or `source ~/.zshrc`) for aliases to take effect.

## Supported Operating Systems

- **Linux** (Ubuntu/Debian, RHEL/CentOS/Fedora)
- **macOS** (Intel and Apple Silicon)
- **Windows** (limited support - provides instructions)

## Installation Methods by OS

### Linux (Ubuntu/Debian)

- Uses system package manager (`apt`/`apt-get`)
- For newer versions, automatically adds `deadsnakes` PPA (Ubuntu only)
- **Note**: Deadsnakes PPA is Ubuntu-only; Debian systems will need to use pyenv or build from source
- Installs `python3.x`, `python3.x-dev`, and `python3.x-venv`

### Linux (RHEL/CentOS/Fedora)

- Uses system package manager (`dnf`/`yum`)
- Attempts EPEL repository for older RHEL/CentOS systems
- Falls back to compilation instructions if version not available

### macOS

- Uses Homebrew to install `pyenv`
- Installs Python via `pyenv` for better version management
- Automatically detects shell type (zsh, bash, or fallback to `.profile`)
- Configures shell profiles with pyenv integration (only if not already configured)

### Windows

- Provides manual installation instructions
- Recommends using `pyenv-win` for version management

## Features

- Automatically detects platform and package manager
- Intelligently handles sudo (works as root or with sudo)
- Installs latest Python version when no version is specified
- Supports version pinning (major.minor or full version)
- Idempotent: skips installation if requested version is already installed
- Automatically installs required dependencies (`curl`)
- Handles multiple installation methods per OS
- Verifies installation after completion
- Validates Ubuntu-only requirements for deadsnakes PPA
- Smart shell detection for pyenv configuration on macOS
- **Automatic alias creation**: Creates `python` and `python3` aliases pointing to the installed version (configurable via `PYTHON_SET_ALIASES`)

## Error Handling

- If Python with the requested version is already installed, the script will skip reinstallation.
- If an unsupported OS or architecture is detected, the script exits with an error message.
- The script checks for required dependencies before attempting installation.
- Missing dependencies are automatically installed.
- Validates that sudo is available (or runs as root) before attempting package installation.
- Checks if latest version detection succeeds before proceeding.
- Validates Ubuntu-only requirement for deadsnakes PPA on Debian-based systems.

## Version Detection

The script normalizes version numbers:

- `3.12.5` → `3.12` (major.minor)
- `3.12` → `3.12` (unchanged)
- Latest version is fetched from python.org

## Prerequisites

The script automatically installs required dependencies:

- **curl** - for fetching latest version information

### OS-Specific Prerequisites

- **macOS**: Requires Homebrew (installed automatically if needed for pyenv)
- **Linux**: Requires appropriate package manager (apt, dnf, yum)
- **Windows**: Manual installation recommended

## Idempotency

The script is idempotent and will:

- Check if Python is already installed
- Compare installed version with requested version
- Skip installation if versions match
- Proceed with installation if version differs or Python is not installed

## Troubleshooting

### Common Issues

1. **Python not found after installation**:
   - Restart your shell or run `source ~/.bashrc` (or `source ~/.zshrc`)
   - Verify PATH: `echo $PATH | grep python`
   - Check installation: `which python3`

2. **Installation fails on Ubuntu/Debian**:
   - Ensure `software-properties-common` is installed
   - Check if deadsnakes PPA was added: `ls /etc/apt/sources.list.d/ | grep deadsnakes`
   - **Note**: Deadsnakes PPA is Ubuntu-only. On Debian, use pyenv or build from source

3. **Installation fails on RHEL/CentOS**:
   - Ensure EPEL repository is enabled: `sudo yum install epel-release`
   - Some versions may require compilation from source

4. **macOS installation issues**:
   - Ensure Homebrew is installed: `brew --version`
   - If pyenv fails, try: `brew install python@3.12` directly

5. **Version not available**:
   - System repositories may not have the latest Python versions
   - Consider using `pyenv` for better version management
   - Check available versions in your distribution's repositories

6. **Aliases not working**:
   - Restart your shell or run `source ~/.bashrc` (or `source ~/.zshrc`)
   - Check if aliases were added: `grep "alias python" ~/.bashrc` (or `~/.zshrc`)
   - Verify the target binary exists: `which python3.13` (or your installed version)
   - Check if `PYTHON_SET_ALIASES` was set to false during installation

### Logs and Debugging

- **Check installed version**: `python3 --version`
- **Check available versions (Ubuntu)**: `apt-cache search python3 | grep '^python3'`
- **Check available versions (RHEL/Fedora)**: `dnf list available python3*`
- **Check pyenv versions (macOS)**: `pyenv versions`

### Manual Installation Methods

If the script fails, you can install Python manually:

**Ubuntu/Debian**:

```bash
sudo apt update
sudo apt install software-properties-common
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update
sudo apt install python3.12 python3.12-dev python3.12-venv
```

**RHEL/CentOS/Fedora**:

```bash
sudo dnf install python3.12
# Or for older systems:
sudo yum install epel-release
sudo yum install python312
```

**macOS**:

```bash
brew install pyenv
pyenv install 3.12.5
pyenv global 3.12.5
```

## Additional Resources

- **Official Python Downloads**: <https://www.python.org/downloads/>
- **pyenv (Linux/macOS)**: <https://github.com/pyenv/pyenv>
- **pyenv-win (Windows)**: <https://github.com/pyenv-win/pyenv-win>
- **deadsnakes PPA (Ubuntu)**: <https://launchpad.net/~deadsnakes/+archive/ubuntu/ppa>

## Cleanup

- Temporary installation files are automatically removed after execution.
- The script uses `trap cleanup EXIT` to ensure cleanup even if interrupted.

## Notes

- System Python (usually `python3`) may be a system dependency and should not be removed
- The script installs additional Python versions alongside system Python
- **Important**: On RHEL/CentOS/Fedora, installing a specific version (e.g., `python3.13`) creates a versioned binary (`python3.13`) rather than replacing `python3`. The script automatically creates aliases to make `python` and `python3` point to the installed version.
- **Aliases**: By default, the script creates aliases in your shell profile (`.bashrc`, `.zshrc`, or `.bash_profile`) so that `python` and `python3` point to the installed version. Set `PYTHON_SET_ALIASES=false` to disable this behavior.
- On macOS, the script uses `pyenv` for better version management
- Windows support is limited; manual installation is recommended
- The script intelligently handles sudo - works when running as root or with sudo privileges
- **Uninstall warning**: Removing Python packages can affect system tools on non-container systems
- Deadsnakes PPA is Ubuntu-only; Debian users should use pyenv or build from source
- Shell integration for pyenv is only added if not already present (prevents duplicates)
- Aliases are automatically updated when reinstalling or installing a different version
