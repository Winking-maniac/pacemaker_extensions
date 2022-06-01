#!/usr/bin/bash

if [ -n "$1" ]; then
    if [ $1 == "--help" ] || [ $1 == "-h" ]; then
        echo "Usage: $0 [--install-only]"
        exit 0
    fi
fi

mkdir -p /usr/lib/ocf/resource.d/isp
cp ./ovn_watcher.sh /usr/lib/ocf/resource.d/isp/ovn_watcher

if [ -n "$1" ]; then
    if [ $1 == "--install-only" ]; then
        exit 0
    fi
    exit 1
fi
