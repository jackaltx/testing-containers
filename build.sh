#!/bin/bash
set -e

# Simple build script for testing containers
# Replaces the complex build_container.sh with pure Containerfile approach

# Configuration from environment
CONTAINER_TYPE="${1:-${CONTAINER_TYPE:-debian12-ssh}}"
REGISTRY_HOST="${REGISTRY_HOST:-ghcr.io}"
REGISTRY_USER="${REGISTRY_USER:-jackaltx}"
REGISTRY_REPO="${REGISTRY_REPO:-testing-containers}"
SSH_KEY="${SSH_KEY:?SSH_KEY environment variable is required}"

# Parse CONTAINER_TYPE into DISTRO and VERSION
case "$CONTAINER_TYPE" in
    debian12-ssh)
        DISTRO="debian"
        VERSION="12"
        ;;
    rocky9x-ssh)
        DISTRO="rocky"
        VERSION="9"
        ;;
    ubuntu24-ssh)
        DISTRO="ubuntu"
        VERSION="24"
        ;;
    *)
        echo "Error: CONTAINER_TYPE must be one of: debian12-ssh, rocky9x-ssh, ubuntu24-ssh"
        exit 1
        ;;
esac

# Determine authentication token
if [ "$REGISTRY_HOST" = "ghcr.io" ]; then
    TOKEN="${CONTAINER_TOKEN:?CONTAINER_TOKEN required for GitHub registry}"
else
    TOKEN="${GITEA_TOKEN:?GITEA_TOKEN required for Gitea registry}"
fi

echo "Building ${DISTRO}-ssh:${VERSION} from $CONTAINER_TYPE..."

# Login to registry
echo "$TOKEN" | podman login "$REGISTRY_HOST" -u "$REGISTRY_USER" --password-stdin

# Build image with new sub-repository naming pattern
IMAGE_TAG="$REGISTRY_HOST/$REGISTRY_USER/$REGISTRY_REPO/${DISTRO}-ssh:${VERSION}"

podman build \
    --build-arg SSH_KEY="$SSH_KEY" \
    -t "$IMAGE_TAG" \
    -f "$CONTAINER_TYPE/Containerfile" \
    "$CONTAINER_TYPE/"

# Push to registry
podman push "$IMAGE_TAG"

# Tag as latest if requested
if [ "${TAG_LATEST:-false}" = "true" ]; then
    LATEST_TAG="$REGISTRY_HOST/$REGISTRY_USER/$REGISTRY_REPO/${DISTRO}-ssh:latest"
    podman tag "$IMAGE_TAG" "$LATEST_TAG"
    podman push "$LATEST_TAG"
fi

# Logout
podman logout "$REGISTRY_HOST"

echo "✓ Successfully built and pushed $IMAGE_TAG"
