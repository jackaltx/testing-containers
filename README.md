# Testing Containers

These containers are used to test my ansible project. They are packages managed
with minimal changes. I use SSH to at the transport.  The idea is to use the same transport
and system management tools to minimized the difference between real and virtual.

## Purpose

Minimal base images for testing Ansible roles with Molecule. Each container provides:

- **Python 3** - For Ansible
- **OpenSSH** - Key-based authentication
- **systemd** - For service management
- **lsof & ps** - Process utilities for debugging
- **Factory defaults** - Stock OS configuration, updated packages

## Available Images

```bash
# Pull from GitHub Container Registry
podman pull ghcr.io/jackaltx/testing-containers/debian-ssh:12
podman pull ghcr.io/jackaltx/testing-containers/debian-ssh:13
podman pull ghcr.io/jackaltx/testing-containers/rocky-ssh:9
podman pull ghcr.io/jackaltx/testing-containers/rocky-ssh:10
podman pull ghcr.io/jackaltx/testing-containers/ubuntu-ssh:24
```

| Image | Base | Package Manager |
|-------|------|-----------------|
| debian-ssh:12 | debian:12 | apt |
| debian-ssh:13 | debian:13 | apt |
| rocky-ssh:9 | rockylinux:9 | dnf |
| rocky-ssh:10 | rockylinux:10 | dnf |
| ubuntu-ssh:24 | ubuntu:24.04 | apt |

## Quick Start

Note: check that port 2222 is available before using!

### Helper Scripts

```bash
# Source registry credentials (GitHub or Gitea)
source ~/.secrets/testing-containers-registry.conf github
# or
source ~/.secrets/testing-containers-registry.conf gitea

# Run a container
./run-podman.sh -d debian -v 13

# SSH access (from another terminal)
ssh -p 2222 jackaltx@localhost

# Clean up
./cleanup-podman.sh
```

### Manual Container Execution

```bash
# Run container from GitHub
podman run -d \
    --name test_container \
    --privileged \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    -p 2222:22 \
    ghcr.io/jackaltx/testing-containers/debian-ssh:12 \
    /sbin/init

# SSH access
ssh -p 2222 jackaltx@localhost
```

## Registry Configuration

Create `~/.secrets/testing-containers-registry.conf`:

```bash
# Testing Containers Registry Configuration
# Source this file before running build.sh or run-podman.sh
#
# Usage:
#   source ~/.secrets/testing-containers-registry.conf github
#   source ~/.secrets/testing-containers-registry.conf gitea

REGISTRY_PROFILE="${1:-github}"

# Common config
export SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)
export REGISTRY_USER="your-username"
export REGISTRY_REPO="testing-containers"

# Profile-specific config
case "$REGISTRY_PROFILE" in
    github|gh)
        export REGISTRY_HOST="ghcr.io"
        export CONTAINER_TOKEN="ghp_YourGitHubTokenHere"
        echo "✓ Configured for GitHub Container Registry (ghcr.io)"
        ;;
    gitea|lab)
        export REGISTRY_HOST="gitea.example.com"
        export CONTAINER_TOKEN="YourGiteaTokenHere"
        echo "✓ Configured for Gitea Registry (gitea.example.com)"
        ;;
    *)
        echo "Error: Invalid registry profile '$REGISTRY_PROFILE'"
        echo "Usage: source ~/.secrets/testing-containers-registry.conf [github|gitea]"
        return 1
        ;;
esac

# Display current config
echo "  Registry: $REGISTRY_HOST"
echo "  User: $REGISTRY_USER"
echo "  Repo: $REGISTRY_REPO"
```

**Important:**

- Never commit this file to git
- Use GitHub Personal Access Token (PAT) with `write:packages` scope
- Use Gitea Application Token with package write permissions
- Store in `~/.secrets/` directory (outside repository)

## Building Images

### Build and Push to Registry

```bash
# Source credentials first
source ~/.secrets/testing-containers-registry.conf github

# Build specific version
./build.sh -d debian -v 12
./build.sh -d debian -v 13
./build.sh -d rocky -v 9
./build.sh -d ubuntu -v 24
```

### Build for Gitea

```bash
# Source Gitea credentials
source ~/.secrets/testing-containers-registry.conf gitea

# Build and push to Gitea
./build.sh -d debian -v 13
```

## Molecule Integration

```yaml
# molecule.yml
platforms:
  - name: instance
    image: ghcr.io/jackaltx/testing-containers/debian-ssh:12
    privileged: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    command: /sbin/init
```

## Development

### Repository Structure

```text
testing-containers/
├── debian/
│   └── Containerfile          # Unified for Debian & Ubuntu
├── rocky/
│   └── Containerfile          # Rocky-specific
├── build.sh                   # Build & push images
├── run-podman.sh              # Test containers locally
├── cleanup-podman.sh          # Remove test containers
└── README.md
```

### Adding New Versions

1. Update base image version in Containerfile ARG
2. Build with new version: `./build.sh -d debian -v 14`
3. Test locally: `./run-podman.sh -d debian -v 14`

### Design Philosophy

**Keep it minimal.** These are factory-default containers for testing:

- No configuration management tools
- No monitoring agents
- No custom configurations
- Just stock OS + SSH + Python + systemd

This ensures consistent, predictable testing environments.

## Troubleshooting

### Authentication Errors

If you see "unauthorized" errors when pulling images:

```bash
# Make sure you've sourced the registry config
source ~/.secrets/testing-containers-registry.conf github

# Or for private Gitea registry
source ~/.secrets/testing-containers-registry.conf gitea
```

### Port Already in Use

If port 2222 is already in use:

```bash
# Use custom port
LPORT=2223 ./run-podman.sh -d debian -v 13
ssh -p 2223 jackaltx@localhost
```

### Container Won't Start

Check that systemd is running:

```bash
podman exec test_container systemctl is-active sshd
```

## License

See LICENSE file.
