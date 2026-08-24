# install_str2str.sh

This script installs or uninstalls `str2str`, the NTRIP stream relay tool from [RTKLIB](https://github.com/tomojitakasu/RTKLIB). str2str relays GNSS correction data streams between serial ports, TCP/IP, and NTRIP casters/clients, commonly used for RTK base station setups.

## Usage

```bash
./install_str2str.sh [install|uninstall]
```

- **install** (default): Builds and installs str2str from RTKLIB source.
- **uninstall**: Removes str2str from the system.

## Example Usage

To install str2str:

```bash
./install_str2str.sh
```

Or explicitly:

```bash
./install_str2str.sh install
```

To uninstall str2str:

```bash
./install_str2str.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_str2str.sh) install
```

## Verification

After installation, verify str2str is available:

```bash
str2str -h
```

Test a simple relay (example with NTRIP):

```bash
str2str -in ntrip://user:pass@caster:2101/mountpoint -out serial://ttyUSB0:115200
```

## Supported Operating Systems

- **Linux** (Ubuntu, Debian, Fedora, Arch, Amazon Linux)
- **macOS** (Intel and Apple Silicon)

## Supported Architectures

- **x86_64** (amd64) - Intel/AMD 64-bit
- **aarch64** (arm64) - ARM 64-bit (Raspberry Pi, Apple Silicon)

## Features

- Builds str2str from official RTKLIB source
- Automatically installs build dependencies (gcc, make, git)
- Detects platform and architecture
- Idempotent: skips if str2str is already installed
- Supports version pinning via environment variable
- Cleans up temporary build files after installation

## Installation Method

The script builds str2str from source by:

1. Cloning the RTKLIB repository from GitHub
2. Navigating to the str2str application directory
3. Compiling with `make`
4. Installing the binary to the configured prefix

## Optional Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RTKLIB_VERSION` | `2.4.3-b34` | RTKLIB version/tag to build from |
| `STR2STR_PREFIX` | `/usr/local` | Installation prefix directory |

## Error Handling

- If str2str is already installed, the script skips reinstallation
- If build dependencies are missing, the script attempts to install them automatically
- If an unsupported platform or architecture is detected, the script exits with an error
- Build failures produce clear error messages

## Prerequisites

- **git**: Required for cloning the RTKLIB repository
- **gcc/make**: Required for building from source (automatically installed if missing)
- **Internet access**: Required for downloading RTKLIB source code

## Troubleshooting

### Common Issues

1. **Build fails with missing headers**:
   - Ensure build-essential (or equivalent) is installed
   - On Ubuntu/Debian: `sudo apt-get install build-essential`

2. **str2str not found after installation**:
   - Verify `/usr/local/bin` is in your PATH: `echo $PATH | grep /usr/local/bin`
   - Try running with full path: `/usr/local/bin/str2str -h`

3. **Permission denied during install**:
   - The script requires sudo for installing to `/usr/local/bin`
   - Alternatively, set `STR2STR_PREFIX=$HOME/.local` to install without sudo

4. **Git clone fails**:
   - Check internet connectivity
   - Verify git is installed: `git --version`
   - Try a different version: `RTKLIB_VERSION=2.4.3-b34 ./install_str2str.sh install`

## Additional Resources

- **RTKLIB GitHub**: <https://github.com/tomojitakasu/RTKLIB>
- **RTKLIB Manual**: <https://www.rtklib.com/rtklib_document.htm>
- **NTRIP Protocol**: <https://igs.bkg.bund.de/ntrip/ntrip>

## Cleanup

- Temporary build directory is removed automatically after installation via the cleanup trap
- Only the `str2str` binary remains in the install prefix
