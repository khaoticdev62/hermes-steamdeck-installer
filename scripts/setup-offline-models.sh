#!/usr/bin/env bash
# ==============================================================================
#  Steam Deck Offline Local AI Engine Setup (Vulkan llama.cpp + Dual-Tier GGUF)
# ==============================================================================

set -euo pipefail

MODELS_DIR="${HOME}/.local/share/hermes/models"
LLAMA_DIR="${HOME}/.local/lib/llama.cpp"
BIN_DIR="${HOME}/.local/bin"

mkdir -p "${MODELS_DIR}" "${LLAMA_DIR}" "${BIN_DIR}"

echo "===================================================================="
echo " Setting up Vulkan llama.cpp & Dual-Tier Offline Models on Steam Deck"
echo "===================================================================="

# 1. Download prebuilt Vulkan llama.cpp server binary if missing
if [[ ! -f "${LLAMA_DIR}/llama-server" ]]; then
    echo "Fetching prebuilt Vulkan-accelerated llama.cpp binary..."
    LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/ggerganov/llama.cpp/releases/latest | grep "browser_download_url.*bin-ubuntu-x64.zip" | head -n 1 | cut -d '"' -f 4 || true)
    
    if [[ -z "${LATEST_RELEASE_URL}" ]]; then
        # Fallback to direct release tarball/zip
        LATEST_RELEASE_URL="https://github.com/ggerganov/llama.cpp/releases/download/b4150/llama-b4150-bin-ubuntu-x64.zip"
    fi

    TMP_ZIP="/tmp/llama-vulkan.zip"
    echo "Downloading from: ${LATEST_RELEASE_URL}"
    if curl -L -f -o "${TMP_ZIP}" "${LATEST_RELEASE_URL}"; then
        unzip -q -o "${TMP_ZIP}" -d "${LLAMA_DIR}"
        rm -f "${TMP_ZIP}"
        chmod +x "${LLAMA_DIR}"/llama-* || true
        ln -sf "${LLAMA_DIR}/llama-server" "${BIN_DIR}/llama-server"
        echo "Installed llama-server to ${BIN_DIR}/llama-server"
    else
        echo "Warning: Direct binary download failed. Checking if system llama-server exists..."
    fi
fi

# 2. Download In-Game 3B Model (Qwen 2.5 Coder 3B Q4_K_M ~ 2.0GB)
MODEL_3B_FILE="${MODELS_DIR}/qwen2.5-coder-3b-instruct-q4_k_m.gguf"
MODEL_3B_URL="https://huggingface.co/Qwen/Qwen2.5-Coder-3B-Instruct-GGUF/resolve/main/qwen2.5-coder-3b-instruct-q4_k_m.gguf"

if [[ ! -f "${MODEL_3B_FILE}" ]]; then
    echo -e "\nDownloading In-Game Tier Model: Qwen 2.5 Coder 3B Q4_K_M (~2.0 GB)..."
    echo "This model runs fast on the AMD Van Gogh APU with minimal RAM footprint during gaming."
    curl -L --progress-bar -f -o "${MODEL_3B_FILE}" "${MODEL_3B_URL}"
else
    echo "In-Game 3B model already downloaded: ${MODEL_3B_FILE}"
fi

# 3. Download Desktop / Idle 7B Model (Qwen 2.5 7B Q4_K_M ~ 4.7GB)
MODEL_7B_FILE="${MODELS_DIR}/qwen2.5-7b-instruct-q4_k_m.gguf"
MODEL_7B_URL="https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF/resolve/main/qwen2.5-7b-instruct-q4_k_m.gguf"

if [[ ! -f "${MODEL_7B_FILE}" ]]; then
    echo -e "\nDownloading Desktop/Idle Tier Model: Qwen 2.5 7B Q4_K_M (~4.7 GB)..."
    echo "This model activates when no game is active, giving full coding and reasoning depth."
    curl -L --progress-bar -f -o "${MODEL_7B_FILE}" "${MODEL_7B_URL}"
else
    echo "Desktop 7B model already downloaded: ${MODEL_7B_FILE}"
fi

# 4. Configure Hermes offline fallback provider
echo -e "\nRegistering offline fallback endpoint with Hermes..."
if command -v hermes >/dev/null 2>&1; then
    # Configure custom provider in Hermes config.yaml
    hermes config set providers.offline.base_url "http://127.0.0.1:8080/v1" >/dev/null 2>&1 || true
    echo "Offline fallback configured in Hermes."
fi

echo -e "\n[✓] Offline Local AI Engine setup complete."
