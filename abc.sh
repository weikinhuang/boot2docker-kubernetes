#!/bin/bash

docker rm -f $(docker ps -aq)

docker run -it --rm \
  -w /data \
  -v /root:/data \
  quay.io/coreos/bootkube:v0.6.2 \
  /bootkube \
  render \
  --asset-dir=assets \
  --experimental-self-hosted-etcd \
  --api-servers=https://k8s-master:6443 \
  --pod-cidr=10.2.0.0/16 \
  --service-cidr=10.3.0.0/16 \
  --api-server-alt-names=IP=$(ip addr | grep eth0 | grep inet | awk '{print $2}' | cut -d '/' -f1),IP=127.0.0.1,DNS=k8s-master

mkdir -p /etc/kubernetes
cp /root/assets/auth/kubeconfig /etc/kubernetes/kubeconfig
cp /root/assets/tls/ca.crt /etc/kubernetes/ca.crt
docker run --rm \
  --net=host \
  -v /etc/kubernetes:/etc/kubernetes \
  -v /root/assets:/data \
  -w /data \
  quay.io/coreos/bootkube:v0.6.2 \
  /bootkube start --asset-dir=/data

cp -f /root/assets/auth/kubeconfig /mnt/share/data/kubeconfig.node

HOST_IP=$(docker -H unix:///mnt/HOST_DOCKER.sock run -it --rm --net=host alpine:latest ip addr | grep '\<eth0\>' | grep inet | awk '{print $2}' | cut -d '/' -f1)
cat /root/assets/auth/kubeconfig \
    | sed "s#server: https://k8s-master:6443#server: https://${HOST_IP}:6443#" \
    | sed "s/certificate-authority-data: .*/insecure-skip-tls-verify: true/" \
    > /data/kubeconfig
