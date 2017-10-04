#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

set -x

if [[ ! -e /.node-setup ]]; then
    setup || true
    if [[ /data/overlay ]]; then
        cp -av /data/overlay/ /etc/
    fi
    if [[ -n ${K8S_MASTER_NODE:-} ]]; then
        cp -av /etc/.overlay/master/* /etc/
        . setup-master-node.sh
    else
        cp -av /etc/.overlay/worker/* /etc/
        . setup-worker-node.sh
    fi

    env | grep '^BOOTKUBE_' > /etc/systemd/system/bootkube.env
    env | grep '^HYPERKUBE_' > /etc/systemd/system/hyperkube.env

    touch /.node-setup
fi

# call the real command
exec "$@"
