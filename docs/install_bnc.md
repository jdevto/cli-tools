# install_bnc.sh

This script installs or uninstalls the [BKG Ntrip Client (BNC)](https://igs.bkg.bund.de/ntrip/bnc), an open-source multi-stream client for real-time GNSS data. BNC retrieves, decodes, and converts GNSS correction streams from NTRIP broadcasters, and can compute real-time Precise Point Positioning (PPP) solutions.

## Usage

```bash
./install_bnc.sh [install|uninstall]
```

- **install** (default): Downloads and installs the BNC binary.
- **uninstall**: Removes BNC from the system.

## Example Usage

To install BNC:

```bash
./install_bnc.sh
```

Or explicitly:

```bash
./install_bnc.sh install
```

To uninstall BNC:

```bash
./install_bnc.sh uninstall
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_bnc.sh) install
```

## Verification

After installation, verify BNC is available:

```bash
bnc --help
```

Test BNC connectivity (command-line mode):

```bash
bnc --nw --conf /path/to/bnc.conf
```

## Supported Operating Systems

- **Linux** (64-bit: Debian/Ubuntu, RHEL/CentOS/Rocky, Amazon Linux 2023, openSUSE)
- **Linux ARM** (Raspberry Pi OS)
- **macOS** (Intel — v2.13.1)

## Supported Architectures

- **x86_64** (amd64) - Intel/AMD 64-bit (all Linux distros and macOS)
- **aarch64** (arm64) - ARM 64-bit (Raspberry Pi OS build)

## Features

- Downloads prebuilt shared binary from official BKG servers
- Automatically selects the correct binary for your Linux distro (Debian, RHEL/Rocky, SUSE, Raspberry Pi)
- Installs Qt5 runtime dependencies if missing
- Detects platform and architecture automatically
- Idempotent: skips if BNC is already installed
- Supports version pinning via environment variable
- Automatically installs unzip if not present
- Cleans up temporary files after installation

## Installation Method

The script downloads the prebuilt BNC binary:

1. Determines the correct binary URL based on platform and architecture
2. Downloads the zip archive from BKG official servers
3. Extracts the BNC binary
4. Installs it to the configured prefix

## Optional Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BNC_VERSION` | `2.13.6` | BNC version to install |
| `BNC_PREFIX` | `/usr/local` | Installation prefix directory |

## Error Handling

- If BNC is already installed, the script skips reinstallation
- If the download fails, the script exits with an error and URL information
- If the binary cannot be found in the archive, contents are displayed for debugging
- Unsupported platforms/architectures produce clear error messages

## Prerequisites

- **curl** or **wget**: Required for downloading the BNC archive
- **unzip**: Required for extracting the archive (automatically installed if missing)
- **Qt5 runtime libraries**: Required for running BNC (automatically installed if missing)
- **Internet access**: Required for downloading from BKG servers

## Troubleshooting

### Common Issues

1. **Download fails (403/404)**:
   - BKG servers may require manual download; visit <https://igs.bkg.bund.de/ntrip/bnc>
   - Try a different version: `BNC_VERSION=2.13.6 ./install_bnc.sh install`

2. **Binary not found in archive**:
   - Archive structure may vary by version; check script output for file listing
   - Download manually and place in `/usr/local/bin/bnc`

3. **bnc not found after installation**:
   - Verify `/usr/local/bin` is in your PATH: `echo $PATH | grep /usr/local/bin`
   - Try running with full path: `/usr/local/bin/bnc --help`

4. **Permission denied**:
   - Installing to `/usr/local/bin` needs write access (sudo when required)
   - For a user install without sudo: `BNC_PREFIX=$HOME/.local ./install_bnc.sh install`
   - The script only uses sudo when the target path is not writable

5. **Qt5 libraries missing** (common on Amazon Linux 2023):
   - BNC shared builds require Qt5 (`libQt5Core`, `libQt5Gui`, `libQt5Svg`, etc.)
   - Amazon Linux 2023 does not ship Qt5 in default or SPAL repos; the script installs Qt5 from Rocky Linux 9 repositories automatically
   - Manual install on Debian/Ubuntu: `sudo apt-get install libqt5core5a libqt5network5 libqt5gui5 libqt5widgets5 libqt5svg5`
   - Manual install on RHEL/Rocky: `sudo dnf install qt5-qtbase qt5-qtsvg qt5-qtbase-gui`
   - Verify: `ldd $(command -v bnc) | grep Qt5` should show no `not found` entries

## Additional Resources

- **BNC Download Page**: <https://igs.bkg.bund.de/ntrip/bnc>
- **BNC Documentation**: <https://igs.bkg.bund.de/ntrip/download>
- **NTRIP Protocol**: <https://igs.bkg.bund.de/ntrip/ntrip>
- **BNC Source Code**: <https://github.com/easynavtech/bnc-2.12.18-source>

## Cleanup

- Temporary download directory is removed automatically after installation via the cleanup trap
- Only the `bnc` binary remains in the install prefix
