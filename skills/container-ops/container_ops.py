"""Rootless Container & Distrobox Tooling for Hermes Agent on SteamOS."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path
from typing import Any, Dict, Optional


def run_distrobox_cmd(command: str, container: str = "hermes-arch-dev") -> Dict[str, Any]:
    """Execute a shell command inside the persistent Arch Linux development container.

    Args:
        command: Command string (e.g. 'pacman -Syu --noconfirm gcc make', 'cargo build', 'python -m pytest').
        container: Name of container (default: 'hermes-arch-dev').
    """
    cmd = ["distrobox", "enter", container, "--", "bash", "-c", command]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        return {
            "status": "success" if res.returncode == 0 else "error",
            "exit_code": res.returncode,
            "stdout": res.stdout,
            "stderr": res.stderr
        }
    except Exception as e:
        return {"status": "error", "message": f"Execution failed: {e}"}


def podman_build(dockerfile_dir: str, image_tag: str) -> Dict[str, Any]:
    """Build a container image rootlessly using Podman.

    Args:
        dockerfile_dir: Path to directory containing Dockerfile.
        image_tag: Name/tag for image (e.g. 'my-app:latest').
    """
    p = Path(dockerfile_dir).expanduser()
    cmd = ["podman", "build", "-t", image_tag, str(p)]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        return {
            "status": "success" if res.returncode == 0 else "error",
            "exit_code": res.returncode,
            "stdout": res.stdout,
            "stderr": res.stderr
        }
    except Exception as e:
        return {"status": "error", "message": f"Build failed: {e}"}


def podman_compose_up(compose_file_dir: str) -> Dict[str, Any]:
    """Launch a multi-container stack rootlessly using Podman compose.

    Args:
        compose_file_dir: Directory containing docker-compose.yml or podman-compose.yml.
    """
    p = Path(compose_file_dir).expanduser()
    cmd = ["podman", "compose", "up", "-d"]
    try:
        res = subprocess.run(cmd, cwd=str(p), capture_output=True, text=True, timeout=60)
        return {
            "status": "success" if res.returncode == 0 else "error",
            "exit_code": res.returncode,
            "stdout": res.stdout,
            "stderr": res.stderr
        }
    except Exception as e:
        return {"status": "error", "message": f"Compose up failed: {e}"}
