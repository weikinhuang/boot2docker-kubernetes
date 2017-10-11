#!/usr/bin/env bash

function create-test-pod() {
    docker-compose exec master bash -c "env KUBECONFIG=/root/assets/auth/kubeconfig kubectl apply -f /data/test/echoserver.yaml"
}

function get-pods() {
    docker-compose exec master bash -c "env KUBECONFIG=/root/assets/auth/kubeconfig kubectl get pods -o wide"
}

function is-pod-ready() {
    docker-compose exec master bash -c "env KUBECONFIG=/root/assets/auth/kubeconfig kubectl get pods -l app=echoheaders" | grep -q '\<Running\>'
}

create-test-pod

COUNTER=0
EXIT_STATUS=1
while [  $COUNTER -lt 30 ]; do
    get-pods
    if is-pod-ready; then
        EXIT_STATUS=0
        break
    fi
    let COUNTER=COUNTER+1
    sleep 10
done

if [[ ${EXIT_STATUS} == 1 ]]; then
    get-pods
    echo "There no pods ready!"
    exit 1
fi

curl --fail -SL --connect-timeout 10 --max-time 15 -v -i http://docker:30001
