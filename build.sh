#!/bin/bash
set -e

# Simple build script for testing containers
# Replaces the complex build_container.sh with pure Containerfile approach

# Configuration from environment
CONTAINER_TYPE="${CONTAINER_TYPE:-debian12-ssh}"
REGISTRY_HOST="${REGISTRY_HOST:-ghcr.io}"
REGISTRY_USER="${REGISTRY_USER:-jackaltx}"
REGISTRY_REPO="${REGISTRY_REPO:-testing-containers}"
SSH_KEY="${SSH_KEY:?SSH_KEY environment variable is required}"

# Determine authentication token
if [ "$REGISTRY_HOST" = "ghcr.io" ]; then
    TOKEN="${CONTAINER_TOKEN:?CONTAINER_TOKEN required for GitHub registry}"
else
    TOKEN="${GITEA_TOKEN:?GITEA_TOKEN required for Gitea registry}"
fi

# Validate container type
case "$CONTAINER_TYPE" in
    debian12-ssh|rocky93-ssh|ubuntu24-ssh)
        echo "Building $CONTAINER_TYPE..."
        ;;
    *)
        echo "Error: CONTAINER_TYPE must be one of: debian12-ssh, rocky93-ssh, ubuntu24-ssh"
        exit 1
        ;;
esac

# Login to registry
echo "$TOKEN" | podman login "$REGISTRY_HOST" -u "$REGISTRY_USER" --password-stdin

# Build image
IMAGE_TAG="$REGISTRY_HOST/$REGISTRY_USER/$REGISTRY_REPO:$CONTAINER_TYPE"

podman build \
    --build-arg SSH_KEY="$SSH_KEY" \
    -t "$IMAGE_TAG" \
    -f "$CONTAINER_TYPE/Containerfile" \
    "$CONTAINER_TYPE/"

# Push to registry
podman push "$IMAGE_TAG"

# Tag as latest if requested
if [ "${TAG_LATEST:-false}" = "true" ]; then
    podman tag "$IMAGE_TAG" "$REGISTRY_HOST/$REGISTRY_USER/$REGISTRY_REPO:latest"
    podman push "$REGISTRY_HOST/$REGISTRY_USER/$REGISTRY_REPO:latest"
fi

# Logout
podman logout "$REGISTRY_HOST"

echo "✓ Successfully built and pushed $IMAGE_TAG"
