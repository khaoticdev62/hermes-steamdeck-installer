#!/usr/bin/env bash
# ==============================================================================
#  HermDeck Universal Installer Launcher
#  Auto-detects Steam Deck (x86_64) vs Raspberry Pi 5 (aarch64 / ARM)
# ==============================================================================

set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
arch="$(uname -m)"
is_rpi=false

if [[ -f "/proc/device-tree/model" ]]; then
    if grep -qi "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
        is_rpi=true
    fi
fi

if [[ "${arch}" == "aarch64" || "${arch}" == "arm64" ]]; then
    is_rpi=true
fi

# Manual argument overrides
if [[ "${1:-}" == "--pi" || "${1:-}" == "--pi5" || "${1:-}" == "--rpi" ]]; then
    shift
    exec bash "${script_dir}/install-hermdeck-pi5.sh" "$@"
elif [[ "${1:-}" == "--deck" || "${1:-}" == "--steamdeck" ]]; then
    shift
    exec bash "${script_dir}/install-hermes-steamdeck.sh" "$@"
fi

if [[ "${is_rpi}" == true ]]; then
    echo "[HermDeck] Detected ARM / Raspberry Pi 5 platform (${arch}). Launching Pi 5 Suite..."
    exec bash "${script_dir}/install-hermdeck-pi5.sh" "$@"
else
    echo "[HermDeck] Detected x86_64 / Steam Deck platform (${arch}). Launching Steam Deck Suite..."
    exec bash "${script_dir}/install-hermes-steamdeck.sh" "$@"
fi
