#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if [[ -e /.initialized ]]; then
    exit 0
fi

# clean up old running containers
docker rm -f $(docker ps -aq) || true

# create assets for bootkube
if [[ -d /data/assets ]]; then
    cp -a /data/assets /root
else
    # generate assets for bootkube
    docker run --rm \
        -w /data \
        -v /root:/data \
        ${BOOTKUBE_IMAGE_URL}:${BOOTKUBE_IMAGE_TAG} \
        /bootkube \
        render \
        --asset-dir=assets \
        --experimental-self-hosted-etcd \
        --api-servers=https://k8s-master:6443 \
        --pod-cidr=${BOOTKUBE_CONF_POD_CIDR:-10.2.0.0/16} \
        --service-cidr=${BOOTKUBE_CONF_SERVICE_CIDR:-10.3.0.0/16} \
        --network-provider=experimental-calico \
        ${BOOTKUBE_CONF_ADDITIONAL_ARGS:-} \
        --api-server-alt-names=IP=$(ip addr | grep eth0 | grep inet | awk '{print $2}' | cut -d '/' -f1),IP=127.0.0.1,DNS=k8s-master

    # use defined version of k8s
    grep -R -l 'image: quay.io/coreos/hyperkube:' /root/assets \
        | grep '.yaml$' \
        | xargs sed -i -E "s#image: quay.io/coreos/hyperkube:.*#image: quay.io/coreos/hyperkube:${HYPERKUBE_IMAGE_TAG}#g"
    grep -R -l 'rbac.authorization.k8s.io/v1alpha1' /root/assets \
        | grep '.yaml$' \
        | xargs sed -i -E "s#rbac.authorization.k8s.io/v1alpha1#rbac.authorization.k8s.io/v1#g"
fi

# copy assets for kubelet
mkdir -p /etc/kubernetes
cp /root/assets/auth/kubeconfig /etc/kubernetes/kubeconfig
cp /root/assets/tls/ca.crt /etc/kubernetes/ca.crt

# start bootstrap control plane
docker run --rm \
    --net=host \
    -v /etc/kubernetes:/etc/kubernetes \
    -v /root/assets:/data \
    -w /data \
    ${BOOTKUBE_IMAGE_URL}:${BOOTKUBE_IMAGE_TAG} \
    /bootkube start --asset-dir=/data

# copy kubeconfig for other nodes
cat /root/assets/auth/kubeconfig > /mnt/share/data/kubeconfig.node

# create kubeconfig for host usage outside of container
HOST_IP=$(docker -H unix:///mnt/HOST_DOCKER.sock run --rm --net=host alpine:latest ip addr | grep '\<eth0\>' | grep inet | awk '{print $2}' | cut -d '/' -f1)
cat /root/assets/auth/kubeconfig \
    | sed "s#server: https://k8s-master:6443#server: https://${HOST_IP}:6443#" \
    | sed "s/certificate-authority-data: .*/insecure-skip-tls-verify: true/" \
    > /data/kubeconfig

# this should only ever run once!
touch /.initialized

# bootstrap any manifests
if [[ -d /data/bootstrap-manifests ]]; then
    sleep 15
    KUBECONFIG=/root/assets/auth/kubeconfig kubectl apply -R -f /data/bootstrap-manifests || true
fi
