#!/usr/bin/env bash
set -euo pipefail

#==============================================================================
# Constants
#==============================================================================
SELF="$0"

# docker versions
VERSION_KUBERNETES="v1.9.0"

#==============================================================================
# Variables
#==============================================================================
MINIKUBE_MACHINE_NAME="${MINIKUBE_MACHINE_NAME:-default}"

#==============================================================================
# minikube internal functions
#==============================================================================
function docker-machine::start() {
  docker-machine start "${MINIKUBE_MACHINE_NAME}" "$@"
}

function docker-machine::ssh() {
  docker-machine ssh "${MINIKUBE_MACHINE_NAME}" "$@"
}

function docker-machine::ip() {
  docker-machine ip "${MINIKUBE_MACHINE_NAME}"
}

function minikube::setup() {
# setup
if ! docker-machine::ssh which minikube &>/dev/null; then

docker-machine::ssh <<EOF
set -euo pipefail

# install bash
tce-load -wi bash

# make persistent data directories
sudo mkdir -p /mnt/sda1/minikube/bin
sudo mkdir -p /mnt/sda1/minikube/localkube
sudo mkdir -p /mnt/sda1/minikube/.minikube
sudo mkdir -p /mnt/sda1/minikube/.kube

# download files
if [ ! -e /mnt/sda1/minikube/bin/kubectl ]; then
    sudo curl -Lo /mnt/sda1/minikube/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
    sudo chmod +x /mnt/sda1/minikube/bin/kubectl
fi
if [ ! -e /mnt/sda1/minikube/bin/minikube ]; then
    sudo curl -Lo /mnt/sda1/minikube/bin/minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo chmod +x /mnt/sda1/minikube/bin/minikube
fi

# link up binaries
if [ ! -L /usr/local/bin/kubectl ]; then
    sudo ln -s /mnt/sda1/minikube/bin/kubectl /usr/local/bin/kubectl
fi
if [ ! -L /usr/local/bin/minikube ]; then
    sudo ln -s /mnt/sda1/minikube/bin/minikube /usr/local/bin/minikube
fi

# localkube data dir
if [ ! -L /var/lib/localkube ]; then
    sudo ln -s /mnt/sda1/minikube/localkube /var/lib/localkube
fi

# minikube conf
if [ ! -L /root/.kube ]; then
    sudo ln -s /mnt/sda1/minikube/.kube /root/.kube
fi
if [ ! -L /root/.minikube ]; then
    sudo ln -s /mnt/sda1/minikube/.minikube /root/.minikube
fi

EOF

fi
}

function minikube::pull-config() {
    mkdir -p ~/.kube

    local KUBECONFIG_FILE="$(docker-machine::ssh sudo cat /mnt/sda1/minikube/.kube/config)"
    local KUBE_CA_FILE="$(docker-machine::ssh sudo cat /mnt/sda1/minikube/.minikube/ca.crt | base64 -w0)"
    local KUBE_CLIENT_CERT_FILE="$(docker-machine::ssh sudo cat /mnt/sda1/minikube/.minikube/client.crt | base64 -w0)"
    local KUBE_CLIENT_KEY_FILE="$(docker-machine::ssh sudo cat /mnt/sda1/minikube/.minikube/client.key | base64 -w0)"

    echo "${KUBECONFIG_FILE}" \
        | sed "s#certificate-authority: /root/.minikube/ca.crt#certificate-authority-data: ${KUBE_CA_FILE}#" \
        | sed "s#client-certificate: /root/.minikube/client.crt#client-certificate-data: ${KUBE_CLIENT_CERT_FILE}#" \
        | sed "s#client-key: /root/.minikube/client.key#client-key-data: ${KUBE_CLIENT_KEY_FILE}#" > ~/.kube/config
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

  minikube::setup

  case "${SHELL_MINIKUBE_ACTION}" in
    start)
      # send the remapped volume paths
      docker-machine::start
      sleep 5
      # start with pre-configured parameters
      minikube::cmd start --vm-driver=none --apiserver-ips $(docker-machine::ip) --apiserver-name docker.lan "$@"
      sleep 2
      minikube::pull-config
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
