#!/bin/bash

readonly CONFIGURATION_FILE_PATH="/root/seaweedfs-mount.conf"

readonly NOTIFICATION_SERVER="https://gotify.lab.escapethelan.com/message?token=AAhPsaLzoXi3sks"

readonly SEAWEEDFS_MASTERS=(lxc-seaweedfs-master-01 lxc-seaweedfs-master-02 lxc-seaweedfs-master-03)
readonly SEAWEEDFS_VOLUMES=(lxc-seaweedfs-volume-01 lxc-seaweedfs-volume-02 lxc-seaweedfs-volume-03)
readonly SEAWEEDFS_FILERS=(lxc-seaweedfs-filer-01 lxc-seaweedfs-filer-02 lxc-seaweedfs-filer-03)

readonly MINIMUM_NUM_OF_MASTERS=1
readonly MINIMUM_NUM_OF_VOLUMES=2
readonly MINIMUM_NUM_OF_FILERS=1

function send_notification() {
    local title="$1"
    local message="$2"
    
    curl "${NOTIFICATION_SERVER}" -F "title=${title}" -F "message=${message}" -F "priority=5" >/dev/null 2>&1
}

function is_online() {
    local host=$1
    tailscale ping --c 1 --timeout 5s --until-direct "${host}" >/dev/null 2>&1
}

function check_availability() {
    local min_online_nodes=$1
    local -n array=$2

    local count=0

    for node in "${array[@]}"; do
        if is_online "${node}"; then
            count=$((count+1))
            if [[ ${count} -eq ${min_online_nodes} ]]; then
                return 0
            fi
        fi
    done

    return 1
}

function check_seaweedfs_master_availability() {
    check_availability ${MINIMUM_NUM_OF_MASTERS} SEAWEEDFS_MASTERS
}

function check_seaweedfs_volume_availability() {
    check_availability ${MINIMUM_NUM_OF_VOLUMES} SEAWEEDFS_VOLUMES
}

function check_seaweedfs_filer_availability() {
    check_availability ${MINIMUM_NUM_OF_FILERS} SEAWEEDFS_FILERS
}

function check_seaweedfs_cluster_health() {
    if ! check_seaweedfs_master_availability; then
        echo "ERROR: The minimum available master node is less then ${MINIMUM_NUM_OF_MASTERS}."
        return 1
    fi
    if ! check_seaweedfs_volume_availability; then
        echo "ERROR: The minimum available volume node is less then ${MINIMUM_NUM_OF_VOLUMES}."
        return 1
    fi
    if ! check_seaweedfs_filer_availability; then
        echo "ERROR: The minimum available filer node is less then ${MINIMUM_NUM_OF_FILERS}."
        return 1
    fi
}

function wait_for_seaweedfs_cluster_to_come_online() {
    elapsed_time=1
    for ((i = 1 ; i <= 60 ; i++ )); do 
        if check_seaweedfs_cluster_health; then
            echo "SeaweedFs cluster health is sufficient after ${elapsed_time}s."
            echo "There are enough online master, volume and filer nodes to operate."
            echo "Waiting an additional 5s just in case before continue."
            sleep 5
            return 0
        else
            echo "SeaweedFs cluster health is not sufficient after ${elapsed_time}s! Waiting ${i}s before continue...."
            sleep $i
            elapsed_time=$((elapsed_time+i))
        fi
    done

    return 1
}

function wait_for_mount_to_come_online() {
    elapsed_time=1
    for ((i = 1 ; i <= 60 ; i++ )); do 
        if mountpoint -q "${MOUNT_PATH}"; then
            echo "SeaweedFs volume mounted at ${MOUNT_PATH} after ${elapsed_time}s."
            echo "Waiting an additional 5s just in case before starting docker."
            sleep 5
            systemctl start docker.socket
            systemctl start docker.service
            return 0
        else
            echo "SeaweedFs volume is not mounted after ${elapsed_time}s! Waiting ${i}s before continue...."
            elapsed_time=$((elapsed_time+i))
            if [[ $i -eq 15 ]] || [[ $i -eq 25 ]] || [[ $i -eq 35 ]] || [[ $i -eq 45 ]] || [[ $i -eq 55 ]]; then
                echo "Trying to fix mount error by restarting SeaweedFs service..."
                systemctl stop seaweedfs-mount.service
                umount "${MOUNT_PATH}" >/dev/null 2>&1
                sleep $i
                systemctl start seaweedfs-mount.service
            else
                sleep $i
            fi
        fi
    done

    return 1
}

function init() {
    # shellcheck disable=SC1090
    source "${CONFIGURATION_FILE_PATH}"
}

function main() {
    if ! wait_for_seaweedfs_cluster_to_come_online; then
        send_notification "SeaweedFs mount error" "Failed to mount SeaweedFs volume on $(hostname) docker host! SeaweedFs cluster health is not sufficient!"
        exit 1
    fi
    if ! wait_for_mount_to_come_online; then
        send_notification "SeaweedFs mount error" "Failed to mount SeaweedFs volume on $(hostname) docker host! SeaweedFs volume is not available!"
        exit 1
    fi
    
}

init
main