#!/usr/bin/env bash
set -euo pipefail
#IFS=$'\n\t'

env

set -x

exec /usr/bin/docker run \
    --net=host \
    --pid=host \
    --privileged \
    -v /dev:/dev \
    -v /sys:/sys:ro \
    -v /var/run:/var/run:rw \
    -v /var/lib/docker/:/var/lib/docker:rw \
    -v /var/lib/kubelet/:/var/lib/kubelet:shared \
    -v /var/log:/var/log:shared \
    -v /srv/kubernetes:/srv/kubernetes:ro \
    -v /etc/kubernetes:/etc/kubernetes:ro \
    -v /etc/resolv.conf:/etc/resolv.conf:ro \
    -v /var/lib/cni:/var/lib/cni:rw \
    -v /opt/cni/bin:/opt/cni/bin:rw \
    ${HYPERKUBE_IMAGE_URL}:${HYPERKUBE_IMAGE_TAG} \
    /hyperkube kubelet \
        --allow-privileged \
        --anonymous-auth=false \
        --client-ca-file=/etc/kubernetes/ca.crt \
        --cluster_dns=10.3.0.10 \
        --cluster_domain=cluster.local \
        --cni-conf-dir=/etc/kubernetes/cni/net.d \
        --exit-on-lock-contention \
        --kubeconfig=/etc/kubernetes/kubeconfig \
        --lock-file=/var/run/lock/kubelet.lock \
        --network-plugin=cni \
        --pod-manifest-path=/etc/kubernetes/manifests \
        --eviction-hard="memory.available<5%" \
        --eviction-soft="memory.available<7%" \
        --eviction-soft-grace-period=memory.available=2m \
        --eviction-pressure-transition-period=5m \
        --require-kubeconfig \
        --cgroups-per-qos=false \
        --enforce-node-allocatable= \
        ${KUBELET_ARGS_EXTRA:-} \
        ${KUBELET_ARGS_COMPOSE:-} \
        ${KUBELET_ARGS:-}
