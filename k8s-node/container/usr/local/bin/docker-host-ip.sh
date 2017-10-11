#!/usr/bin/env bash
set -euo pipefail

docker-host.sh run --rm --net=host alpine:latest ip addr | grep '\<eth0\>' | grep inet | awk '{print $2}' | cut -d '/' -f1
