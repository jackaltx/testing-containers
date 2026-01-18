#!/bin/bash
set -e

# Unified build script for testing containers
# Usage: ./build.sh -d DISTRO -v VERSION
# Examples:
#   ./build.sh -d debian -v 12
#   ./build.sh -d rocky -v 9
#   ./build.sh -d ubuntu -v 24

# Parse command-line flags
DISTRO=""
VERSION=""
while getopts "d:v:" opt; do
  case $opt in
    d) DISTRO=$OPTARG ;;
    v) VERSION=$OPTARG ;;
    *)
      echo "Usage: $0 -d DISTRO -v VERSION" >&2
      echo "Examples:"
      echo "  $0 -d debian -v 12"
      echo "  $0 -d debian -v 13"
      echo "  $0 -d rocky -v 9"
      echo "  $0 -d rocky -v 10"
      echo "  $0 -d ubuntu -v 24"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [ -z "$DISTRO" ] || [ -z "$VERSION" ]; then
  echo "Error: -d DISTRO and -v VERSION are required"
  echo "Usage: $0 -d DISTRO -v VERSION"
  exit 1
fi

# Validate environment variables (should be set by sourcing registry config)
REGISTRY_HOST="${REGISTRY_HOST:?REGISTRY_HOST not set. Source ~/.secrets/testing-containers-registry.conf first}"
REGISTRY_USER="${REGISTRY_USER:?REGISTRY_USER not set}"
REGISTRY_REPO="${REGISTRY_REPO:?REGISTRY_REPO not set}"
SSH_KEY="${SSH_KEY:?SSH_KEY not set}"
CONTAINER_TOKEN="${CONTAINER_TOKEN:?CONTAINER_TOKEN not set}"

# Map distro to base image and Containerfile location
case "$DISTRO" in
  debian)
    DISTRO_BASE="debian"
    DISTRO_VERSION="$VERSION"
    CONTAINERFILE_DIR="debian"
    ;;
  ubuntu)
    DISTRO_BASE="ubuntu"
    # Map version 24 → 24.04
    case "$VERSION" in
      24) DISTRO_VERSION="24.04" ;;
      *) DISTRO_VERSION="$VERSION" ;;
    esac
    CONTAINERFILE_DIR="debian"  # Ubuntu uses same Containerfile as Debian
    ;;
  rocky)
    DISTRO_BASE="rockylinux/rockylinux"
    DISTRO_VERSION="$VERSION"
    CONTAINERFILE_DIR="rocky"
    ;;
  *)
    echo "Error: DISTRO must be one of: debian, ubuntu, rocky"
    exit 1
    ;;
esac

# Image naming: distro-ssh:version (e.g., rocky-ssh:9, not rocky9-ssh)
IMAGE_TAG="$REGISTRY_HOST/$REGISTRY_USER/$REGISTRY_REPO/${DISTRO}-ssh:${VERSION}"

echo "Building ${DISTRO}-ssh:${VERSION}..."
echo "  Base image: ${DISTRO_BASE}:${DISTRO_VERSION}"
echo "  Registry: $REGISTRY_HOST"
echo "  Image tag: $IMAGE_TAG"

# Login to registry
echo "$CONTAINER_TOKEN" | podman login "$REGISTRY_HOST" -u "$REGISTRY_USER" --password-stdin

# Build image with appropriate build args
if [ "$CONTAINERFILE_DIR" = "debian" ]; then
  # Debian/Ubuntu: pass both DISTRO_BASE and DISTRO_VERSION
  podman build \
    --build-arg SSH_KEY="$SSH_KEY" \
    --build-arg DISTRO_BASE="$DISTRO_BASE" \
    --build-arg DISTRO_VERSION="$DISTRO_VERSION" \
    -t "$IMAGE_TAG" \
    -f "$CONTAINERFILE_DIR/Containerfile" \
    "$CONTAINERFILE_DIR/"
else
  # Rocky: only pass DISTRO_VERSION
  podman build \
    --build-arg SSH_KEY="$SSH_KEY" \
    --build-arg DISTRO_VERSION="$DISTRO_VERSION" \
    -t "$IMAGE_TAG" \
    -f "$CONTAINERFILE_DIR/Containerfile" \
    "$CONTAINERFILE_DIR/"
fi

# Push to registry
podman push "$IMAGE_TAG"

# Tag as latest if requested
if [ "${TAG_LATEST:-false}" = "true" ]; then
    LATEST_TAG="$REGISTRY_HOST/$REGISTRY_USER/$REGISTRY_REPO/${DISTRO}-ssh:latest"
    podman tag "$IMAGE_TAG" "$LATEST_TAG"
    podman push "$LATEST_TAG"
    echo "✓ Also tagged as: $LATEST_TAG"
fi

# Logout
podman logout "$REGISTRY_HOST"

echo "✓ Successfully built and pushed $IMAGE_TAG"
