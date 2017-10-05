#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# start over when we reload!
rm -rf /var/lib/kubelet/* || true
rm -rf /etc/kubernetes/* || true
rm -rf /var/lib/cni/* || true
rm -rf /opt/cni/bin/* || true

# clean up old running containers
docker kill $(docker ps -aq) || true
docker rm $(docker ps -aq) || true
docker volume rm $(docker volume ls -f dangling=true -q) || true
