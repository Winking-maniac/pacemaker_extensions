#!/usr/bin/bash

if [ -n "$1" ]; then
    if [ $1 -eq "--help" ] || [ $1 -eq "-h" ]; then
        echo "Usage: $0 [--install-only]"
        exit 0
    fi
fi

mkdir -p /usr/lib/ocf/resource.d/isp
cp ./ovn_watcher.sh /usr/lib/ocf/resource.d/isp/ovn_watcher

if [ -n "$1" ]; then
    if [ $1 -eq "--install-only" ]; then
        exit 0
    fi
    exit 1
fi

pcs resource create ovn-watcher ocf:isp:ovn_watcher pmem_threshold=20 stable_periods=5 failing_periods=3 op monitor interval=3600s on-fail=block --disabled
pcs constraint colocation add ovn-dbs-bundle with Master ovn-watcher INFINITY
pcs resource enable ovn-watcher
