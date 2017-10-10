#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if [[ -e /mnt/share/data/.initialized ]]; then
    exit 0
fi

set -x

# this should only ever run once!
# if bootkube fails, containers must be rebuilt with `docker-compose down -v`
touch /mnt/share/data/.initialized

# clean up old running containers
docker rm -f $(docker ps -aq) || true

HOST_IP=$(docker-host.sh run --rm --net=host alpine:latest ip addr | grep '\<eth0\>' | grep inet | awk '{print $2}' | cut -d '/' -f1)
NODE_IP=$(ip addr | grep eth0 | grep inet | awk '{print $2}' | cut -d '/' -f1)

# create assets for bootkube
if [[ ! -d /root/assets ]]; then
    if [[ -d /data/assets ]]; then
        cp -a /data/assets /root
    else
        # make use of all args starting with BOOTKUBE_CONF_*
        BOOTKUBE_EXTRA_ARGS=( )
        for envname in ${!BOOTKUBE_CONF_*}; do
            if [[ "$envname" != "BOOTKUBE_CONF_POD_CIDR" ]] && [[ "$envname" != "BOOTKUBE_CONF_SERVICE_CIDR" ]]; then
                BOOTKUBE_EXTRA_ARGS+=( $(printenv "${envname}") )
            fi
        done

        # use custom CA cert to generate certs
        if [[ -e /data/tls/ca.crt ]] && [[ -e /data/tls/ca.key ]]; then
            BOOTKUBE_EXTRA_ARGS+=( --ca-certificate-path=/data/tls/ca.crt )
            BOOTKUBE_EXTRA_ARGS+=( --ca-private-key-path=/data/tls/ca.key )
        fi

        # generate assets for bootkube
        docker run --rm \
            --name=bootkube \
            -w /data \
            -v /root:/data \
            ${BOOTKUBE_IMAGE_URL}:${BOOTKUBE_IMAGE_TAG} \
            /bootkube \
            render \
            --asset-dir=assets \
            --etcd-servers=http://etcd1.:2379 \
            --api-servers=https://master.:6443 \
            --pod-cidr=${BOOTKUBE_CONF_POD_CIDR:-10.2.0.0/16} \
            --service-cidr=${BOOTKUBE_CONF_SERVICE_CIDR:-10.3.0.0/16} \
            ${BOOTKUBE_EXTRA_ARGS[@]} \
            --api-server-alt-names=IP=${HOST_IP},IP=${NODE_IP},IP=127.0.0.1,DNS=master,DNS=master.,DNS=${HOST_IP}.xip.io,DNS=${NODE_IP}.xip.io,DNS=127.0.0.1.xip.io

        # use defined version of k8s
        grep -R -l 'image: quay.io/coreos/hyperkube:' /root/assets \
            | grep '.yaml$' \
            | xargs sed -i -E "s#image: quay.io/coreos/hyperkube:.*#image: quay.io/coreos/hyperkube:${HYPERKUBE_IMAGE_TAG}#g"
        grep -R -l 'rbac.authorization.k8s.io/v1alpha1' /root/assets \
            | grep '.yaml$' \
            | xargs sed -i -E "s#rbac.authorization.k8s.io/v1alpha1#rbac.authorization.k8s.io/v1#g"
    fi
fi

# copy assets for kubelet
mkdir -p /etc/kubernetes
cat /root/assets/auth/kubeconfig > /etc/kubernetes/kubeconfig
cat /root/assets/tls/ca.crt > /etc/kubernetes/ca.crt

# set up local kubectl access
mkdir -p /root/.kube
cat /root/assets/auth/kubeconfig > /root/.kube/config

# start bootstrap control plane
docker run --rm \
    --name=bootkube \
    --net=host \
    -v /etc/kubernetes:/etc/kubernetes \
    -v /root/assets:/data \
    -w /data \
    ${BOOTKUBE_IMAGE_URL}:${BOOTKUBE_IMAGE_TAG} \
    /bootkube start --asset-dir=/data

# copy kubeconfig for other nodes
cat /root/assets/auth/kubeconfig > /mnt/share/data/kubeconfig.node

# create kubeconfig for host usage outside of container
HOST_PORT=$(self-container-info.sh | jq -r '.[0].NetworkSettings.Ports["6443/tcp"][0].HostPort')
cat /root/assets/auth/kubeconfig \
    | sed "s#server: https://master.:6443#server: https://${HOST_IP}:${HOST_PORT}#" \
    | sed "s/certificate-authority-data: .*/insecure-skip-tls-verify: true/" \
    > /data/kubeconfig

# bootstrap any manifests
if [[ -d /data/bootstrap-manifests ]]; then
    sleep 15
    env KUBECONFIG=/root/assets/auth/kubeconfig kubectl apply -R -f /data/bootstrap-manifests || true
fi

echo '===== Bootkube deployed successfully ====='
