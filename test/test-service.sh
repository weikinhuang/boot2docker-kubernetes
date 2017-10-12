#!/usr/bin/env bash

set -x

function create-test-pods() {
    docker-compose exec master bash -c "env KUBECONFIG=/root/assets/auth/kubeconfig kubectl apply -f /data/test/echoserver.yaml"
    docker-compose exec master bash -c "env KUBECONFIG=/root/assets/auth/kubeconfig kubectl apply -f /data/test/haproxy.yaml"
}

function get-pods() {
    docker-compose exec master bash -c "env KUBECONFIG=/root/assets/auth/kubeconfig kubectl get pods -o wide"
}

function is-echoheaders-ready() {
    docker-compose exec master bash -c "env KUBECONFIG=/root/assets/auth/kubeconfig kubectl get pods -l app=echoheaders" | grep '1/1' | grep -q '\<Running\>'
}
function is-haproxy-ready() {
    docker-compose exec master bash -c "env KUBECONFIG=/root/assets/auth/kubeconfig kubectl get pods -l app=haproxy" | grep '2/2' | grep -q '\<Running\>'
}

function is-pod-ready() {
    is-echoheaders-ready && is-haproxy-ready
}

create-test-pods

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

# test using non fqdn
docker-compose exec master bash -c "curl --fail -SL --connect-timeout 10 --max-time 15 -v -i http://127.0.0.1:30002"
# test using fqdn
docker-compose exec master bash -c "curl --fail -SL --connect-timeout 10 --max-time 15 -v -i http://127.0.0.1:30003"
# test hostport
#docker-compose exec master bash -c "curl --fail -SL --connect-timeout 10 --max-time 15 -v -i http://127.0.0.1:30012"
