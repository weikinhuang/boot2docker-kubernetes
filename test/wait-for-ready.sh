#!/usr/bin/env bash

function get-node-status() {
    kubectl get nodes
}

function get-pods() {
    kubectl get pods --all-namespaces -o wide
}

sleep 15

COUNTER=0
SUCCESS_COUNTER=0
EXIT_STATUS=1
while [ $COUNTER -lt 30 ]; do
    get-node-status
    READY_NODES=$(get-node-status | grep '\<Ready\>' | wc -l)
    if [[ ${READY_NODES} == 1 ]]; then
        if [ $SUCCESS_COUNTER -ge 5 ]; then
            EXIT_STATUS=0
            break
        fi
        let SUCCESS_COUNTER=SUCCESS_COUNTER+1
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
