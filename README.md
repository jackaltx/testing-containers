# Testing Containers

Factory-default container images for Ansible testing. Just SSH and Python - nothing else.

## Purpose

Minimal base images for testing Ansible roles with Molecule. Each container provides:
- **Python 3** - For Ansible
- **OpenSSH** - Key-based authentication
- **systemd** - For service management
- **Factory defaults** - Stock OS configuration, updated packages

## Available Images

```bash
# Pull from GitHub Container Registry
podman pull ghcr.io/jackaltx/testing-containers/debian-ssh:12
podman pull ghcr.io/jackaltx/testing-containers/rocky-ssh:9
podman pull ghcr.io/jackaltx/testing-containers/ubuntu-ssh:24
```

| Image | Base | Package Manager |
|-------|------|-----------------|
| debian-ssh:12 | debian:12 | apt |
| rocky-ssh:9 | rockylinux:9 | dnf |
| ubuntu-ssh:24 | ubuntu:24.04 | apt |

## Quick Start

```bash
# Run container
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

## Building Images

See [build.sh](build.sh) for building and pushing to registries.

```bash
export SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)
export CONTAINER_TOKEN=ghp_your_token_here
./build.sh debian12-ssh
```