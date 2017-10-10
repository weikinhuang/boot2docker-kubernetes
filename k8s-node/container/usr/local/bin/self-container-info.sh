#!/usr/bin/env bash
set -euo pipefail

docker-host.sh inspect "$(cat /proc/self/cgroup | grep "docker" | sed s/\\//\\n/g | tail -1)" "$@"
