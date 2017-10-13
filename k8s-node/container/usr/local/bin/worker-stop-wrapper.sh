#!/usr/bin/env bash
set -euo pipefail

# do nothing on master
if [[ -n ${K8S_MASTER_NODE:-} ]]; then
    exit 0
fi

function finish {
    # not set up!
    if [[ ! -e /etc/kubernetes/kubeconfig ]]; then
        return 0
    fi

    # clean up node!
    kubectl drain --force $(hostname)
    kubectl delete node $(hostname)
}
trap finish EXIT

while :; do sleep 3600; done;
