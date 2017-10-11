#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

function b2d-k8s::is::master() {
    [[ -n ${K8S_MASTER_NODE:-} ]]
}

function b2d-k8s::is::entrypoint() {
    echo "$@" | grep -q '/bin/systemd'
}

function bd2-k8s::setup::check-overlay() {
    cat /proc/filesystems | grep -q overlay
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
        docker-host.sh run --rm --privileged -v /:/host "$(self-container-info.sh | jq -r '.[0].Config.Image')" setup-systemd.sh || true
    else
        # wait for master node to finish `setup`
        sleep 5
    fi

    # if the system doesn't support overlay, don't use it!
    if ! bd2-k8s::setup::check-overlay; then
        rm -f /etc/systemd/system/docker.service.d/10-overlay.conf
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
    else
        # update kubeconfig on boot
        if b2d-k8s::is::master; then
            export-kubeconfig.sh
        fi
    fi
}


if b2d-k8s::is::entrypoint "$@"; then
    set -x
    bd2-k8s::setup::node "$@"
    set +x
fi

# call the real command
exec "$@"
