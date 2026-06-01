#!/bin/bash

set -e

DOCKER_USER="${DOCKER_USER:-}"
DOCKER_SKIP_VERIFY="${DOCKER_SKIP_VERIFY:-0}"
DOCKER_REMOVE_DATA="${DOCKER_REMOVE_DATA:-0}"
DOCKER_INSTALL_METHOD="${DOCKER_INSTALL_METHOD:-}"   # auto | distro | ce

DOCKER_CE_PACKAGES=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
)

cleanup() {
    :
}
trap cleanup EXIT

detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        echo "Error: /etc/os-release not found. This script supports Linux only."
        exit 1
    fi

    # shellcheck source=/dev/null
    . /etc/os-release

    if [[ "${ID:-}" == "amzn" && "${VERSION_ID:-}" == "2023" ]]; then
        OS_ID="amzn2023"
    elif [[ "${ID:-}" == "ubuntu" ]]; then
        OS_ID="ubuntu"
    elif [[ "${ID:-}" == "fedora" ]]; then
        OS_ID="fedora"
    else
        echo "Error: Unsupported OS: ${PRETTY_NAME:-unknown}"
        echo "v1 supports: Amazon Linux 2023, Ubuntu, Fedora."
        echo "For macOS, install Docker Desktop: https://docs.docker.com/desktop/"
        exit 1
    fi

    echo "Detected OS: ${PRETTY_NAME}"
}

resolve_install_method() {
    if [ -n "$DOCKER_INSTALL_METHOD" ]; then
        echo "$DOCKER_INSTALL_METHOD"
        return
    fi

    case "$OS_ID" in
        amzn2023) echo "distro" ;;
        ubuntu | fedora) echo "ce" ;;
    esac
}

is_docker_installed() {
    command -v docker &>/dev/null
}

configure_service() {
    if command -v systemctl &>/dev/null && systemctl list-units --type=service &>/dev/null; then
        sudo systemctl enable docker
        sudo systemctl start docker
    fi
}

add_user_to_docker_group() {
    if [ -z "$DOCKER_USER" ]; then
        return
    fi

    if ! id "$DOCKER_USER" &>/dev/null; then
        echo "Warning: DOCKER_USER='$DOCKER_USER' does not exist. Skipping group assignment."
        return
    fi

    sudo usermod -aG docker "$DOCKER_USER"
    echo "Added '$DOCKER_USER' to the docker group."
    echo "Log out and back in, or run 'newgrp docker', for group membership to apply."
}

verify_install() {
    if [ "$DOCKER_SKIP_VERIFY" = "1" ]; then
        echo "Skipping hello-world verification (DOCKER_SKIP_VERIFY=1)."
        return
    fi

    echo "Verifying Docker with hello-world..."
    if sudo docker run --rm hello-world; then
        echo "Docker verification succeeded."
    else
        echo "Error: Docker verification failed."
        exit 1
    fi
}

install_docker_amzn_distro() {
    echo "Installing Docker from Amazon Linux repositories (dnf install docker)..."
    sudo dnf install -y docker
    configure_service
}

install_docker_ubuntu_ce() {
    echo "Installing Docker Engine from Docker's official apt repository..."

    sudo apt-get update
    sudo apt-get install -y ca-certificates curl

    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # shellcheck source=/dev/null
    . /etc/os-release
    sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    sudo apt-get update
    sudo apt-get install -y "${DOCKER_CE_PACKAGES[@]}"
    configure_service
}

install_docker_fedora_ce() {
    echo "Installing Docker Engine from Docker's official dnf repository..."

    sudo dnf install -y dnf-plugins-core
    sudo dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y "${DOCKER_CE_PACKAGES[@]}"
    configure_service
}

install_docker() {
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        echo "Error: Docker Engine install is supported on Linux only."
        echo "On macOS, use Docker Desktop: https://docs.docker.com/desktop/"
        exit 1
    fi

    detect_os

    if is_docker_installed; then
        echo "Docker is already installed. Skipping installation."
        docker --version 2>/dev/null || true
        add_user_to_docker_group
        exit 0
    fi

    local method
    method=$(resolve_install_method)

    case "$OS_ID:$method" in
        amzn2023:distro) install_docker_amzn_distro ;;
        amzn2023:ce)
            echo "Error: DOCKER_INSTALL_METHOD=ce is not supported on Amazon Linux 2023 in v1."
            echo "Use the default distro package (omit DOCKER_INSTALL_METHOD) or install Docker CE manually."
            exit 1
            ;;
        ubuntu:ce) install_docker_ubuntu_ce ;;
        ubuntu:distro)
            echo "Error: DOCKER_INSTALL_METHOD=distro is not supported on Ubuntu in v1."
            exit 1
            ;;
        fedora:ce) install_docker_fedora_ce ;;
        fedora:distro)
            echo "Error: DOCKER_INSTALL_METHOD=distro is not supported on Fedora in v1."
            exit 1
            ;;
        *)
            echo "Error: Unsupported OS/method combination: ${OS_ID}/${method}"
            exit 1
            ;;
    esac

    if ! is_docker_installed; then
        echo "Error: Docker installation completed but 'docker' was not found in PATH."
        exit 1
    fi

    echo "Docker installed successfully: $(docker --version)"
    add_user_to_docker_group
    verify_install
}

