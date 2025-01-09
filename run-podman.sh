#!/bin/bash
set -e

# Function for logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to clean up on exit
cleanup() {
    if [ -n "$CONTAINER_NAME" ]; then
        log "Cleaning up container $CONTAINER_NAME..."
        podman stop "$CONTAINER_NAME" 2>/dev/null || true
        podman rm "$CONTAINER_NAME" 2>/dev/null || true
    fi
}

# Set up error handling
trap cleanup ERR

# Configuration
CONTAINER_NAME="test_container"
CONTAINER_NAME="$CONTAINER_TYPE"
NETWORK_NAME="monitoring-net"
LPORT="${LPORT:-2222}"
SSH_PORT="$LPORT"

# Validate container type is set
if [ -z "$CONTAINER_TYPE" ]; then
    log "ERROR: CONTAINER_TYPE must be set"
    exit 1
fi

# Create network if it doesn't exist
if ! podman network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    log "Creating network $NETWORK_NAME..."
    podman network create "$NETWORK_NAME"
else
    log "Network $NETWORK_NAME already exists"
fi

# Remove existing container if it exists
if podman container exists "$CONTAINER_NAME" 2>/dev/null; then
    log "Removing existing container $CONTAINER_NAME..."
    podman stop "$CONTAINER_NAME" 2>/dev/null || true
    sleep 2
    podman rm "$CONTAINER_NAME" 2>/dev/null || true
    sleep 2
fi

# Start container
log "Starting container $CONTAINER_NAME..."
podman run -d \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK_NAME" \
    --privileged \
    --security-opt label=disable \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    --cgroupns=host \
    -p "${SSH_PORT}:22" \
    "$CONTAINER_TYPE" \
    /sbin/init

# Wait for container to be ready
for i in {1..30}; do
    if podman exec "$CONTAINER_NAME" systemctl is-active sshd >/dev/null 2>&1; then
        log "Container is ready"
        exit 0
    fi
    sleep 1
done

log "ERROR: Container failed to start properly"
podman logs "$CONTAINER_NAME"
exit 1