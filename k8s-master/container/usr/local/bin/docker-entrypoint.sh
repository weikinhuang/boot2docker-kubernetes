#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

set -x

if [[ -n ${K8S_MASTER_NODE:-} ]] && echo "$@" | grep -q '/sbin/init'; then
    # setup systemd cgroup hierarchy at /sys/fs/cgroup/systemd
    docker-host.sh run --rm --privileged -v /:/host "${SYSTEMD_SETUP_IMAGE}" setup || true
else
    # wait for master node to finish `setup`
    sleep 5
fi

if [[ ! -e /.node-setup ]]; then
    if [[ -d /data/overlay ]]; then
        cp -av /data/overlay/* /etc/
    fi
    if [[ -n ${K8S_MASTER_NODE:-} ]]; then
        # set up master node configs
        rm -f /mnt/share/data/kubeconfig.node
        cp -av /etc/.overlay/master/* /etc/
        . setup-master-node.sh
    else
        # set up worker node configs
        cp -av /etc/.overlay/worker/* /etc/
        . setup-worker-node.sh
    fi

    env | grep '^BOOTKUBE_' > /etc/systemd/system/bootkube.env || true
    env | grep '^HYPERKUBE_' > /etc/systemd/system/hyperkube.env || true
    env | grep '^KUBELET_' > /etc/systemd/system/kubelet.env || true

    touch /.node-setup
fi

# call the real command
exec "$@"
