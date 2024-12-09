#!/bin/bash

for ((i = 0 ; i < 30 ; i++ )); do 
    if mountpoint -q /opt/docker/volumes; then
        echo "SeaweedFs volume mounted at /opt/docker/volumes after ${i}s."
        echo "Waiting an additional 5s just in case before exiting."
        sleep 5
        systemctl start docker.socket
        systemctl start docker.service
        break
    else
        echo "SeaweedFs volume not mounted! Waiting ${i}s before continue...."
        sleep $i
    fi
done