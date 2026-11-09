#!/usr/bin/env bash
# ==============================================================================
#  Steam Deck Hybrid Voice Assistant Setup (Faster-Whisper + Piper TTS)
# ==============================================================================

set -euo pipefail

VOICE_DIR="${HOME}/.local/share/hermes/voice"
PIPER_DIR="${VOICE_DIR}/piper"
BIN_DIR="${HOME}/.local/bin"

mkdir -p "${VOICE_DIR}" "${PIPER_DIR}" "${BIN_DIR}"

echo "===================================================================="
echo " Setting up Hybrid Voice Assistant on Steam Deck (Whisper + Piper)"
echo "===================================================================="

# 1. Download Piper TTS standalone binary & neural voice model if missing
if [[ ! -f "${PIPER_DIR}/piper" ]]; then
    echo "Downloading standalone Piper TTS engine..."
    PIPER_TAR="/tmp/piper_amd64.tar.gz"
    PIPER_URL="https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_amd64.tar.gz"
    
    if curl -L -f -o "${PIPER_TAR}" "${PIPER_URL}"; then
        tar -xzf "${PIPER_TAR}" -C "${VOICE_DIR}"
        rm -f "${PIPER_TAR}"
        ln -sf "${PIPER_DIR}/piper" "${BIN_DIR}/piper"
        echo "Piper TTS installed to ${BIN_DIR}/piper"
    fi
fi

# Download high-quality low-latency voice model (en_US-lessac-medium)
VOICE_ONNX="${PIPER_DIR}/en_US-lessac-medium.onnx"
VOICE_JSON="${PIPER_DIR}/en_US-lessac-medium.onnx.json"

if [[ ! -f "${VOICE_ONNX}" ]]; then
    echo "Downloading Piper neural voice model (Lessac Medium)..."
    curl -L -f -o "${VOICE_ONNX}" "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx"
    curl -L -f -o "${VOICE_JSON}" "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json"
fi

# 2. Setup Python environment for Faster-Whisper
echo "Configuring lightweight faster-whisper environment..."
python3 -m pip install --user --upgrade faster-whisper sounddevice numpy >/dev/null 2>&1 || true

# 3. Install paddle voice listener script
cp "$(dirname "$0")/voice_paddle_listener.py" "${BIN_DIR}/hermes-voice-listener"
chmod +x "${BIN_DIR}/hermes-voice-listener"

echo -e "\n[✓] Steam Deck Hybrid Voice Assistant setup complete."
echo "Launch voice listener with: hermes-voice-listener"
