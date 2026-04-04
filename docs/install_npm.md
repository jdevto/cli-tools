# install_npm.sh

This script installs or uninstalls **Node.js** and **npm** using the **official
prebuilt binaries** published at
[nodejs.org/dist](https://nodejs.org/dist/), matching the
[Node.js download](https://nodejs.org/en/download) page (LTS and Current
releases come from the same distribution index).

It does **not** use distro `apt`/`dnf`/`brew` packages for the install step, so
you get the current **LTS** or **Current** version from the Node.js project (or
an exact version you pin), not whatever your OS ships.

## Usage

```bash
./install_npm.sh [install|uninstall]
```

- **install** (default): Downloads the chosen release tarball or zip from
  `nodejs.org/dist`, extracts into `NODE_INSTALL_PREFIX` (default
  `$HOME/.local/node`), and optionally prepends that `bin` directory to `PATH`
  in `~/.bashrc` and `~/.zshrc` when those files exist.
- **uninstall**: Removes `NODE_INSTALL_PREFIX` and strips the managed `PATH`
  block from those rc files.

## Example Usage

Install latest **LTS** (default):

```bash
./install_npm.sh
```

Install latest **Current** release:

```bash
NODE_CHANNEL=current ./install_npm.sh install
```

Pin an exact version (must exist on
[nodejs.org/dist](https://nodejs.org/dist/)):

```bash
NODE_VERSION=22.14.0 ./install_npm.sh install
```

Install to a custom directory without editing shell rc files (e.g. CI):

```bash
NODE_UPDATE_SHELL_RC=false NODE_INSTALL_PREFIX=/opt/node ./install_npm.sh install
```

Uninstall:

```bash
./install_npm.sh uninstall
```

## Running Without Cloning

```bash
URL=https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_npm.sh
bash <(curl -s "$URL") install
```

Set `NODE_CHANNEL`, `NODE_VERSION`, `NODE_INSTALL_PREFIX`, or
`NODE_UPDATE_SHELL_RC` on the same line if you need them.

## Verification

```bash
node --version
npm --version
```

After a normal install, use a new terminal session or `source ~/.bashrc` /
`source ~/.zshrc` so `PATH` picks up `NODE_INSTALL_PREFIX/bin`.

## Supported Operating Systems

- **Linux** (glibc or musl) — `linux-x64`, `linux-arm64`, `linux-armv7l` when
  published for the selected version
- **macOS** — `darwin-x64`, `darwin-arm64`
- **Windows** (Git Bash, MSYS, Cygwin) — `win-x64` or `win-arm64` zip (requires
  `unzip`)

## Supported Architectures

- **x86_64** / **amd64** → `x64`
- **aarch64** / **arm64** → `arm64`
- **armv7l** → `armv7l` (Linux only, when available)

## Features

- Resolves **latest LTS** or **latest Current** via
  [nodejs.org/dist/index.json](https://nodejs.org/dist/index.json) (same
  source as the official site).
- **Idempotent**: if `NODE_INSTALL_PREFIX/bin/node` already matches the target
  version, install is skipped.
- **Upgrade / reinstall**: if the target version differs, the prefix directory
  is replaced with the new build.
- Optional **`NODE_VERSION`** for an exact release.
- Optional **`NODE_UPDATE_SHELL_RC`** to skip modifying `~/.bashrc` /
  `~/.zshrc`.

## Optional environment variables

- **`NODE_CHANNEL`** (default `lts`): `lts` or `current`. Ignored if
  `NODE_VERSION` is set.
- **`NODE_VERSION`**: Exact release, e.g. `24.14.1` or `v24.14.1`. Overrides
  `NODE_CHANNEL`.
- **`NODE_INSTALL_PREFIX`** (default `$HOME/.local/node`): Install root
  (`bin/node`, `bin/npm`, etc.).
- **`NODE_UPDATE_SHELL_RC`** (default `true`): Set to `false`, `0`, or `no` to
  skip editing rc files; the script prints an `export PATH=…` line instead.

## Requirements

- **curl** — download from `nodejs.org`
- **tar** — extract Linux/macOS archives
- **python3** — parse `index.json` (stdlib only)
- **unzip** — Windows zip extracts only

Parent directory of `NODE_INSTALL_PREFIX` must be writable by the user running
the script (no `sudo` required for the default prefix).

## Official references

- [Download Node.js](https://nodejs.org/en/download)
- [Package manager / install notes](https://nodejs.org/en/download/package-manager)
  (other official options include version managers such as nvm or fnm)
- [Verifying binaries](https://github.com/nodejs/node#verifying-binaries) (this
  script does not run checksum verification; you can verify downloads
  separately if needed)

## Uninstall

Removes `NODE_INSTALL_PREFIX` and the script’s marked block in `~/.bashrc` and
`~/.zshrc`. If another Node/npm remains on `PATH` (system packages, nvm, etc.),
remove or adjust that install separately.
