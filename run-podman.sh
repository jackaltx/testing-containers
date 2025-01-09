#!/bin/sh

# Create a new network (claude: if it does not exist)
#podman network create monitoring-net

# Run container with this network
podman run -d \
    --name test_container \
    --network monitoring-net \
    --privileged \
    --security-opt label=disable \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    --cgroupns=host \
    -p 2222:22 \
    "$CONTAINER_TYPE" \
    /sbin/init

