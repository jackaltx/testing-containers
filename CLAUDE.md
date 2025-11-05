# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Base container images for testing Ansible roles via Molecule. Provides current, minimal, Ansible-ready platforms for Debian 12, Rocky Linux 9.3, and Ubuntu 24.04 LTS with SSH access, systemd support, and rootless Podman deployment.

## Core Commands

### Building Containers

**Command Syntax**: `./build.sh <container-type>`

Where `<container-type>` is: `debian12-ssh`, `rocky9x-ssh`, or `ubuntu24-ssh`

**Registry Selection**: Only ONE registry per build (determined by `REGISTRY_HOST`)
- `ghcr.io` (default) - requires `CONTAINER_TOKEN`
- Gitea registry - requires `GITEA_TOKEN`

```bash
# Build and push to GitHub Container Registry (ghcr.io) - DEFAULT
export CONTAINER_TOKEN=ghp_your_token_here
export SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)
./build.sh debian12-ssh    # or rocky9x-ssh, ubuntu24-ssh

# Build and push to Gitea registry
export REGISTRY_HOST=gitea.example.com:3001
export REGISTRY_USER=your_username
export GITEA_TOKEN=your_token_here
export SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)
./build.sh rocky9x-ssh

# Tag as 'latest' when building
export TAG_LATEST=true
./build.sh ubuntu24-ssh
```

**Note**: GitHub Actions CI builds all distributions automatically and pushes them to separate sub-repositories:
- `ghcr.io/jackaltx/testing-containers/debian-ssh:12`
- `ghcr.io/jackaltx/testing-containers/rocky-ssh:9`
- `ghcr.io/jackaltx/testing-containers/ubuntu-ssh:24`

This sub-repository structure allows you to delete individual distro images without affecting others.

### Running Containers

```bash
# Run with defaults (debian12-ssh on port 2222)
./run-podman.sh

# Run specific container type
export CONTAINER_TYPE=rocky9x-ssh
export IMAGE=ghcr.io/jackaltx/testing-containers/rocky-ssh:9
export LPORT=2223
./run-podman.sh

# Custom container name
export CONTAINER_NAME=my_test_container
./run-podman.sh
```

### Testing Containers

```bash
# SSH into running container
ssh -p 2222 jackaltx@localhost

# Check container status
podman ps

# View container logs
podman logs test_container

# Verify systemd is working
podman exec test_container systemctl status

# Check SSH service
podman exec test_container systemctl status sshd
```

### Cleanup

```bash
# Quick cleanup (removes test_container and monitoring-net network)
./cleanup-podman.sh

# Manual cleanup
podman stop test_container
podman rm test_container
podman network rm monitoring-net

# Remove specific image if needed
podman rmi ghcr.io/jackaltx/testing-containers/debian-ssh:12
```

## Architecture

### Container Types

Three base images are provided, each optimized for Molecule testing:

1. **debian12-ssh** - Debian 12 (Bookworm)
   - Package manager: apt
   - SSH service: ssh
   - Base image: `debian:12`

2. **rocky9x-ssh** - Rocky Linux 9.x
   - Package manager: dnf
   - SSH service: sshd
   - Base image: `rockylinux/rockylinux:9`

3. **ubuntu24-ssh** - Ubuntu 24.04 LTS
   - Package manager: apt
   - SSH service: ssh
   - Base image: `ubuntu:24.04`

### Common Features

All containers include:
- **Python 3** - Required for Ansible
- **OpenSSH Server** - Key-based authentication only (no passwords)
- **systemd** - Full init system for service management
- **sudo** - Passwordless sudo for jackaltx user
- **Utilities** - vim, wget, git, tmux
- **SSH Key** - Injected at build time via SSH_KEY build arg

### Container Architecture

- **Rootless Podman** - No root privileges required
- **Privileged Mode** - Required for systemd support
- **Cgroup Mounting** - `/sys/fs/cgroup:/sys/fs/cgroup:rw` for systemd
- **Network** - Custom `monitoring-net` network for inter-container communication
- **Port Mapping** - Host port (default 2222) → container port 22

## Directory Structure

```
testing-containers/
├── debian12-ssh/
│   └── Containerfile      # Debian 12 container definition
├── rocky9x-ssh/
│   └── Containerfile      # Rocky Linux 9.x container definition
├── ubuntu24-ssh/
│   └── Containerfile      # Ubuntu 24.04 LTS container definition
├── build.sh               # Build and push to registry
├── run-podman.sh          # Run container locally
├── cleanup-podman.sh      # Quick cleanup script
└── README.md              # User documentation
```

## Environment Variables

### Build Configuration
- `CONTAINER_TYPE` - Container to build: `debian12-ssh`, `rocky9x-ssh`, `ubuntu24-ssh`
- `SSH_KEY` - **Required** - Public SSH key to inject into container
- `REGISTRY_HOST` - Registry hostname (default: `ghcr.io`)
- `REGISTRY_USER` - Registry username (default: `jackaltx`)
- `REGISTRY_REPO` - Repository name (default: `testing-containers`)
- `TAG_LATEST` - Tag as 'latest' (default: `false`)

