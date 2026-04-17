#!/bin/bash

set -e

# Official prebuilt binaries: https://nodejs.org/dist/ (see https://nodejs.org/en/download)
NODE_CHANNEL="${NODE_CHANNEL:-lts}"              # lts | current — matches “LTS” vs “Current” on the download page
NODE_VERSION="${NODE_VERSION:-}"                 # Optional: exact version, e.g. 24.14.1 or v24.14.1 (overrides NODE_CHANNEL)
NODE_INSTALL_PREFIX="${NODE_INSTALL_PREFIX:-$HOME/.local/node}"
NODE_UPDATE_SHELL_RC="${NODE_UPDATE_SHELL_RC:-true}"

TMP_DIR=""
MARK_BEGIN="# >>> install_npm.sh (Node.js from nodejs.org dist) >>>"
MARK_END="# <<< install_npm.sh <<<"

cleanup() {
    if [[ -n "${TMP_DIR:-}" ]]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

usage() {
    cat <<'EOF'
Usage: install_npm.sh [install|uninstall]

Default: install.

Installs Node.js and npm from official prebuilt binaries at https://nodejs.org/dist/
(see https://nodejs.org/en/download). Releases are chosen via NODE_CHANNEL or NODE_VERSION.

Optional environment variables:
  NODE_CHANNEL         - lts (default) or current — latest LTS vs latest Current from index.json
  NODE_VERSION         - Pin an exact release, e.g. 24.14.1 or v24.14.1 (overrides NODE_CHANNEL)
  NODE_INSTALL_PREFIX  - Install directory (default: $HOME/.local/node)
  NODE_UPDATE_SHELL_RC - If true/1/yes (default), append PATH to ~/.bashrc and ~/.zshrc when present.
                         Set to false/0/no to skip (e.g. CI or custom PATH).

Examples:
  install_npm.sh
  install_npm.sh install
  NODE_CHANNEL=current install_npm.sh install
  NODE_VERSION=22.14.0 install_npm.sh install
  install_npm.sh uninstall
EOF
    exit 1
}

check_dependencies() {
    local missing=()
    command -v curl &>/dev/null || missing+=("curl")
    command -v tar &>/dev/null || missing+=("tar")
    command -v python3 &>/dev/null || missing+=("python3")
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Error: Missing required tools: ${missing[*]}"
        echo "Install them and try again."
        exit 1
    fi
}

detect_platform_arch() {
    case "${OSTYPE:-}" in
    linux-gnu* | linux-musl*)
        OS="linux"
        ;;
    darwin*)
        OS="darwin"
        ;;
    msys* | cygwin* | win32)
        OS="win"
        ;;
    *)
        echo "Error: Unsupported OS: ${OSTYPE:-unknown}"
        exit 1
        ;;
    esac

    local m
    m=$(uname -m)
    case "$m" in
    x86_64 | amd64) ARCH="x64" ;;
    aarch64 | arm64) ARCH="arm64" ;;
    armv7l) ARCH="armv7l" ;;
    *)
        echo "Error: Unsupported architecture: $m"
        exit 1
        ;;
    esac

    if [ "$OS" = "win" ] && [ "$ARCH" = "arm64" ]; then
        WIN_ARCH="arm64"
    elif [ "$OS" = "win" ]; then
        WIN_ARCH="x64"
    fi
}

# Prints bare version like v24.14.1
resolve_dist_version() {
    local channel_or_exact="$1"
    python3 -c "
import json, sys, urllib.request
arg = sys.argv[1]
with urllib.request.urlopen('https://nodejs.org/dist/index.json', timeout=60) as r:
    data = json.load(r)
if arg == 'lts':
    ver = next(x['version'] for x in data if x['lts'])
elif arg == 'current':
    ver = data[0]['version']
else:
    v = arg if arg.startswith('v') else 'v' + arg
    if not any(x['version'] == v for x in data):
        sys.stderr.write(f'Error: No release {v} in nodejs.org/dist/index.json\n')
        sys.exit(1)
    ver = v
print(ver)
" "$channel_or_exact"
}

