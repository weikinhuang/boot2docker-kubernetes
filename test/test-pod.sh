#!/usr/bin/env bash

set -x

function create-test-pod() {
    kubectl apply -f ./data/test/echoserver.yaml
}

function get-pods() {
    kubectl get pods -o wide
}

function is-pod-ready() {
    kubectl get pods -l app=echoheaders | grep '1/1' | grep -q '\<Running\>'
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

docker-compose exec master bash -c "curl --fail -SL --connect-timeout 10 --max-time 15 -v -i http://127.0.0.1:30001"
curl --fail -SL --connect-timeout 10 --max-time 15 -v -i http://127.0.0.1:40001