### Authentication
- `CONTAINER_TOKEN` - GitHub Personal Access Token (for ghcr.io)
- `GITEA_TOKEN` - Gitea access token (for Gitea registry)

### Runtime Configuration
- `IMAGE` - Container image to run (default: constructed from CONTAINER_TYPE as `ghcr.io/jackaltx/testing-containers/{distro}-ssh:{version}`)
- `CONTAINER_NAME` - Container name (default: `test_container`)
- `LPORT` - Local SSH port mapping (default: `2222`)
- `NETWORK_NAME` - Podman network name (default: `monitoring-net`)

## Usage Patterns

### Local Development Testing

```bash
# Build and test locally
export SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)
export CONTAINER_TYPE=debian12-ssh
export CONTAINER_TOKEN=ghp_xxxxx

# Build
./build.sh

# Run
./run-podman.sh

# Test SSH access
ssh -p 2222 jackaltx@localhost

# Clean up
./cleanup-podman.sh
```

### Molecule Integration

These containers are designed for Ansible Molecule testing:

```yaml
# molecule.yml
platforms:
  - name: instance
    image: ghcr.io/jackaltx/testing-containers/debian-ssh:12
    privileged: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    command: /sbin/init
    cgroupns_mode: host
    network_mode: bridge
```

### Multi-Distribution Testing

```bash
# Test across all distributions
for distro in debian12-ssh rocky9x-ssh ubuntu24-ssh; do
  export CONTAINER_TYPE=$distro
  export LPORT=$((2222 + ${distro##*[!0-9]}))
  ./run-podman.sh
done

# Verify all running
podman ps
```

## Registry Management

### GitHub Container Registry (ghcr.io)

```bash
# Login
echo $CONTAINER_TOKEN | podman login ghcr.io -u jackaltx --password-stdin

# Pull images (each distro is a separate sub-repository)
podman pull ghcr.io/jackaltx/testing-containers/debian-ssh:12
podman pull ghcr.io/jackaltx/testing-containers/rocky-ssh:9
podman pull ghcr.io/jackaltx/testing-containers/ubuntu-ssh:24

# List all tags for a specific distro
# (Use GitHub web interface or API - each distro has its own package page)
```

### Gitea Registry

```bash
# Login
echo $GITEA_TOKEN | podman login gitea.example.com:3001 -u username --password-stdin

# Pull image (same sub-repository structure)
podman pull gitea.example.com:3001/jackaltx/testing-containers/rocky-ssh:9

# Push custom tag
podman tag <image> gitea.example.com:3001/jackaltx/testing-containers/debian-ssh:custom
podman push gitea.example.com:3001/jackaltx/testing-containers/debian-ssh:custom
```

## Troubleshooting

### Build Issues

```bash
# SSH_KEY not set
export SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)

# Wrong CONTAINER_TYPE
export CONTAINER_TYPE=debian12-ssh  # Must be exact match

# Authentication failure
# GitHub: Check token has write:packages scope
# Gitea: Verify token and registry URL
```

### Runtime Issues

```bash
# Container won't start
# Check for port conflicts
netstat -tlnp | grep 2222

# systemd not working
# Ensure privileged mode and cgroup mount
podman run -d --privileged \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  --cgroupns=host <image> /sbin/init

# SSH connection refused
# Wait for container to fully start (up to 30 seconds)
# Check SSH service: podman exec test_container systemctl status sshd
```

### Permission Issues

```bash
# Podman configuration
mkdir -p ~/.config/containers
chmod 700 ~/.config/containers

# Check storage configuration
podman info

# Reset if needed
podman system reset  # WARNING: Removes all containers/images
```

## Development Workflow

### Adding a New Distribution

1. Create directory: `mkdir newdistro-ssh/`
2. Create Containerfile with standard structure
3. Update `build.sh` validation in case statement
4. Update README.md with new distribution details
5. Test build: `CONTAINER_TYPE=newdistro-ssh ./build.sh`
6. Update this CLAUDE.md

### Testing Changes

```bash
# Test build without pushing
podman build --build-arg SSH_KEY="$(cat ~/.ssh/id_ed25519.pub)" \
  -t test:local -f debian12-ssh/Containerfile debian12-ssh/

# Test run
podman run -d --name test_local --privileged \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  -p 2222:22 test:local /sbin/init

# Verify
ssh -p 2222 jackaltx@localhost
```

### CI/CD Integration

The `.github/workflows/` directory contains GitHub Actions for:
- Automated builds on push
- Multi-architecture support (if configured)
- Automatic pushing to ghcr.io

## Security Considerations

- **Key-based SSH only** - Password authentication disabled
- **Single user** - Only `jackaltx` user created
- **Passwordless sudo** - Required for Ansible testing, use only in isolated environments
- **No secrets in images** - SSH keys injected at build time, not committed
- **Privileged containers** - Required for systemd, run in isolated networks only

## Integration with SOLTI Project

These containers support the SOLTI testing framework:
- **solti-monitoring** - Tests monitoring stack roles
- **solti-containers** - Tests container service deployments
- **solti-ensemble** - Tests shared utility roles

All Molecule scenarios across SOLTI collections use these standardized base images for consistent testing environments.
