#!/bin/bash
set -e

#################################################################
#
#  Goal:  Produce images for testing ansible scripts on a server distro,
#         with minimal extra stuff.
#
#  License: MIT
#  Authors:  jackaltx and claude
#

# Configuration can come from environment or defaults
REGISTRY_HOST=${REGISTRY_HOST:-"gitea.a0a0.org:3001"}
REGISTRY_USER=${REGISTRY_USER:-"jackaltx"}
REGISTRY_REPO=${REGISTRY_REPO:-"testing-containers"}
CONTAINER_TYPE=${CONTAINER_TYPE:-""} # rocky93-ssh or debian12-ssh
SSH_KEY=${SSH_KEY:-$(cat ~/.ssh/id_ed25519.pub)}
REGISTRY_URL="https://${REGISTRY_HOST}"
ORIGINAL_DIR=$(pwd)

#################################################################
# Validate required input
#
if [[ ! "$CONTAINER_TYPE" =~ ^(rocky93-ssh|debian12-ssh)$ ]]; then
    echo "CONTAINER_TYPE must be either 'rocky93-ssh' or 'debian12-ssh'"
    exit 1
fi

#################################################################
# Registry login and remove previous pkg
#
if [ -n "$GITHUB_TOKEN" ]; then
    echo "$GITHUB_TOKEN" | podman login ghcr.io -u "$GITHUB_ACTOR" --password-stdin

    echo "Attempting to delete existing package from GHCR..."
    curl -X DELETE \
         -H "Authorization: Bearer ${GITHUB_TOKEN}" \
         "https://api.github.com/user/packages/container/${REGISTRY_REPO}%2F${CONTAINER_TYPE}/versions/latest"
    sleep 5
    
elif [ -n "$GITEA_TOKEN" ]; then
    echo "$GITEA_TOKEN" | podman login --username "$REGISTRY_USER" --password-stdin "${REGISTRY_URL}"

    echo "Attempting to delete existing package from Gitea..."
    curl -X DELETE \
         -H "Authorization: token ${GITEA_TOKEN}" \
         "${REGISTRY_URL}/api/v1/packages/${REGISTRY_USER}/container/${REGISTRY_REPO}%2F${CONTAINER_TYPE}/latest"
    sleep 5
else
    echo "No authentication token provided"
    exit 1
fi

# Set image name based on registry
if [ -n "$GITHUB_TOKEN" ]; then
    REGISTRY_IMAGE="ghcr.io/${GITHUB_REPOSITORY}/${CONTAINER_TYPE}"
else
    REGISTRY_IMAGE="${REGISTRY_HOST}/${REGISTRY_USER}/${REGISTRY_REPO}/${CONTAINER_TYPE}"
fi

#################################################################
# Set up build directory
#
BUILD_DIR="${ORIGINAL_DIR}/.working/${CONTAINER_TYPE}"
mkdir -p "$BUILD_DIR"
echo "Using build directory: $BUILD_DIR"

# Ensure clean state
rm -rf "${BUILD_DIR:?}"/*
cp -r "$ORIGINAL_DIR/${CONTAINER_TYPE}"/* "$BUILD_DIR/"

# Change to build directory
cd "$BUILD_DIR"

#################################################################
# Build container
#
echo "Building container..."
podman build --build-arg SSH_KEY="$SSH_KEY" -t "$CONTAINER_TYPE" .

#################################################################
# Create and configure test container
#
echo "Testing container..."
podman run -d \
    --name test_container \
    --privileged \
    --security-opt label=disable \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    --cgroupns=host \
    -p 2222:22 \
    "$CONTAINER_TYPE" \
    /sbin/init

# Wait for container to start
sleep 5

echo "Setting up container environment..."
podman exec -u root test_container /bin/bash -c 'chown root:root /usr/bin/sudo && chmod 4755 /usr/bin/sudo'

# # Debug: Check sudo permissions inside container
# echo "Checking container setup..."
# podman exec test_container ls -l /usr/bin/sudo
# podman exec test_container id
# podman exec test_container getfacl /usr/bin/sudo

# # Ensure sudo has correct permissions inside running container
# echo "Fixing sudo permissions..."
# podman exec test_container chmod 4755 /usr/bin/sudo
# podman exec test_container chown root:root /usr/bin/sudo

sleep 5  # Wait for container to be ready

#################################################################
# Run ansible playbook
#
echo "Configuring container..."
ansible-playbook -i inventory.yml playbook.yml

#################################################################
# Create and push final image
#
echo "Creating final image..."
podman commit \
    -f docker \
    --author "Created by build script" \
    --message "${CONTAINER_TYPE} with SSH and lavender user" \
    test_container "${REGISTRY_IMAGE}:latest"

echo "Pushing to registry..."
podman push "${REGISTRY_IMAGE}:latest"

#################################################################
# Clean up
#
echo "Cleaning up..."
cd "$ORIGINAL_DIR"
podman stop test_container
podman rm test_container

# Logout from registry
if [ -n "$GITHUB_TOKEN" ]; then
    podman logout ghcr.io
else
    podman logout "${REGISTRY_URL}"
fi
