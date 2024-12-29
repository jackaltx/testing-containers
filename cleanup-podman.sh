#!/bin/sh
podman stop test_container || true
podman rm test_container || true
podman rmi rocky93-ssh || true
