# Testing Containers

Base container images for testing Ansible roles via Molecule. Provides current, minimal, Ansible-ready platforms for Debian, Rocky Linux, and Ubuntu.

## Features

- Rootless podman container builds
- SSH access with configurable keys
- systemd support
- Ansible-ready with Python and required dependencies
- Current packages (updated at build time)
- Stock configuration with minimal modifications
- Registry integration (Gitea and GitHub Container Registry)

## Prerequisites

- Podman
- SSH key pair for container access
- Registry access token (Gitea or GitHub)

## Installation

```bash
# For Debian/Ubuntu
sudo apt-get install podman

# For Fedora/RHEL
sudo dnf install podman
```

## Configuration

Environment variables:

```bash
REGISTRY_HOST      # Registry hostname (default: ghcr.io)
REGISTRY_USER      # Registry username (default: jackaltx)
REGISTRY_REPO      # Repository name (default: testing-containers)
CONTAINER_TYPE     # debian12-ssh, rocky9x-ssh, or ubuntu24-ssh
SSH_KEY           # SSH public key (required)
CONTAINER_TOKEN   # GitHub token (for ghcr.io)
GITEA_TOKEN       # Gitea token (for Gitea registry)
TAG_LATEST        # Tag as 'latest' (default: false)
```

## Usage Examples

The `build.sh` script accepts the container type as a command-line argument:
```bash
./build.sh <container-type>
```

Where `<container-type>` is one of: `debian12-ssh`, `rocky9x-ssh`, `ubuntu24-ssh`

**Important**: Only ONE registry is used per build, determined by `REGISTRY_HOST`:
- `ghcr.io` (default) - requires `CONTAINER_TOKEN` (GitHub Personal Access Token)
- Custom Gitea - requires `GITEA_TOKEN`

### Build for GitHub Container Registry (ghcr.io)

```bash
# Required: GitHub Personal Access Token with write:packages scope
export CONTAINER_TOKEN=ghp_your_token_here
export SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)

# Build Debian 12 (automatically built by GitHub Actions)
./build.sh debian12-ssh

# Build Rocky Linux 9.x (manual build only)
./build.sh rocky9x-ssh

# Build Ubuntu 24.04 LTS (manual build only)
./build.sh ubuntu24-ssh
```

**Note**: GitHub Actions CI only builds `debian12-ssh` automatically. Other distributions must be built manually to reduce CI time.

### Build for Gitea Registry

```bash
# Required: Gitea access token
export REGISTRY_HOST=gitea.example.com:3001
export REGISTRY_USER=your_username
export GITEA_TOKEN=your_gitea_token
export SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)

# Build any distribution
./build.sh debian12-ssh
./build.sh rocky9x-ssh
./build.sh ubuntu24-ssh
```

## Container Details

All containers include:
- Python 3 (for Ansible)
- OpenSSH server (key-based auth)
- systemd (for service management)
- sudo (passwordless for jackaltx user)
- vim, wget, git, tmux (utilities)

### Debian 12 (debian12-ssh)
- Base: `debian:12`
- Package manager: apt
- SSH service: ssh

### Rocky Linux 9.x (rocky9x-ssh)
- Base: `rockylinux/rockylinux:9`
- Package manager: dnf
- SSH service: sshd

### Ubuntu 24.04 LTS (ubuntu24-ssh)
- Base: `ubuntu:24.04`
- Package manager: apt
- SSH service: ssh

## Using Containers

### Pull from Registry

```bash
# GitHub Container Registry
podman pull ghcr.io/jackaltx/testing-containers:debian12-ssh

# Gitea Registry
podman pull gitea.example.com:3001/jackaltx/testing-containers:rocky9x-ssh
```

### Run Container

```bash
podman run -d \
    --name test_container \
    --privileged \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    -p 2222:22 \
    ghcr.io/jackaltx/testing-containers:debian12-ssh \
    /sbin/init
```

### SSH Access

```bash
ssh -p 2222 jackaltx@localhost
```

### Molecule Testing

These containers are designed for use with Molecule:

```yaml
# molecule.yml
platforms:
  - name: instance
    image: ghcr.io/jackaltx/testing-containers:debian12-ssh
    privileged: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    command: /sbin/init
```

## Troubleshooting

### Common Issues

1. Podman Permission Issues
```bash
# Set up proper podman configuration
mkdir -p ~/.config/containers/registries.conf.d
chmod 700 ~/.config/containers
```

2. Ansible Connection Issues
```bash
# Verify container is running
podman ps

# Check container logs
podman logs test_container

# Verify SSH access
ssh -p 2222 jackaltx@localhost
```

3. Registry Authentication Issues
```bash
# Verify token
podman login gitea.example.com:3001

# Check auth file
cat ~/.config/containers/auth.json
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

MIT

## Authors

- jackaltx
- claude