artifact_key_for_download() {
    if [ "$OS" = "linux" ]; then
        echo "linux-${ARCH}"
    elif [ "$OS" = "darwin" ]; then
        echo "darwin-${ARCH}"
    elif [ "$OS" = "win" ]; then
        echo "win-${WIN_ARCH}"
    fi
}

verify_release_has_artifact() {
    local ver="$1"
    local key="$2"
    python3 -c "
import json, sys, urllib.request
ver, key = sys.argv[1], sys.argv[2]
with urllib.request.urlopen('https://nodejs.org/dist/index.json', timeout=60) as r:
    data = json.load(r)
entry = next(x for x in data if x['version'] == ver)
# index uses linux-x64, osx-arm64-tar style keys — map our key to file tokens
def ok(files):
    if key == 'linux-x64' and 'linux-x64' in files: return True
    if key == 'linux-arm64' and 'linux-arm64' in files: return True
    if key == 'linux-armv7l' and 'linux-armv7l' in files: return True
    if key == 'darwin-x64' and 'osx-x64-tar' in files: return True
    if key == 'darwin-arm64' and 'osx-arm64-tar' in files: return True
    if key == 'win-x64' and 'win-x64-zip' in files: return True
    if key == 'win-arm64' and 'win-arm64-zip' in files: return True
    return False
if not ok(entry['files']):
    sys.stderr.write(f\"Error: Node {ver} has no official prebuild for {key}.\\n\")
    sys.exit(1)
" "$ver" "$key"
}

download_and_extract() {
    local ver="$1"
    local key
    key=$(artifact_key_for_download)
    verify_release_has_artifact "$ver" "$key"

    TMP_DIR=$(mktemp -d)

    local base="https://nodejs.org/dist/${ver}"

    if [ "$OS" = "linux" ]; then
        local archive="node-${ver}-linux-${ARCH}.tar.xz"
        curl -fsSL "${base}/${archive}" -o "${TMP_DIR}/${archive}"
        rm -rf "${NODE_INSTALL_PREFIX:?}"
        mkdir -p "$NODE_INSTALL_PREFIX"
        tar -xJf "${TMP_DIR}/${archive}" -C "$NODE_INSTALL_PREFIX" --strip-components=1
    elif [ "$OS" = "darwin" ]; then
        local archive="node-${ver}-darwin-${ARCH}.tar.gz"
        curl -fsSL "${base}/${archive}" -o "${TMP_DIR}/${archive}"
        rm -rf "${NODE_INSTALL_PREFIX:?}"
        mkdir -p "$NODE_INSTALL_PREFIX"
        tar -xzf "${TMP_DIR}/${archive}" -C "$NODE_INSTALL_PREFIX" --strip-components=1
    elif [ "$OS" = "win" ]; then
        if ! command -v unzip &>/dev/null; then
            echo "Error: unzip is required to install Node on Windows."
            exit 1
        fi
        local archive="node-${ver}-win-${WIN_ARCH}.zip"
        curl -fsSL "${base}/${archive}" -o "${TMP_DIR}/${archive}"
        rm -rf "${NODE_INSTALL_PREFIX:?}"
        mkdir -p "$NODE_INSTALL_PREFIX"
        unzip -oq "${TMP_DIR}/${archive}" -d "$TMP_DIR/extract"
        local inner
        inner=$(find "$TMP_DIR/extract" -mindepth 1 -maxdepth 1 -type d | head -1)
        mv "$inner"/* "$NODE_INSTALL_PREFIX/"
    fi
}

prepend_path_in_shell_configs() {
    case "${NODE_UPDATE_SHELL_RC:-true}" in
    false | False | FALSE | 0 | no | No | NO) return 0 ;;
    esac

    local line="export PATH=\"${NODE_INSTALL_PREFIX}/bin:\$PATH\""
    local f
    for f in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ ! -f "$f" ]; then
            continue
        fi
        if grep -qF "$MARK_BEGIN" "$f" 2>/dev/null; then
            continue
        fi
        {
            echo ""
            echo "$MARK_BEGIN"
            echo "$line"
            echo "$MARK_END"
        } >>"$f"
        echo "Added Node.js PATH to $f (open a new shell or: source $f)"
    done
}

remove_path_from_shell_configs() {
    local f
    for f in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ ! -f "$f" ]; then
            continue
        fi
        if ! grep -qF "$MARK_BEGIN" "$f" 2>/dev/null; then
            continue
        fi
        local tmp
        tmp=$(mktemp)
        awk -v begin="$MARK_BEGIN" -v end="$MARK_END" '
            $0 == begin { skip=1; next }
            $0 == end { skip=0; next }
            !skip { print }
        ' "$f" >"$tmp" && mv "$tmp" "$f"
        echo "Removed Node.js PATH block from $f"
    done
}

installed_prefix_version() {
    if [ -x "${NODE_INSTALL_PREFIX}/bin/node" ]; then
        "${NODE_INSTALL_PREFIX}/bin/node" --version 2>/dev/null || true
    fi
}

install_npm() {
    check_dependencies
    detect_platform_arch

    mkdir -p "$(dirname "$NODE_INSTALL_PREFIX")"
    if [ ! -w "$(dirname "$NODE_INSTALL_PREFIX")" ]; then
        echo "Error: Cannot write to parent of NODE_INSTALL_PREFIX: $(dirname "$NODE_INSTALL_PREFIX")"
        echo "Choose a writable NODE_INSTALL_PREFIX or create the directory with appropriate permissions."
        exit 1
    fi

    local target_ver
    if [ -n "$NODE_VERSION" ]; then
        target_ver=$(resolve_dist_version "$NODE_VERSION")
    else
        case "$NODE_CHANNEL" in
        lts | current) target_ver=$(resolve_dist_version "$NODE_CHANNEL") ;;
        *)
            echo "Error: NODE_CHANNEL must be lts or current (got: $NODE_CHANNEL)"
            exit 1
            ;;
        esac
    fi

    local installed
    installed=$(installed_prefix_version)
    if [ -n "$installed" ] && [ "$installed" = "$target_ver" ]; then
        echo "Node.js ${target_ver} is already installed at NODE_INSTALL_PREFIX=${NODE_INSTALL_PREFIX}. Skipping."
        "${NODE_INSTALL_PREFIX}/bin/npm" --version 2>/dev/null || true
        exit 0
    fi

    echo "Installing Node.js ${target_ver} from nodejs.org/dist (includes npm)..."
    download_and_extract "$target_ver"
    prepend_path_in_shell_configs

    export PATH="${NODE_INSTALL_PREFIX}/bin:${PATH}"
    hash -r 2>/dev/null || true

    if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
        echo "Error: node or npm missing after extract."
        exit 1
    fi

    echo "Installed: $(node --version), npm $(npm --version)"
}

uninstall_npm() {
    remove_path_from_shell_configs

    if [ -d "$NODE_INSTALL_PREFIX" ] && [ -x "${NODE_INSTALL_PREFIX}/bin/node" ]; then
        rm -rf "${NODE_INSTALL_PREFIX:?}"
        echo "Removed ${NODE_INSTALL_PREFIX}"
    elif [ -d "$NODE_INSTALL_PREFIX" ]; then
        rm -rf "${NODE_INSTALL_PREFIX:?}"
        echo "Removed empty or partial ${NODE_INSTALL_PREFIX}"
    else
        echo "No installation at NODE_INSTALL_PREFIX=${NODE_INSTALL_PREFIX}."
    fi

    if command -v npm &>/dev/null; then
        echo "Note: another npm is still on PATH ($(command -v npm)). Remove it separately if needed."
    fi
}

case "${1:-install}" in
install) install_npm ;;
uninstall) uninstall_npm ;;
-h | --help) usage ;;
*)
    echo "Unknown action: ${1:-}"
    usage
    ;;
esac

if [ "${1:-install}" != "uninstall" ] && [ "${1:-install}" != "-h" ] && [ "${1:-install}" != "--help" ]; then
    echo ""
    case "${NODE_UPDATE_SHELL_RC:-true}" in
    false | False | FALSE | 0 | no | No | NO)
        echo "Add to PATH for this install: export PATH=\"${NODE_INSTALL_PREFIX}/bin:\$PATH\""
        ;;
    *)
        echo "Open a new shell or source your rc file, then run: npm --version"
        ;;
    esac
fi
