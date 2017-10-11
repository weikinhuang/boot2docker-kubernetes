#!/usr/bin/env bash
set -euo pipefail

if [[ ! -e /root/assets/auth/kubeconfig ]]; then
    exit 0
fi

# create kubeconfig for host usage outside of container
HOST_IP=$(docker-host-ip.sh)
HOST_PORT=$(self-container-info.sh | jq -r '.[0].NetworkSettings.Ports["6443/tcp"][0].HostPort')
cat /root/assets/auth/kubeconfig \
    | sed "s#server: https://master.:6443#server: https://${HOST_IP}:${HOST_PORT}#" \
    | sed "s/certificate-authority-data: .*/insecure-skip-tls-verify: true/" \
    > /data/kubeconfig
