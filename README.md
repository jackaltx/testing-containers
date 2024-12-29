# Testing Containers

This repository provides tools for building container images suitable for testing Ansible roles. It includes support for both Debian and Rocky Linux-based containers with SSH and systemd support.

## Features

- Rootless podman container builds
- SSH access with configurable keys
- systemd support
- Ansible-ready with Python and required dependencies
- Support for both Debian and Rocky Linux base images
- Registry integration (Gitea and GitHub Container Registry support)

## Prerequisites

- Podman
- Ansible with community.docker collection
- SSH key pair for container access
- Registry access token (Gitea or GitHub)

## Installation

1. Install required packages:
```bash
# For Debian/Ubuntu
sudo apt-get install podman ansible

# For Fedora/RHEL
sudo dnf install podman ansible
```

2. Install required Ansible collection:
```bash
ansible-galaxy collection install community.docker
```

## Configuration

The script can be configured through environment variables:

```bash
REGISTRY_HOST      # Registry hostname (default: gitea.a0a0.org:3001)
REGISTRY_USER      # Registry username (default: jackaltx)
REGISTRY_REPO      # Repository name (default: testing-containers)
CONTAINER_TYPE     # Container type (debian12-ssh or rocky93-ssh)
SSH_KEY           # SSH public key (default: ~/.ssh/id_ed25519.pub)
GITEA_TOKEN       # Gitea access token
GITHUB_TOKEN      # GitHub access token (alternative to GITEA_TOKEN)
```

## Usage Examples

### Building a Debian Container

```bash
# Using Gitea registry
export GITEA_TOKEN=your_token_here
./build_container.sh CONTAINER_TYPE=debian12-ssh

# Using GitHub registry
export GITHUB_TOKEN=your_token_here
export GITHUB_REPOSITORY=your_username/your_repo
./build_container.sh CONTAINER_TYPE=debian12-ssh
```

### Building a Rocky Linux Container

```bash
export GITEA_TOKEN=your_token_here
./build_container.sh CONTAINER_TYPE=rocky93-ssh
```

### Custom SSH Key

```bash
export GITEA_TOKEN=your_token_here
export SSH_KEY=$(cat ~/.ssh/custom_key.pub)
./build_container.sh CONTAINER_TYPE=debian12-ssh
```

### Custom Registry

```bash
export GITEA_TOKEN=your_token_here
export REGISTRY_HOST=custom.registry.com
export REGISTRY_USER=your_username
export REGISTRY_REPO=your_repo
./build_container.sh CONTAINER_TYPE=debian12-ssh
```

## Container Details

### Debian Container (debian12-ssh)
- Base Image: debian:12
- Included Packages:
  - python3
  - sudo
  - systemd
  - openssh-server
  - python3-pip

### Rocky Linux Container (rocky93-ssh)
- Base Image: rockylinux:9.3
- Included Packages:
  - python3
  - sudo
  - systemd
  - openssh-server

## Testing Containers

The built containers can be tested using Ansible:

```bash
# Pull the container
podman pull gitea.a0a0.org:3001/jackaltx/testing-containers/debian12-ssh:latest

# Run the container
podman run -d \
    --name test_container \
    --privileged \
    -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
    -p 2222:22 \
    debian12-ssh \
    /sbin/init

# Test with Ansible
ansible-playbook -i inventory.yml your_playbook.yml
```

Example inventory.yml:
```yaml
all:
  hosts:
    debian_container:
      ansible_connection: community.docker.docker
      ansible_host: test_container
      ansible_user: lavender
      ansible_become: true
      ansible_python_interpreter: python3
      ansible_remote_tmp: /tmp/ansible-${USER}
      ansible_pipelining: true
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
ssh -p 2222 lavender@localhost
```

3. Registry Authentication Issues
```bash
# Verify token
podman login gitea.a0a0.org:3001

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