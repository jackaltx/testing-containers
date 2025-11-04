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
CONTAINER_TYPE     # debian12-ssh, rocky93-ssh, or ubuntu24-ssh
SSH_KEY           # SSH public key (required)
CONTAINER_TOKEN   # GitHub token (for ghcr.io)
GITEA_TOKEN       # Gitea token (for Gitea registry)
TAG_LATEST        # Tag as 'latest' (default: false)
```

## Usage Examples

### Build Debian 12

```bash
export CONTAINER_TOKEN=ghp_your_token_here
export SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)
export CONTAINER_TYPE=debian12-ssh
./build.sh
```

### Build Rocky Linux 9.3

```bash
export CONTAINER_TOKEN=ghp_your_token_here
export SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)
export CONTAINER_TYPE=rocky93-ssh
./build.sh
```

### Build Ubuntu 24.10

```bash
export CONTAINER_TOKEN=ghp_your_token_here
export SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)
export CONTAINER_TYPE=ubuntu24-ssh
./build.sh
```

### Custom Registry (Gitea)

```bash
export REGISTRY_HOST=gitea.example.com:3001
export REGISTRY_USER=your_username
export GITEA_TOKEN=your_token_here
export SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)
export CONTAINER_TYPE=debian12-ssh
./build.sh
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

### Rocky Linux 9.3 (rocky93-ssh)
- Base: `rockylinux:9.3`
- Package manager: dnf
- SSH service: sshd

### Ubuntu 24.10 (ubuntu24-ssh)
- Base: `ubuntu:24.10`
- Package manager: apt
- SSH service: ssh

## Using Containers

### Pull from Registry

```bash
# GitHub Container Registry
podman pull ghcr.io/jackaltx/testing-containers:debian12-ssh

# Gitea Registry
podman pull gitea.example.com:3001/jackaltx/testing-containers:rocky93-ssh
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