#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if [[ ! -d /data/images ]]; then
    exit 0
fi

if [[ -e /.images-imported ]]; then
    exit 0
fi

touch /.images-imported

# reimport any saved images to save on bandwidth
# docker images | tr -s ' ' | cut -f1-2 -d ' ' | tail -n +2 | tr ' ' ':' | xargs -I{} sh -c 'docker save -o "$(echo "{}" | tr ':' '@' | tr '/' '=').tar" "{}"'

if [[ -d /data/images/all ]]; then
    find /data/images/all -iname '*.tar' | xargs -r -I{} sh -c 'docker load -i "{}"'
fi
if [[ -n ${K8S_MASTER_NODE:-} ]]; then
    if [[ -d /data/images/master ]]; then
        find /data/images/master -iname '*.tar' | xargs -r -I{} sh -c 'docker load -i "{}"'
    fi
else
    if [[ -d /data/images/worker ]]; then
        find /data/images/worker -iname '*.tar' | xargs -r -I{} sh -c 'docker load -i "{}"'
    fi
fi
