#!/usr/bin/env bash
# ==============================================================================
#  Steam Deck Rootless Distrobox & Podman Dev Container Setup
#  Survives SteamOS updates by storing all containers in /home/deck/
# ==============================================================================

set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
mkdir -p "${BIN_DIR}"

echo "===================================================================="
echo " Setting up Rootless Distrobox & Podman Dev Containers on Steam Deck"
echo "===================================================================="

# 1. Install or verify standalone Distrobox in user-space
if ! command -v distrobox >/dev/null 2>&1; then
    echo "Downloading standalone user-space Distrobox..."
    curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix "${HOME}/.local"
    echo "Distrobox installed to ${BIN_DIR}/distrobox"
else
    echo "Distrobox already installed: $(distrobox --version 2>/dev/null || echo 'OK')"
fi

# 2. Check Podman
if ! command -v podman >/dev/null 2>&1; then
    echo "Checking for SteamOS built-in Podman or fallback..."
    if [[ -f "/usr/bin/podman" ]]; then
        export PATH="/usr/bin:${PATH}"
    else
        echo "Note: Podman will be accessed via rootless socket or Distrobox container engine."
    fi
fi

# 3. Create persistent Arch Linux Development Container: 'hermes-arch-dev'
CONTAINER_NAME="hermes-arch-dev"
echo "Checking Distrobox container: ${CONTAINER_NAME}..."

if distrobox list 2>/dev/null | grep -q "${CONTAINER_NAME}"; then
    echo "Container '${CONTAINER_NAME}' already exists."
else
    echo "Creating persistent Arch Linux development container '${CONTAINER_NAME}'..."
    echo "This provides full 'pacman' access for GCC, Clang, Rust, Go, Python, and C/C++ libraries."
    distrobox create --name "${CONTAINER_NAME}" --image docker.io/library/archlinux:latest --yes || true
    echo "Container created. Initialize packages with: distrobox enter ${CONTAINER_NAME}"
fi

# 4. Create convenient wrapper scripts
cat << 'EOF' > "${BIN_DIR}/hermes-dev-shell"
#!/usr/bin/env bash
# Launch directly into the persistent Arch Linux development container
exec distrobox enter hermes-arch-dev -- "$@"
EOF
chmod +x "${BIN_DIR}/hermes-dev-shell"

echo -e "\n[✓] Distrobox development container environment ready."
echo "Run 'hermes-dev-shell' to open an Arch dev shell with full compiler support."
