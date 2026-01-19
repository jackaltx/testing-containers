# CLAUDE.md

AI context for working with testing containers.

## Core Purpose

**Factory-default containers for Ansible testing. SSH + Python. Nothing more.**

These are deliberately minimal - don't suggest adding features. User wants stock OS configurations for reliable Ansible role testing.

## Quick Commands

```bash
# Setup registry credentials (required first step)
source ~/.secrets/testing-containers-registry.conf github   # For GitHub
source ~/.secrets/testing-containers-registry.conf gitea    # For Gitea lab

# Build containers
./build.sh -d debian -v 12
./build.sh -d debian -v 13
./build.sh -d rocky -v 9
./build.sh -d rocky -v 10
./build.sh -d ubuntu -v 24

# Test locally
./run-podman.sh -d debian -v 13
ssh -p 2222 jackaltx@localhost
./cleanup-podman.sh
```

## What's Included

Supported distributions:
- **debian**: Debian 12, 13 (apt, OpenSSH)
- **rocky**: Rocky Linux 9, 10 (dnf, OpenSSH)
- **ubuntu**: Ubuntu 24.04 LTS (apt, OpenSSH)

Each has:
- Python 3 (Ansible requirement)
- OpenSSH server (key-based only)
- systemd (for service testing)
- sudo (passwordless for jackaltx user)

## Build System

```bash
# Syntax
./build.sh -d DISTRO -v VERSION

# Examples
./build.sh -d debian -v 13
./build.sh -d rocky -v 9
./build.sh -d ubuntu -v 24

# Required environment (set by sourcing registry config)
SSH_KEY          # Public key to inject
CONTAINER_TOKEN  # Registry authentication token
REGISTRY_HOST    # Registry URL (ghcr.io or gitea.a0a0.org:3001)
REGISTRY_USER    # Registry username (jackaltx)
REGISTRY_REPO    # Repository name (testing-containers)
```

## Registry Configuration

Registry credentials stored in `~/.secrets/testing-containers-registry.conf` (NOT in repo):

```bash
# GitHub Container Registry
source ~/.secrets/testing-containers-registry.conf github

# Gitea Lab Registry
source ~/.secrets/testing-containers-registry.conf gitea
```

## Key Files

- `debian/Containerfile` - Debian/Ubuntu build definition (parameterized)
- `rocky/Containerfile` - Rocky build definition (parameterized)
- `build.sh` - Build and push script
- `run-podman.sh` - Local test runner
- `cleanup-podman.sh` - Clean up test containers

## Image Naming

Output images follow pattern: `{distro}-ssh:{version}`

Examples:
- `ghcr.io/jackaltx/testing-containers/debian-ssh:13`
- `ghcr.io/jackaltx/testing-containers/rocky-ssh:9`
- `gitea.a0a0.org:3001/jackaltx/testing-containers/ubuntu-ssh:24`

## Design Philosophy

**Keep it minimal.** Don't suggest:
- Additional packages beyond base requirements
- Configuration management tools
- Monitoring agents
- Custom configurations

User wants factory defaults for consistent, predictable testing environments.
