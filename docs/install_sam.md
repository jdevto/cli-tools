# install_sam.sh

This script installs or uninstalls the AWS SAM CLI on Linux and macOS systems. The AWS SAM CLI is a tool for building, testing, and deploying serverless applications.

## Usage

```bash
./install_sam.sh [install|uninstall]
```

- **install** (default): Installs the latest AWS SAM CLI version.
- **uninstall**: Removes the AWS SAM CLI from the system.

## Example Usage

To install AWS SAM CLI:

```bash
./install_sam.sh
```

To uninstall AWS SAM CLI:

```bash
./install_sam.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_sam.sh) install
```

## Verification

After installation, check the AWS SAM CLI version:

```bash
sam --version
```

## Supported Operating Systems

- **Linux** (Ubuntu/Debian, RHEL/CentOS/Fedora)
  - Supports x86_64 and aarch64 architectures
- **macOS** (Intel and Apple Silicon)
  - Supports x86_64 and aarch64 (arm64) architectures

## Installation Locations

- **Root user**: Installs to `/usr/local/bin`
- **Non-root user**: Installs to `~/.local/bin` (automatically added to PATH)

## Features

- Automatically detects platform and architecture
- Installs required dependencies (curl, unzip)
- Downloads latest version from GitHub releases
- Sets up bash completion automatically
- Idempotent: skips installation if already installed
- Handles both root and non-root installations
- Preserves bundled Python libraries in dist directory

## Error Handling

- If AWS SAM CLI is already installed, the script will skip reinstallation.
- If an unsupported OS or architecture is detected, the script exits with an error message.
- The script checks for required dependencies before attempting installation.
- Missing dependencies are automatically installed.
- Validates that sudo is available (or runs as root) before attempting package installation.

## Bash Completion

The script automatically sets up bash completion for the `sam` command:

- **Root user**: Completion is added to `/etc/bash_completion.d/sam` and sourced in `/etc/bash.bashrc`
- **Non-root user**: Completion is added to `~/.bash_completion.d/sam` and sourced in `~/.bashrc`

After installation, restart your shell or run `source ~/.bashrc` for completion to take effect.

## Prerequisites

The script automatically installs required dependencies:

- **curl** - for downloading the SAM CLI installer
- **unzip** - for extracting the downloaded archive

### OS-Specific Prerequisites

- **Linux**: Requires appropriate package manager (apt, apt-get, dnf, yum)
- **macOS**: Requires Homebrew (for dependency installation)

## Idempotency

The script is idempotent and will:

- Check if AWS SAM CLI is already installed
- Skip installation if already present
- Proceed with installation if not installed

## Troubleshooting

### Common Issues

1. **SAM command not found after installation**:
   - Restart your shell or run `source ~/.bashrc` (or `source ~/.zshrc`)
   - Verify PATH: `echo $PATH | grep .local/bin`
   - Check installation: `ls -la ~/.local/bin/sam` (non-root) or `ls -la /usr/local/bin/sam` (root)
   - For non-root installations, ensure `~/.local/bin` is in your PATH

2. **Installation fails on Linux**:
   - Ensure you have sudo privileges or are running as root
   - Check if curl and unzip are available: `which curl unzip`
   - Verify package manager is working: `sudo apt update` (Ubuntu) or `sudo dnf check-update` (RHEL/Fedora)

3. **Installation fails on macOS**:
   - Ensure Homebrew is installed: `brew --version`
   - If Homebrew is not available, ensure curl and unzip are installed manually

4. **Bash completion not working**:
   - Restart your shell or run `source ~/.bashrc`
   - Check if completion file exists: `ls -la ~/.bash_completion.d/sam` (non-root) or `ls -la /etc/bash_completion.d/sam` (root)
   - Verify completion is sourced: `grep "bash_completion.d/sam" ~/.bashrc` (non-root) or `grep "bash_completion.d/sam" /etc/bash.bashrc` (root)

5. **Download fails**:
   - Check internet connectivity
   - Verify GitHub releases are accessible: `curl -I https://github.com/aws/aws-sam-cli/releases/latest`
   - Check if architecture is supported (x86_64 or aarch64/arm64)

### Logs and Debugging

- **Check installed version**: `sam --version`
- **Check installation location**: `which sam`
- **Check PATH**: `echo $PATH`
- **Test completion**: Type `sam` and press Tab to see if completion works

## Cleanup

- Temporary installation files are automatically removed after execution.
- The script uses `trap cleanup EXIT` to ensure cleanup even if interrupted.

## Notes

- The script installs the standalone binary distribution from GitHub releases
- The SAM CLI includes bundled Python libraries in the `dist` directory
- Bash completion is automatically configured but requires shell restart to take effect
- The script intelligently handles sudo - works when running as root or with sudo privileges
- For non-root installations, ensure `~/.local/bin` is in your PATH (the script attempts to add it automatically)

## Additional Resources

- **AWS SAM CLI Documentation**: <https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html>
- **AWS SAM CLI GitHub**: <https://github.com/aws/aws-sam-cli>
- **AWS SAM CLI Releases**: <https://github.com/aws/aws-sam-cli/releases>
