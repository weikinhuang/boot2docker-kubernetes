#!/usr/bin/env bash

function get-node-status() {
    docker-compose exec master bash -c "env KUBECONFIG=/root/assets/auth/kubeconfig kubectl get nodes"
}

function get-pods() {
    docker-compose exec master bash -c "env KUBECONFIG=/root/assets/auth/kubeconfig kubectl get pods --all-namespaces -o wide"
}

COUNTER=0
while [  $COUNTER -lt 30 ]; do
    get-node-status
    docker-compose exec master bash -c "docker ps"
    READY_NODES=$(get-node-status | grep Ready | wc -l)
    if [[ $READY_NODES == 2 ]]; then
        get-pods
        exit 0
    fi
    let COUNTER=COUNTER+1
    sleep 10
done

echo "There no nodes ready"
docker-compose exec master bash -c "docker images"
exit 1
