#!/bin/bash

readonly SEAWEEDFS_ARCHIVE_URL="https://github.com/seaweedfs/seaweedfs/releases/download/3.80/linux_amd64.tar.gz"
readonly SEAWEEDFS_BIN_PATH="/usr/sbin/weed"
readonly SCRIPT_BIN_PATH="/usr/sbin/wait_for_weed_mount"
readonly CONF_FILE_PATH="/root/seaweedfs-mount.conf"

readonly MOUNT_SERVICE_PATH="/etc/systemd/system/seaweedfs-mount.service"
readonly DOCKER_SERVICE_PATH="/etc/systemd/system/seaweedfs-docker.service"

readonly SCRIPT_URL="https://raw.githubusercontent.com/zbalint/docker-compose-projects/refs/heads/master/seaweedfs/systemd/wait_for_weed_mount.sh"
readonly MOUNT_SERVICE_URL="https://raw.githubusercontent.com/zbalint/docker-compose-projects/refs/heads/master/seaweedfs/systemd/seaweedfs-mount.service"
readonly DOCKER_SERVICE_URL="https://raw.githubusercontent.com/zbalint/docker-compose-projects/refs/heads/master/seaweedfs/systemd/seaweedfs-docker.service"
readonly CONF_FILE_URL="https://raw.githubusercontent.com/zbalint/docker-compose-projects/refs/heads/master/seaweedfs/systemd/seaweedfs-mount.conf"

function cleanup() {
    rm -f "weed.tar.gz"
    rm -f "${SCRIPT_BIN_PATH}"
    rm -f "${MOUNT_SERVICE_PATH}"
    rm -f "${DOCKER_SERVICE_PATH}"
    rm -f "${CONF_FILE_PATH}"
}

function download_dependencies() {
    mkdir .seaweedfs && cd .seaweedfs/ || return 1
    wget -O "weed.tar.gz" "${SEAWEEDFS_ARCHIVE_URL}" && tar -xvf "weed.tar.gz" && mv weed "${SEAWEEDFS_BIN_PATH}" || return 1
    wget -O "${SCRIPT_BIN_PATH}" "${SCRIPT_URL}" && chmod +x "${SCRIPT_BIN_PATH}" || return 1
    wget -O "${MOUNT_SERVICE_PATH}" "${MOUNT_SERVICE_URL}" || return 1
    wget -O "${DOCKER_SERVICE_PATH}" "${DOCKER_SERVICE_URL}" || return 1
    if ! test -f "${CONF_FILE_PATH}"; then
        wget -O "${CONF_FILE_PATH}" "${CONF_FILE_URL}" || return 1
    fi
    cd - || return 1

    return 0
}

function disable_services() {
    systemctl stop seaweedfs-mount.service && \
    systemctl stop seaweedfs-docker.service && \
    systemctl disable seaweedfs-mount.service && \
    systemctl disable seaweedfs-docker.service && \
    systemctl daemon-reload 
}

function enable_services() {
    systemctl daemon-reload && \
    systemctl enable seaweedfs-mount.service --now && \
    systemctl enable seaweedfs-docker.service --now
}

function disable_docker() {
    systemctl disable docker.service && \
    systemctl disable docker.socket
}

function enable_docker() {
    systemctl enable docker.socket --now && \
    systemctl enable docker.service --now 
}


function main() {
    echo "Download dependencies..."
    if ! download_dependencies; then
        cleanup 
        exit 1
    fi
    echo "Enable services..."
    if ! enable_services; then
        disable_services
        cleanup
        exit 1
    fi
    echo "Disable docker services..."
    if ! disable_docker; then
        disable_services
        cleanup
        enable_docker
        exit 1
    fi
}

main