uninstall_docker_amzn_distro() {
    if command -v systemctl &>/dev/null; then
        sudo systemctl stop docker 2>/dev/null || true
        sudo systemctl disable docker 2>/dev/null || true
    fi
    sudo dnf remove -y docker || true
}

uninstall_docker_ubuntu_ce() {
    sudo apt-get purge -y "${DOCKER_CE_PACKAGES[@]}" docker-ce-rootless-extras 2>/dev/null || true
    sudo rm -f /etc/apt/sources.list.d/docker.sources
    sudo rm -f /etc/apt/keyrings/docker.asc
}

uninstall_docker_fedora_ce() {
    if command -v systemctl &>/dev/null; then
        sudo systemctl stop docker 2>/dev/null || true
        sudo systemctl disable docker 2>/dev/null || true
    fi
    sudo dnf remove -y "${DOCKER_CE_PACKAGES[@]}" docker-ce-rootless-extras 2>/dev/null || true
    sudo rm -f /etc/yum.repos.d/docker-ce.repo 2>/dev/null || true
}

remove_docker_data() {
    if [ "$DOCKER_REMOVE_DATA" = "1" ]; then
        echo "Removing Docker data directories (DOCKER_REMOVE_DATA=1)..."
        sudo rm -rf /var/lib/docker /var/lib/containerd
    else
        echo "Keeping /var/lib/docker and /var/lib/containerd (set DOCKER_REMOVE_DATA=1 to delete)."
    fi
}

uninstall_docker() {
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        echo "Error: Uninstall is supported on Linux only."
        exit 1
    fi

    detect_os

    if ! is_docker_installed; then
        echo "Docker is not installed. Nothing to uninstall."
        exit 0
    fi

    local method
    method=$(resolve_install_method)

    echo "Uninstalling Docker (${OS_ID}, method=${method})..."

    case "$OS_ID:$method" in
        amzn2023:distro) uninstall_docker_amzn_distro ;;
        ubuntu:ce) uninstall_docker_ubuntu_ce ;;
        fedora:ce) uninstall_docker_fedora_ce ;;
        *)
            echo "Error: Cannot determine uninstall path for ${OS_ID}/${method}."
            exit 1
            ;;
    esac

    remove_docker_data
    echo "Docker has been uninstalled."
}

usage() {
    echo "Usage: $0 [install|uninstall]"
    echo ""
    echo "Installs Docker Engine on Linux using distribution-appropriate official methods."
    echo "Does not install minikube, Kubernetes, or Docker Desktop."
    echo ""
    echo "v1 supported OS:"
    echo "  - Amazon Linux 2023  (dnf install docker)"
    echo "  - Ubuntu             (Docker apt repository)"
    echo "  - Fedora             (Docker dnf repository)"
    echo ""
    echo "Optional environment variables:"
    echo "  DOCKER_USER            - Add this user to the 'docker' group after install"
    echo "  DOCKER_SKIP_VERIFY     - Set to 1 to skip 'docker run hello-world'"
    echo "  DOCKER_REMOVE_DATA     - Set to 1 on uninstall to remove /var/lib/docker"
    echo "  DOCKER_INSTALL_METHOD  - 'distro' (AL2023 only) or 'ce' (Ubuntu/Fedora). Default: auto"
    echo ""
    echo "Examples:"
    echo "  $0 install"
    echo "  DOCKER_USER=ec2-user $0 install"
    echo "  DOCKER_SKIP_VERIFY=1 $0 install"
    echo "  DOCKER_REMOVE_DATA=1 $0 uninstall"
    exit 1
}

case "${1:-install}" in
    install) install_docker ;;
    uninstall) uninstall_docker ;;
    *) usage ;;
esac

if [ "${1:-install}" != "uninstall" ]; then
    echo ""
    echo "Run 'docker --version' and 'sudo systemctl status docker' to verify."
    echo "For minikube: install minikube, then 'minikube start --driver=docker' as a non-root user."
fi
