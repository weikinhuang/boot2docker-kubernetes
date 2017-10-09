#!/usr/bin/env bash

function get-node-status() {
    docker-compose exec master bash -c "env KUBECONFIG=/root/assets/auth/kubeconfig kubectl get nodes"
}

function get-pods() {
    docker-compose exec master bash -c "env KUBECONFIG=/root/assets/auth/kubeconfig kubectl get pods --all-namespaces -o wide"
}

COUNTER=0
EXIT_STATUS=1
while [  $COUNTER -lt 30 ]; do
    get-node-status
    docker-compose exec master bash -c "docker ps"
    READY_NODES=$(get-node-status | grep '\<Ready\>' | wc -l)
    if [[ ${READY_NODES} == 2 ]]; then
        EXIT_STATUS=0
        break
    fi
    let COUNTER=COUNTER+1
    sleep 10
done

if [[ ${EXIT_STATUS} == 0 ]]; then
    get-pods
    echo "Cluster successfully bootstrapped!"
else
    echo "There no nodes ready!"
fi
docker-compose exec master bash -c "docker images"
exit ${EXIT_STATUS}
