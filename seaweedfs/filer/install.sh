#!/bin/bash

mkdir -p /root/seaweedfs/{bin,conf,data} && cd /root/seaweedfs

cd /root/seaweedfs/bin && wget -O weed.tar.gz https://github.com/seaweedfs/seaweedfs/releases/download/3.80/linux_amd64.tar.gz && tar -xvf weed.tar.gz && rm -f weed.tar.gz && cd -

wget -O /etc/systemd/system/seaweedfs-filer.service "https://raw.githubusercontent.com/zbalint/docker-compose-projects/refs/heads/master/seaweedfs/filer/seaweedfs-filer.service"

/etc/systemd/system/seaweedfs-filer.service
/etc/systemd/system/seaweedfs-master.service
/etc/systemd/system/seaweedfs-volume.service

systemctl daemon-reload && systemctl enable seaweedfs-filer.service --now && journalctl -u seaweedfs-filer -f

systemctl daemon-reload && systemctl enable seaweedfs-master.service --now && journalctl -u seaweedfs-master -f

systemctl daemon-reload && systemctl enable seaweedfs-volume.service --now && journalctl -u seaweedfs-volume -f