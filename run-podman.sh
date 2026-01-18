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

# Parse command-line flags with defaults
DISTRO=""
VERSION=""
while getopts "d:v:" opt; do
  case $opt in
    d) DISTRO=$OPTARG ;;
    v) VERSION=$OPTARG ;;
    *)
      echo "Usage: $0 -d DISTRO -v VERSION" >&2
      echo "Examples:"
      echo "  $0 -d debian -v 13"
      echo "  $0 -d rocky -v 9"
      echo "  $0 -d ubuntu -v 24"
      exit 1
      ;;
  esac
done

# Apply defaults if not provided
DISTRO="${DISTRO:-debian}"
VERSION="${VERSION:-12}"

# Configuration from environment with defaults
REGISTRY_HOST="${REGISTRY_HOST:-ghcr.io}"
REGISTRY_USER="${REGISTRY_USER:-jackaltx}"
REGISTRY_REPO="${REGISTRY_REPO:-testing-containers}"

# Image naming: distro-ssh:version
IMAGE="${IMAGE:-$REGISTRY_HOST/$REGISTRY_USER/$REGISTRY_REPO/${DISTRO}-ssh:${VERSION}}"
CONTAINER_NAME="${CONTAINER_NAME:-test_container}"
NETWORK_NAME="monitoring-net"
LPORT="${LPORT:-2222}"
SSH_PORT="$LPORT"

log "Starting ${DISTRO}-ssh:${VERSION}"
log "Using image: $IMAGE"
log "Container name: $CONTAINER_NAME"

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
    "$IMAGE" \
    /sbin/init

# Wait for container to be ready
for i in {1..30}; do
    if podman exec "$CONTAINER_NAME" systemctl is-active sshd >/dev/null 2>&1 || \
       podman exec "$CONTAINER_NAME" systemctl is-active ssh >/dev/null 2>&1; then
        log "Container is ready"
        log "SSH: ssh -p $SSH_PORT jackaltx@localhost"
        exit 0
    fi
    sleep 1
done

log "ERROR: Container failed to start properly"
podman logs "$CONTAINER_NAME"
exit 1
