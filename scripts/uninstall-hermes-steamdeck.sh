#!/usr/bin/env bash
# ==============================================================================
#  HermDeck Installer Steam Deck - Modular Clean Uninstaller & Rollback Tool
# ==============================================================================

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${RED}====================================================================${NC}"
echo -e "${BOLD}       HermDeck Installer Steam Deck - Clean Uninstaller & Prune${NC}"
echo -e "${BOLD}${RED}====================================================================${NC}"

# 1. Stop & Remove Systemd Services
remove_services() {
    echo -e "\n${CYAN}[1/6] Stopping and disabling background user services...${NC}"
    systemctl --user stop hermes-adaptive-model.service hermes-code-server.service 2>/dev/null || true
    systemctl --user disable hermes-adaptive-model.service hermes-code-server.service 2>/dev/null || true
    rm -f "${HOME}/.config/systemd/user/hermes-adaptive-model.service"
    rm -f "${HOME}/.config/systemd/user/hermes-code-server.service"
    systemctl --user daemon-reload 2>/dev/null || true
    echo -e "${GREEN}[✓] Background services removed.${NC}"
}

# 2. Remove Steam Shortcuts & Grid Artwork
remove_steam_shortcuts() {
    echo -e "\n${CYAN}[2/6] Cleaning Steam shortcuts and grid artwork...${NC}"
    local steam_dir="${HOME}/.steam/steam"
    if [[ ! -d "${steam_dir}" ]]; then
        steam_dir="${HOME}/.local/share/Steam"
    fi

    # Clean shortcuts.vdf entries via Python
    python3 - << 'EOF' 2>/dev/null || true
import os
import glob
from pathlib import Path

steam_dir = Path.home() / ".steam" / "steam"
if not steam_dir.is_dir():
    steam_dir = Path.home() / ".local" / "share" / "Steam"

userdata = steam_dir / "userdata"
if userdata.is_dir():
    for sc in userdata.glob("*/config/shortcuts.vdf"):
        try:
            data = sc.read_bytes()
            if b"Hermes Agent" in data:
                # Remove shortcut data block
                idx = data.find(b"\x01AppName\x00Hermes Agent\x00")
                if idx != -1:
                    start = data.rfind(b"\x000\x00", 0, idx)
                    if start == -1:
                        start = data.rfind(b"\x00", 0, idx - 10)
                    end = data.find(b"\x08\x08", idx)
                    if start != -1 and end != -1:
                        new_data = data[:start] + data[end+2:]
                        sc.write_bytes(new_data)
        except Exception:
            pass

grid_dir = steam_dir / "appcache" / "grid"
if grid_dir.is_dir():
    for f in grid_dir.glob("*hermes*"):
        try: f.unlink()
        except: pass
EOF
    echo -e "${GREEN}[✓] Steam shortcuts and artwork cleaned.${NC}"
}

# 3. Remove Decky Loader Plugin
remove_decky_plugin() {
    echo -e "\n${CYAN}[3/6] Removing Decky Loader plugin...${NC}"
    local decky_plugin_dir="${HOME}/homebrew/plugins/hermes-decky"
    if [[ -d "${decky_plugin_dir}" ]]; then
        rm -rf "${decky_plugin_dir}"
        sudo systemctl restart plugin_loader 2>/dev/null || true
        echo -e "${GREEN}[✓] Removed hermes-decky from Decky Loader.${NC}"
    else
        echo "No Decky plugin found to remove."
    fi
}

# 4. Remove Distrobox Container
remove_distrobox() {
    echo -e "\n${CYAN}[4/6] Removing Distrobox development container...${NC}"
    if command -v distrobox >/dev/null 2>&1; then
        distrobox rm -f hermes-arch-dev 2>/dev/null || true
        echo -e "${GREEN}[✓] Distrobox container 'hermes-arch-dev' removed.${NC}"
    fi
}

# 5. Prune GGUF Local Models
prune_models() {
    echo -e "\n${CYAN}Pruning offline GGUF model files to free disk space (~7GB)...${NC}"
    local models_dir="${HOME}/.local/share/hermes/models"
    if [[ -d "${models_dir}" ]]; then
        rm -rf "${models_dir}"
        echo -e "${GREEN}[✓] Reclaimed storage from GGUF models.${NC}"
    else
        echo "No models found."
    fi
}

# 6. Full Clean Wipe
full_clean_uninstall() {
    echo -e "\n${BOLD}${RED}Starting Full Clean Uninstall of Hermes Steam Deck Suite...${NC}"
    remove_services
    remove_steam_shortcuts
    remove_decky_plugin
    remove_distrobox
    prune_models

    echo -e "\n${CYAN}[5/6] Removing binaries and libraries...${NC}"
    rm -f "${HOME}/.local/bin/hermes"
    rm -f "${HOME}/.local/bin/godot4"
    rm -f "${HOME}/.local/bin/code-server"
    rm -f "${HOME}/.local/bin/llama-server"
    rm -f "${HOME}/.local/bin/hermes-*"
    rm -f "${HOME}/Desktop/Hermes-Setup.desktop"

    rm -rf "${HOME}/.local/lib/godot"
    rm -rf "${HOME}/.local/lib/code-server"
    rm -rf "${HOME}/.local/lib/llama.cpp"
    rm -rf "${HOME}/.local/share/hermes"
    rm -rf "${HOME}/.hermes"
    rm -rf "${HOME}/.local/share/hermes-installer"
    rm -rf "${HOME}/.config/code-server"

    echo -e "\n${CYAN}[6/6] Checking user game save backups...${NC}"
    if [[ -d "${HOME}/GameSaveBackups" ]]; then
        echo -e "${GREEN}[✓] User game save backups preserved in: ${HOME}/GameSaveBackups/${NC}"
    fi

    echo -e "\n${BOLD}${GREEN}====================================================================${NC}"
    echo -e "${BOLD}${GREEN} Full Uninstall Complete. Steam Deck is cleanly restored!${NC}"
    echo -e "${BOLD}${GREEN}====================================================================${NC}"
}

# Menu
show_menu() {
    echo -e "Choose an uninstallation or prune action:"
    echo -e "  ${BOLD}1)${NC} 🧹 ${BOLD}Full Clean Uninstall${NC} (Removes all components; preserves game saves)"
    echo -e "  ${BOLD}2)${NC} 💾 ${BOLD}Prune Models Only${NC} (Reclaims ~7GB disk space without removing Hermes)"
    echo -e "  ${BOLD}3)${NC} 🛑 ${BOLD}Deactivate Background Services${NC} (Stops and disables systemd services)"
    echo -e "  ${BOLD}4)${NC} ❌ Cancel & Exit"
    echo -e "--------------------------------------------------------------------"
    read -r -p "Enter selection [1-4]: " choice

    case "${choice}" in
        1)
            read -r -p "Are you sure you want to completely uninstall Hermes? [y/N]: " confirm
            if [[ "${confirm}" =~ ^[Yy]$ ]]; then
                full_clean_uninstall
            else
                echo "Uninstall aborted."
            fi
            ;;
        2)
            prune_models
            ;;
        3)
            remove_services
            ;;
        4)
            echo "Cancelled."
            exit 0
            ;;
        *)
            echo "Invalid option."
            ;;
    esac
}

show_menu
