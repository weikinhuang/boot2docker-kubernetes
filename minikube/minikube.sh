#!/usr/bin/env bash
set -euo pipefail

#==============================================================================
# Constants
#==============================================================================
SELF="$0"

# docker versions
VERSION_KUBERNETES="v1.10.1"
VERSION_ETCD3="v3.3.3"

#==============================================================================
# Variables
#==============================================================================
MINIKUBE_MACHINE_NAME="${DOCKER_MACHINE_NAME:-default}"

#==============================================================================
# minikube internal functions
#==============================================================================
function docker-machine::ssh() {
  docker-machine ssh "${MINIKUBE_MACHINE_NAME}" "$@"
}

function docker-machine::ip() {
  docker-machine ip "${MINIKUBE_MACHINE_NAME}"
}

function minikube::setup() {
# setup
if ! docker-machine::ssh test -e /etc/kubernetes/kubeconfig &>/dev/null; then

docker-machine::ssh <<EOF
set -euo pipefail

cat <<EOF_ETCD3 >/tmp/etcd3.service
cat etcd3.service
[Unit]
Description=etcd (System Application Container)
Documentation=https://github.com/coreos/etcd
Wants=network.target
Conflicts=etcd.service
Conflicts=etcd2.service

[Service]
Type=notify
Restart=on-failure
RestartSec=10s
TimeoutStartSec=0
LimitNOFILE=40000

Environment="ETCD_IMAGE_TAG=${VERSION_ETCD3}"
Environment="ETCD_NAME=%m"
Environment="ETCD_USER=etcd"
Environment="ETCD_DATA_DIR=/var/lib/etcd"
Environment="RKT_RUN_ARGS=--uuid-file-save=/var/lib/coreos/etcd-member-wrapper.uuid"
Environment="ETCD_INITIAL_CLUSTER=%m=http://127.0.0.1:2380"
Environment="ETCD_INITIAL_CLUSTER_STATE=new"

ExecStartPre=/usr/bin/mkdir --parents /var/lib/coreos
ExecStartPre=-/usr/bin/rkt rm --uuid-file=/var/lib/coreos/etcd-member-wrapper.uuid
ExecStart=/usr/lib/coreos/etcd-wrapper \\\$ETCD_OPTS \\\\
  --advertise-client-urls=http://127.0.0.1:2379 \\\\
  --initial-advertise-peer-urls=http://127.0.0.1:2380 \\\\
  --listen-client-urls=http://0.0.0.0:2379 \\\\
  --listen-peer-urls=http://0.0.0.0:2380 \\\\
  --auto-compaction-retention 1
ExecStop=-/usr/bin/rkt stop --uuid-file=/var/lib/coreos/etcd-member-wrapper.uuid

[Install]
WantedBy=multi-user.target
EOF_ETCD3

cat <<EOF_KUBELET >/tmp/kubelet.service
[Unit]
Description=Kubelet via Hyperkube ACI
[Service]
Environment="RKT_RUN_ARGS=\\\\
  --uuid-file-save=/var/run/kubelet-pod.uuid \\\\
  --insecure-options=image \\\\
  --volume resolv,kind=host,source=/etc/resolv.conf \\\\
  --mount volume=resolv,target=/etc/resolv.conf \\\\
  --volume var-lib-cni,kind=host,source=/var/lib/cni \\\\
  --mount volume=var-lib-cni,target=/var/lib/cni \\\\
  --volume opt-cni-bin,kind=host,source=/opt/cni/bin \\\\
  --mount volume=opt-cni-bin,target=/opt/cni/bin \\\\
"
EnvironmentFile=/etc/kubernetes/kubelet.env
ExecStartPre=/bin/mkdir -p /etc/kubernetes/manifests
ExecStartPre=/bin/mkdir -p /etc/kubernetes/cni/net.d
ExecStartPre=/bin/mkdir -p /etc/kubernetes/checkpoint-secrets
ExecStartPre=/bin/mkdir -p /etc/kubernetes/inactive-manifests
ExecStartPre=/bin/mkdir -p /opt/cni/bin
ExecStartPre=/bin/mkdir -p /var/lib/kubelet/pki
ExecStartPre=/bin/mkdir -p /var/lib/cni
ExecStartPre=/usr/bin/bash -c "grep 'certificate-authority-data' /etc/kubernetes/kubeconfig | awk '{print \\\$2}' | base64 -d > /etc/kubernetes/ca.crt"
ExecStartPre=-/usr/bin/rkt rm --uuid-file=/var/run/kubelet-pod.uuid
ExecStart=/usr/lib/coreos/kubelet-wrapper \\\\
  --allow-privileged \\\\
  --anonymous-auth=false \\\\
  --authentication-token-webhook=true \\\\
  --authorization-mode=AlwaysAllow \\\\
  --cert-dir=/var/lib/kubelet/pki \\\\
  --client-ca-file=/etc/kubernetes/ca.crt \\\\
  --cluster_dns=10.3.0.10 \\\\
  --cluster_domain=cluster.local \\\\
  --cni-conf-dir=/etc/kubernetes/cni/net.d \\\\
  --exit-on-lock-contention \\\\
  --kubeconfig=/etc/kubernetes/kubeconfig \\\\
  --lock-file=/var/run/lock/kubelet.lock \\\\
  --network-plugin=cni \\\\
  --node-labels=node-role.kubernetes.io/master \\\\
  --pod-manifest-path=/etc/kubernetes/manifests \\\\
  --rotate-certificates \\\\
  \\\\
  # do not delete this comment: the line above is dynamic
ExecStop=-/usr/bin/rkt stop --uuid-file=/var/run/kubelet-pod.uuid
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF_KUBELET

cat <<EOF_KUBELET_ENV >/tmp/kubelet.env
KUBELET_IMAGE_URL=docker://k8s.gcr.io/hyperkube
KUBELET_IMAGE_TAG=${VERSION_KUBERNETES}
EOF_KUBELET_ENV

set -x

sudo mkdir -p /etc/kubernetes
sudo mv /tmp/kubelet.env /etc/kubernetes/kubelet.env
sudo mv /tmp/etcd3.service /etc/systemd/system/etcd3.service
sudo mv /tmp/kubelet.service /etc/systemd/system/kubelet.service
sudo systemctl daemon-reload
sudo systemctl start etcd3
sudo systemctl start kubelet

docker run --rm \
    -v "/home/core:/data" \
    -w /data \
    "quay.io/coreos/bootkube:v0.12.0" \
    /bootkube render \
        --asset-dir=assets \
        --api-servers=https://127.0.0.1:6443 \
        --etcd-servers=http://127.0.0.1:2379 \
        --pod-cidr=10.2.0.0/16 \
        --service-cidr=10.3.0.0/16 \
        --api-server-alt-names='IP=$(docker-machine::ip),IP=127.0.0.1'

# use defined version of k8s
sudo grep -R -l 'image: k8s.gcr.io/hyperkube:' /home/core/assets \
    | grep '.yaml$' \
    | xargs -r sudo sed -i -E "s#image: k8s.gcr.io/hyperkube:.*#image: k8s.gcr.io/hyperkube:${VERSION_KUBERNETES}#g" \
|| true

sudo cp /home/core/assets/auth/kubeconfig-kubelet /etc/kubernetes/kubeconfig

docker run --rm \
    --net=host \
    -v /etc/kubernetes:/etc/kubernetes \
    -v /home/core/assets:/data \
    -w /data \
    "quay.io/coreos/bootkube:v0.12.0" \
    /bootkube start --asset-dir=/data
EOF

else

docker-machine::ssh <<EOF
set -euo pipefail
set -x
sudo systemctl start etcd3
sudo systemctl start kubelet

EOF

fi
}

