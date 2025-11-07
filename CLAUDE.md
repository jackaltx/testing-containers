# CLAUDE.md

AI context for working with testing containers.

## Core Purpose

**Factory-default containers for Ansible testing. SSH + Python. Nothing more.**

These are deliberately minimal - don't suggest adding features. User wants stock OS configurations for reliable Ansible role testing.

## Quick Commands

```bash
# Build (requires SSH_KEY and token)
./build.sh debian12-ssh
./build.sh rocky9x-ssh
./build.sh ubuntu24-ssh

# Test locally
export CONTAINER_TYPE=debian12-ssh
./run-podman.sh
ssh -p 2222 jackaltx@localhost
./cleanup-podman.sh
```

## What's Included

Three distributions:
- **debian12-ssh**: Debian 12, apt, OpenSSH
- **rocky9x-ssh**: Rocky Linux 9.x, dnf, OpenSSH
- **ubuntu24-ssh**: Ubuntu 24.04 LTS, apt, OpenSSH

Each has:
- Python 3 (Ansible requirement)
- OpenSSH server (key-based only)
- systemd (for service testing)
- sudo (passwordless for jackaltx user)

## Build System

```bash
# Syntax
./build.sh <container-type>

# Environment variables
SSH_KEY          # Required - public key to inject
CONTAINER_TOKEN  # For ghcr.io (default registry)
GITEA_TOKEN      # For Gitea registry
REGISTRY_HOST    # Defaults to ghcr.io
```

## Key Files

- `debian12-ssh/Containerfile` - Debian build definition
- `rocky9x-ssh/Containerfile` - Rocky build definition
- `ubuntu24-ssh/Containerfile` - Ubuntu build definition
- `build.sh` - Build and push script
- `run-podman.sh` - Local test runner
- `cleanup-podman.sh` - Clean up test containers

## Design Philosophy

**Keep it minimal.** Don't suggest:
- Additional packages beyond base requirements
- Configuration management tools
- Monitoring agents
- Custom configurations

User wants factory defaults for consistent, predictable testing environments.
