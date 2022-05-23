mkdir /usr/lib/ocf/resource.d/isp
cp ./ovn_watcher.sh /usr/lib/ocf/resource.d/ips/ovn_watcher
pcs resource create ovn-watcher ovn_watcher
