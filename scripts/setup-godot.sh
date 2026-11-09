#!/usr/bin/env bash
# ==============================================================================
#  Steam Deck Portable Godot 4 Engine Setup
# ==============================================================================

set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
LIB_DIR="${HOME}/.local/lib"
GODOT_DIR="${LIB_DIR}/godot"

mkdir -p "${BIN_DIR}" "${GODOT_DIR}"

echo "===================================================================="
echo " Installing Standalone Godot 4 Engine on Steam Deck"
echo "===================================================================="

GODOT_VERSION="4.3-stable"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
GODOT_BIN="${GODOT_DIR}/Godot_v${GODOT_VERSION}_linux.x86_64"

if [[ ! -f "${GODOT_BIN}" ]]; then
    echo "Downloading Godot ${GODOT_VERSION} from GitHub..."
    TMP_ZIP="/tmp/godot.zip"
    if curl -L -f -o "${TMP_ZIP}" "${GODOT_URL}"; then
        unzip -q -o "${TMP_ZIP}" -d "${GODOT_DIR}"
        rm -f "${TMP_ZIP}"
        chmod +x "${GODOT_BIN}"
        ln -sf "${GODOT_BIN}" "${BIN_DIR}/godot4"
        echo "[✓] Godot 4 installed to ${BIN_DIR}/godot4"
    else
        echo "Error: Failed to download Godot 4."
        exit 1
    fi
else
    echo "Godot 4 is already installed at ${GODOT_BIN}"
    ln -sf "${GODOT_BIN}" "${BIN_DIR}/godot4"
fi

echo -e "\n[✓] Portable Godot 4 Engine ready."
echo "Launch with: godot4 (or use through Hermes via 'godot-agent' skill)"
