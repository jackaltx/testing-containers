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


# Add error trapping and cleanup
cleanup() {
    echo "Performing cleanup..."
    podman stop test_container 2>/dev/null || true
    podman rm test_container 2>/dev/null || true
    cd "$ORIGINAL_DIR"
}
trap cleanup EXIT

# Add structured logging
log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*"
}

# Configuration can come from environment or defaults
REGISTRY_HOST=${REGISTRY_HOST:-"gitea.a0a0.org:3001"}
REGISTRY_USER=${REGISTRY_USER:-"jackaltx"}
REGISTRY_REPO=${REGISTRY_REPO:-"testing-containers"}
CONTAINER_TYPE=${CONTAINER_TYPE:-""} # rocky93-ssh or debian12-ssh
REGISTRY_URL="https://${REGISTRY_HOST}"
ORIGINAL_DIR=$(pwd)

#################################################################
# Validate required input
#
validate_environment() {
    if [ -z "$SSH_KEY" ]; then
        log ERROR "SSH_KEY must be provided"
        exit 1
    fi

    if [[ ! "$CONTAINER_TYPE" =~ ^(rocky93-ssh|debian12-ssh)$ ]]; then
        log ERROR "CONTAINER_TYPE must be either 'rocky93-ssh' or 'debian12-ssh'"
        log ERROR "Container type was ${CONTAINER_TYPE}"
        exit 1
    fi
}
validate_environment

#################################################################
# Registry login
#
login_registry() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if [ -n "$CONTAINER_TOKEN" ]; then
            if echo "$CONTAINER_TOKEN" | podman login ghcr.io -u "$REGISTRY_USER" --password-stdin; then
                return 0
            fi
        elif [ -n "$GITEA_TOKEN" ]; then
            if echo "$GITEA_TOKEN" | podman login --username "$REGISTRY_USER" --password-stdin "${REGISTRY_URL}"; then
                return 0
            fi
        else
            log ERROR "No authentication token provided"
            exit 1
        fi
        log WARN "Login attempt $attempt failed, retrying..."
        attempt=$((attempt + 1))
        sleep 2
    done
    
    log ERROR "Failed to login after $max_attempts attempts"
    exit 1
}

# Perform registry login
log INFO "Logging into registry..."
login_registry


#################################################################
# Remove previous version (claude: this needs to be later after it complets)
#

if [ -n "$CONTAINER_TOKEN" ]; then
    log INFO "Attempting to delete existing package from Github..."
    curl -X DELETE \
        -H "Authorization: Bearer ${CONTAINER_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/user/packages/container/${REGISTRY_REPO}%2F${CONTAINER_TYPE}/versions/latest"
    sleep 5

else    # elif [ -n "$GITEA_TOKEN" ]; then
    log INFO "Attempting to delete existing package from Gitea..."
    curl -X DELETE \
         -H "Authorization: token ${GITEA_TOKEN}" \
         "${REGISTRY_URL}/api/v1/packages/${REGISTRY_USER}/container/${REGISTRY_REPO}%2F${CONTAINER_TYPE}/latest"
    sleep 5
fi


# Set image name based on registry
if [ -n "$GITHUB_ACTIONS" ]; then
    REGISTRY_IMAGE="ghcr.io/${GITHUB_REPOSITORY}/${CONTAINER_TYPE}"
else
    REGISTRY_IMAGE="${REGISTRY_HOST}/${REGISTRY_USER}/${REGISTRY_REPO}/${CONTAINER_TYPE}"
fi

#################################################################
# Set up build directory
#
BUILD_DIR="${ORIGINAL_DIR}/.working/${CONTAINER_TYPE}"
mkdir -p "$BUILD_DIR"
log INFO "Using build directory: $BUILD_DIR"

# Ensure clean state
rm -rf "${BUILD_DIR:?}"/*
cp -r "$ORIGINAL_DIR/${CONTAINER_TYPE}"/* "$BUILD_DIR/"

# Change to build directory
cd "$BUILD_DIR"

#################################################################
# Build container
#
log INFO "Building container..."
if ! podman build --build-arg SSH_KEY="$SSH_KEY" -t "$CONTAINER_TYPE" .; then
    log ERROR "Container build failed"
    exit 1
fi

#################################################################
# Create and configure test container
#
log INFO "Starting test container..."
podman run -d \
    --name test_container \
    --privileged \
    --security-opt label=disable \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    --cgroupns=host \
    -p 2222:22 \
    "$CONTAINER_TYPE" \
    /sbin/init

#################################################################
# Wait for container to start
#
log INFO "Waiting for container to be healthy..."
for i in {1..30}; do
    if podman exec test_container systemctl is-system-running; then
        break
    fi
    sleep 1
    if [ $i -eq 30 ]; then
        log ERROR "Container failed to become healthy"
        exit 1
    fi
done

#################################################################
# Wait for container to be ready
#
log INFO "Setting up container environment..."
podman exec -u root test_container /bin/bash -c 'chown root:root /usr/bin/sudo && chmod 4755 /usr/bin/sudo'

sleep 5  # Wait for container to be ready


#################################################################
# Add Podman socket setup
#

log INFO "Setting up Podman socket..."
systemctl --user enable podman.socket || true
systemctl --user start podman.socket || true
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock


#################################################################
# Debug info (Claude adde debug level cutoff with defailt at INFO)
#

log DEBUG "Container status:"
podman ps -a

log DEBUG "Container logs:"
podman logs test_container

log DEBUG "Ansible inventory:"
cat inventory.yml

#################################################################
#  Run ansible playbook
#
log INFO "Configuring container..."
if [ -n "$GITHUB_ACTIONS" ]; then
    # ansible-galaxy collection install community.docker
    ansible-playbook -i inventory.yml playbook.yml
#    ansible-playbook -i inventory.yml \
#                     -e "ansible_connection=docker" \
#                     playbook.yml
else
    ansible-playbook -i inventory.yml playbook.yml
fi

#################################################################
# Create and push final image
#
log INFO "Creating final image..."
podman commit \
    -f docker \
    --author "Created by build script" \
    --message "${CONTAINER_TYPE} with SSH and jackaltx user" \
    test_container "${REGISTRY_IMAGE}:latest"

log INFO "Pushing to registry..."
podman push "${REGISTRY_IMAGE}:latest"

#################################################################
# Clean up
#
log INFO "Cleaning up..."
cd "$ORIGINAL_DIR"
podman stop test_container
podman rm test_container

#################################################################
# Logout from registry
#
log INFO "Logout from registry"
if [ -n "$GITHUB_ACTIONS" ]; then
    podman logout ghcr.io
else
    podman logout "${REGISTRY_URL}"
fi