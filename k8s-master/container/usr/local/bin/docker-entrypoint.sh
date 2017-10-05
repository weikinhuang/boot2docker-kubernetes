#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

function b2d-k8s::is::master() {
    [[ -n ${K8S_MASTER_NODE:-} ]]
}

function b2d-k8s::is::entrypoint() {
    echo "$@" | grep -q '/sbin/init'
}

function bd2-k8s::setup::master-node() {
    rm -f /mnt/share/data/kubeconfig.node
    systemctl enable bootkube.service
}

function bd2-k8s::setup::worker-node() {
    systemctl enable kubeconfig.path
}

function bd2-k8s::setup::node() {
    if b2d-k8s::is::master; then
        # setup systemd cgroup hierarchy at /sys/fs/cgroup/systemd
        docker-host.sh run --rm --privileged -v /:/host "${SYSTEMD_SETUP_IMAGE}" setup || true
    else
        # wait for master node to finish `setup`
        sleep 5
    fi

    if [[ ! -e /.node-setup ]]; then
        if b2d-k8s::is::master; then
            # set up master node configs
            bd2-k8s::setup::master-node
        else
            # set up worker node configs
            bd2-k8s::setup::worker-node
        fi

        env | grep '^BOOTKUBE_' > /etc/systemd/system/bootkube.env || true
        env | grep '^HYPERKUBE_' > /etc/systemd/system/hyperkube.env || true
        env | grep '^KUBELET_' > /etc/systemd/system/kubelet.env || true

        echo "K8S_MASTER_NODE=${K8S_MASTER_NODE:-}" >> /etc/systemd/system/kubelet.env || true

        touch /.node-setup
    fi
}


if b2d-k8s::is::entrypoint "$@"; then
    set -x
    bd2-k8s::setup::node "$@"
    set +x
fi

# call the real command
exec "$@"
