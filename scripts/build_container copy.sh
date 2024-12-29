#!/bin/bash
set -e

#################################################################
#
#  Goal:  Produce images for testing my ansible scripts on a server distro,
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
# For podman operations, explicitly run as the real user
#
REAL_USER=$(who am i | awk '{print $1}')

podman_run() {
    if [ "$(id -u)" -eq 0 ]; then
        # Run podman with user's configuration
        CONTAINERS_CONF="/home/$REAL_USER/.config/containers/containers.conf" \
        CONTAINERS_REGISTRIES_CONF="/home/$REAL_USER/.config/containers/registries.conf" \
        # Set XDG directories to use real user's home
        XDG_RUNTIME_DIR="/run/user/$(id -u $REAL_USER)" \
        XDG_CONFIG_HOME="/home/$REAL_USER/.config" \
        XDG_DATA_HOME="/home/$REAL_USER/.local/share" \
        REGISTRY_AUTH_FILE="/home/$REAL_USER/.config/containers/auth.json" \
        su -p -c "$*" $REAL_USER
    else
        $*
    fi
}


# And at the start of the script, ensure these directories and files exist:
if [ "$(id -u)" -eq 0 ]; then
    # Create necessary directories
    mkdir -p "/home/$REAL_USER/.config/containers"
    mkdir -p "/home/$REAL_USER/.local/share/containers"
    
    # Create default registries.conf if it doesn't exist
    if [ ! -f "/home/$REAL_USER/.config/containers/registries.conf" ]; then
        cp /etc/containers/registries.conf "/home/$REAL_USER/.config/containers/registries.conf"
    fi
    
    # Set ownership
    chown -R $REAL_USER:$REAL_USER "/home/$REAL_USER/.config/containers"
    chown -R $REAL_USER:$REAL_USER "/home/$REAL_USER/.local/share/containers"
fi


#################################################################
# Validate required input
#
if [[ ! "$CONTAINER_TYPE" =~ ^(rocky93-ssh|debian12-ssh)$ ]]; then
    echo "CONTAINER_TYPE must be either 'rocky93-ssh' or 'debian12-ssh'"
    exit 1
fi

#################################################################
# Registry login and remove previous pkg - support both Gitea token and GitHub token
#
if [ -n "$GITHUB_TOKEN" ]; then
    echo "$GITHUB_TOKEN" | podman login ghcr.io -u "$GITHUB_ACTOR" --password-stdin
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
#  Create build directory in temporary file system.  may need revisiting
#  I would rather create a sub-dir and keep it after the run (use .gitignore)
#
#  Claude ->  address this comment
#
BUILD_DIR="${ORIGINAL_DIR}/.working/${CONTAINER_TYPE}"
mkdir -p "$BUILD_DIR"
echo "Using build directory: $BUILD_DIR"

# Ensure clean state
rm -rf "${BUILD_DIR:?}"/*
cp -r "$ORIGINAL_DIR/${CONTAINER_TYPE}"/* "$BUILD_DIR/"
chown -R $REAL_USER:$REAL_USER "$BUILD_DIR"

# All the work is done in this location
cd "$BUILD_DIR"

#################################################################
# Build container
#   NOTE: uses hard-coded name test_container.  It will push based on name. 
#   TODO: Jack, evaluate end product for re-use.
#
echo "Building container..."
podman_run "podman build --build-arg SSH_KEY=\"$SSH_KEY\" -t \"$CONTAINER_TYPE\" ."

#################################################################
# Create and configure test container
#
echo "Testing container..."
podman run -d \
    --name test_container \
    --systemd=always \
    -p 2222:22 \
    "$CONTAINER_TYPE" \
    /sbin/init

sleep 5  # Wait for container to be ready

#################################################################
#################################################################
#
# Run ansible playbook
# NOTE: This needs to be become root for the provisioning phase
#
echo "Configuring container..."
ansible-playbook -i inventory.yml playbook.yml

# Create final image
echo "Creating final image..."
podman commit \
    -f docker \
    --author "Created by build script" \
    --message "${CONTAINER_TYPE} with SSH and lavender user" \
    test_container "${REGISTRY_IMAGE}:latest"

#################################################################
#################################################################
#  Add container into a registry
#
echo "Pushing to registry..."
podman push "${REGISTRY_IMAGE}:latest"

# Clean up
echo "Cleaning up..."
cd "$ORIGINAL_DIR"
podman stop test_container
podman rm test_container

#################################################################
# Logout from registry

if [ -n "$GITHUB_TOKEN" ]; then
    podman logout ghcr.io
else
    podman logout "${REGISTRY_URL}"
fi