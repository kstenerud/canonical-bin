#!/bin/bash

set -eu

print_usage()
{
	echo "Usage: $(basename $0) <node name>"
}

lxc_is_network_up()
{
    container=$1
    lxc exec $container -- grep $'\t0003\t' /proc/net/route >/dev/null
}

lxc_wait_for_network()
{
    container=$1
    until lxc_is_network_up $container;
    do
        echo "Waiting for network"
        sleep 1
    done
}



if [ $# -ne 1 ]; then
	print_usage
	exit 1
fi

NODE_NAME=$1

lxc launch ubuntu-daily:cosmic $NODE_NAME
lxc_wait_for_network $NODE_NAME
lxc exec $NODE_NAME -- apt update
lxc exec $NODE_NAME -- apt dist-upgrade -y
lxc exec $NODE_NAME -- apt install -y pacemaker pcs corosync fence-agents
echo -e "hacluster\nhacluster" | lxc exec $NODE_NAME -- passwd hacluster
