#!/usr/bin/env bash
set -euo pipefail

docker -H unix:///mnt/HOST_DOCKER.sock "$@"
