#!/usr/bin/env bash

sh -c 'journalctl -f | { sed "/===== Bootkube deployed successfully =====/ q" && kill $$ ;}'
EXIT_CODE=$?
if [[ $EXIT_CODE == 0 ]] || [[ $EXIT_CODE == 143 ]]; then
    EXIT_CODE=0
fi
exit ${EXIT_CODE:-1}