function minikube::pull-config() {
    mkdir -p ~/.kube

    local KUBECONFIG_FILE="$(docker-machine::ssh sudo cat /home/core/assets/auth/kubeconfig)"

    echo "${KUBECONFIG_FILE}" \
        | sed "s#server: https://127.0.0.1:6443#server: https://$(docker-machine::ip):6443#" \
        > ~/.kube/config
}

function minikube::stop() {
docker-machine::ssh <<EOF
set -euo pipefail
set -x

sudo systemctl stop kubelet
sudo systemctl stop etcd3

docker ps --format "{{.Names}}" | grep '^k8s_' | xargs docker rm -f

EOF
}

#==============================================================================
# docker functions
#==============================================================================
function minikube::cmd() {
  docker-machine::ssh sudo minikube "$@"
}

#==============================================================================
# Entrypoint
#==============================================================================
function main() {
  local SHELL_MINIKUBE_ACTION="$1"
  shift

  case "${SHELL_MINIKUBE_ACTION}" in
    start)
      minikube::setup
      minikube::pull-config
    ;;
    stop)
      minikube::stop
    ;;
    *)
      # default run minikube command on remote host
      minikube::cmd "${SHELL_MINIKUBE_ACTION}" "$@"
    ;;
  esac
}

#==============================================================================
# Run Script
#==============================================================================
main "$@"
