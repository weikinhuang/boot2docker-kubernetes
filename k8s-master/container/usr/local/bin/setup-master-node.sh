#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

set -x

systemctl enable bootkube.service
