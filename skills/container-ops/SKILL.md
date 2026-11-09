---
name: container-ops
description: Rootless Podman and Distrobox container management for SteamOS. Run pacman, cargo, gcc, and build Dockerfiles or compose stacks inside persistent home containers that survive SteamOS system updates.
---

# Container & Distrobox Operations Skill

Allows Hermes to execute builds, compile native C/Rust/Go code, and manage rootless containers without touching or disabling SteamOS's read-only root filesystem.

## Capabilities

1. **`run_distrobox_cmd(command, container='hermes-arch-dev')`**: Runs any command inside the persistent Arch Linux development container with full package manager (`pacman`) and compiler access.
2. **`podman_build(dockerfile_dir, image_tag)`**: Builds a container image rootlessly using Podman.
3. **`podman_compose_up(compose_file_dir)`**: Launches multi-container microservice stacks on the Steam Deck.
