#!/usr/bin/env bash
set -euo pipefail

# make use of all args starting with KUBELET_ARGS*
KUBELET_EXTRA_ARGS=( )
for envname in ${!KUBELET_ARGS*}; do
    KUBELET_EXTRA_ARGS+=( $(printenv "${envname}") )
done

# add node labels for master
# @todo: append labels rather than override
if [[ -n ${K8S_MASTER_NODE:-} ]]; then
    KUBELET_EXTRA_ARGS+=( --node-labels=node-role.kubernetes.io/master,master=true )
fi

# kubelet >= v1.8.0 has new flags for swap
if docker run --rm ${HYPERKUBE_IMAGE_URL}:${HYPERKUBE_IMAGE_TAG} /hyperkube kubelet --help 2>&1 | grep -q -- --fail-swap-on; then
    KUBELET_EXTRA_ARGS+=( --fail-swap-on=false )
fi

# generate hostname with docker-compose container name
KUBELET_HOSTNAME="$(self-container-info.sh | jq -r '.[0].Name' | cut -f2 -d'/' | sed -e 's/[^A-Za-z0-9]/-/g')-$(hostname)"

set -x

exec /usr/bin/docker run \
    --rm \
    --name kubelet \
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
        --cgroups-per-qos=false \
        --client-ca-file=/etc/kubernetes/ca.crt \
        --cluster_dns=10.3.0.10 \
        --cluster_domain=cluster.local \
        --cni-conf-dir=/etc/kubernetes/cni/net.d \
        --enforce-node-allocatable= \
        --eviction-hard="memory.available<5%" \
        --eviction-soft="memory.available<7%" \
        --eviction-soft-grace-period=memory.available=2m \
        --eviction-pressure-transition-period=5m \
        --exit-on-lock-contention \
        --hostname-override=${KUBELET_HOSTNAME:-$(hostname)} \
        --kubeconfig=/etc/kubernetes/kubeconfig \
        --lock-file=/var/run/lock/kubelet.lock \
        --network-plugin=cni \
        --pod-manifest-path=/etc/kubernetes/manifests \
        --require-kubeconfig \
        ${KUBELET_EXTRA_ARGS[@]}
