#!/bin/bash

set -e

TFENV_DIR="$HOME/.tfenv"
TFENV_REPO="https://github.com/tfutils/tfenv.git"

install_tfenv() {
    if command -v tfenv &>/dev/null; then
        echo "tfenv is already installed. Skipping installation."
        return
    fi

    echo "Installing tfenv..."
    git clone --depth=1 "$TFENV_REPO" "$TFENV_DIR"
    echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >>"$HOME/.bash_profile"
    source "$HOME/.bash_profile"
    sudo ln -s "$TFENV_DIR/bin/"* /usr/local/bin
    tfenv install latest
    tfenv use latest
    echo "tfenv installed successfully."
}

uninstall_tfenv() {
    echo "Uninstalling tfenv..."
    if [ -d "$TFENV_DIR" ]; then
        rm -rf "$TFENV_DIR"
        sudo rm -f /usr/local/bin/terraform /usr/local/bin/tfenv
        echo "tfenv has been uninstalled."
    else
        echo "tfenv is not installed. Nothing to uninstall."
    fi
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    exit 1
}

if [ "$#" -eq 0 ]; then
    install_tfenv
elif [ "$1" == "install" ]; then
    install_tfenv
elif [ "$1" == "uninstall" ]; then
    uninstall_tfenv
else
    usage
fi

if [ "$1" != "uninstall" ]; then
    echo "Operation completed. Run 'tfenv --version' to verify installation."
fi
