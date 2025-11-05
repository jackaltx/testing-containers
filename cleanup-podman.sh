#!/bin/bash
set -e

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-test_container}"
NETWORK_NAME="${NETWORK_NAME:-monitoring-net}"

echo "Cleaning up container: $CONTAINER_NAME"
podman stop "$CONTAINER_NAME" 2>/dev/null || true
podman rm "$CONTAINER_NAME" 2>/dev/null || true

echo "Removing network: $NETWORK_NAME"
podman network rm "$NETWORK_NAME" 2>/dev/null || true

# Optional: Remove local images (uncomment if needed)
# CONTAINER_TYPE="${CONTAINER_TYPE:-debian12-ssh}"
# case "$CONTAINER_TYPE" in
#     debian12-ssh) IMAGE="ghcr.io/jackaltx/testing-containers/debian-ssh:12" ;;
#     rocky9x-ssh) IMAGE="ghcr.io/jackaltx/testing-containers/rocky-ssh:9" ;;
#     ubuntu24-ssh) IMAGE="ghcr.io/jackaltx/testing-containers/ubuntu-ssh:24" ;;
# esac
# echo "Removing image: $IMAGE"
# podman rmi "$IMAGE" 2>/dev/null || true

echo "✓ Cleanup complete"
