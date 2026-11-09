#!/usr/bin/env bash
# ==============================================================================
#  Hermes Agent Steam Deck Ultimate Developer & Gaming Edition v2.3.0
#  Target OS: SteamOS 3.x (Arch-based Linux, immutable rootfs friendly)
# ==============================================================================

set -u

REPO_OWNER="khaoticdev62"
REPO_NAME="hermes-steamdeck-installer"
SCRIPT_VERSION="2.3.0"

LOG_DIR="${HOME}/.local/share/hermes-installer"
LOG_FILE="${LOG_DIR}/installer.log"
mkdir -p "${LOG_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1

APP_TITLE="Hermes Agent - Steam Deck Developer & Gaming Suite"

# ANSI Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Determine UI Mode: GUI (kdialog/zenity) or Terminal
UI_BACKEND="terminal"
if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
    if command -v kdialog >/dev/null 2>&1; then
        UI_BACKEND="kdialog"
    elif command -v zenity >/dev/null 2>&1; then
        UI_BACKEND="zenity"
    fi
fi

# Ensure user PATH includes user-space binaries
export PATH="${HOME}/.local/bin:${HOME}/.npm-global/bin:${HOME}/.local/lib/nodejs/bin:${PATH}"

ensure_user_path() {
    local bashrc="${HOME}/.bashrc"
    local path_line='export PATH="${HOME}/.local/bin:${HOME}/.npm-global/bin:${HOME}/.local/lib/nodejs/bin:${PATH}"'
    if [[ -f "${bashrc}" ]]; then
        if ! grep -q "npm-global/bin" "${bashrc}"; then
            echo "" >> "${bashrc}"
            echo "# Added by Hermes Steam Deck Installer" >> "${bashrc}"
            echo "${path_line}" >> "${bashrc}"
        fi
    fi
}
ensure_user_path

# ------------------------------------------------------------------------------
# UI Helpers
# ------------------------------------------------------------------------------

msg_info() {
    local text="$1"
    echo -e "${CYAN}[INFO]${NC} ${text}"
    if [[ "${UI_BACKEND}" == "kdialog" ]]; then
        kdialog --title "${APP_TITLE}" --msgbox "${text}" 2>/dev/null || true
    elif [[ "${UI_BACKEND}" == "zenity" ]]; then
        zenity --info --title="${APP_TITLE}" --text="${text}" --width=450 2>/dev/null || true
    fi
}

msg_success() {
    local text="$1"
    echo -e "${GREEN}[SUCCESS]${NC} ${text}"
    if [[ "${UI_BACKEND}" == "kdialog" ]]; then
        kdialog --title "${APP_TITLE}" --msgbox "${text}" 2>/dev/null || true
    elif [[ "${UI_BACKEND}" == "zenity" ]]; then
        zenity --info --title="${APP_TITLE}" --text="${text}" --width=450 2>/dev/null || true
    fi
}

msg_error() {
    local title="$1"
    local details="$2"
    echo -e "${RED}[ERROR] ${title}${NC}\n${details}"
    if [[ "${UI_BACKEND}" == "kdialog" ]]; then
        kdialog --title "Error: ${title}" --error "${details}\n\nCheck log: ${LOG_FILE}" 2>/dev/null || true
    elif [[ "${UI_BACKEND}" == "zenity" ]]; then
        zenity --error --title="Error: ${title}" --text="${details}\n\nCheck log: ${LOG_FILE}" --width=480 2>/dev/null || true
    fi
}

# ------------------------------------------------------------------------------
# Auto-Update Check
# ------------------------------------------------------------------------------

check_for_updates() {
    echo -e "${CYAN}[Update Check] Checking GitHub for latest version...${NC}"
    local latest_tag
    latest_tag=$(curl -s "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest" 2>/dev/null | grep '"tag_name":' | head -n 1 | cut -d '"' -f 4 || true)
    
    if [[ -n "${latest_tag}" && "${latest_tag#v}" != "${SCRIPT_VERSION}" ]]; then
        echo -e "${YELLOW}[!] A newer version (${latest_tag}) is available on GitHub! (Current: v${SCRIPT_VERSION})${NC}"
        if [[ "${UI_BACKEND}" == "kdialog" ]]; then
            kdialog --title "Update Available" --yesno "A newer release (${latest_tag}) is available. Would you like to update?" 2>/dev/null && update_in_place "${latest_tag}"
        fi
    else
        echo -e "${GREEN}[✓] Running latest version (v${SCRIPT_VERSION}).${NC}"
    fi
}

update_in_place() {
    local tag="$1"
    local update_url="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${tag}/hermes-steamdeck.tar.gz"
    echo "Downloading update from ${update_url}..."
    curl -L -f -o /tmp/hermes-update.tar.gz "${update_url}"
    tar -xzf /tmp/hermes-update.tar.gz -C "${HOME}"
    rm -f /tmp/hermes-update.tar.gz
    msg_success "Updated to ${tag}! Please restart the installer."
    exit 0
}

# ------------------------------------------------------------------------------
# Module Implementations
# ------------------------------------------------------------------------------

# Module 1: Core Engine (Hermes + Claude + Codex)
install_core_engine() {
    echo -e "\n${BOLD}${CYAN}=== Installing Hermes Core Engine & Subscription Providers ===${NC}"
    
    mkdir -p "${HOME}/.local/bin" "${HOME}/.npm-global/bin" "${HOME}/.hermes"
    npm config set prefix "${HOME}/.npm-global" >/dev/null 2>&1 || true

    if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
        echo "Installing user-space Node.js LTS..."
        local NODE_DIR="${HOME}/.local/lib/nodejs"
        mkdir -p "${NODE_DIR}"
        curl -fsSL "https://nodejs.org/dist/v20.18.0/node-v20.18.0-linux-x64.tar.xz" | tar -xJ -C "${NODE_DIR}" --strip-components=1
        export PATH="${NODE_DIR}/bin:${PATH}"
    fi

    if ! command -v hermes >/dev/null 2>&1; then
        echo "Installing Hermes Agent..."
        curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
        export PATH="${HOME}/.local/bin:${PATH}"
    fi

    if ! command -v claude >/dev/null 2>&1; then
        echo "Installing @anthropic-ai/claude-code..."
        npm install -g @anthropic-ai/claude-code
    fi

    if ! claude auth status 2>/dev/null | grep -q '"loggedIn": true'; then
        echo -e "${YELLOW}Please authenticate your Claude subscription in the browser prompt:${NC}"
        claude auth login
    fi

    echo "Installing claude-subscription-directsdk plugin..."
    hermes plugins install --yes-deps --enable claude-subscription-directsdk >/dev/null 2>&1 || true
    hermes config set model.provider claude-subscription-directsdk-experimental
    hermes config unset model.base_url >/dev/null 2>&1 || true
    hermes config set model.default sonnet

    if ! hermes auth list 2>/dev/null | grep -q "openai-codex"; then
        echo -e "${YELLOW}Starting OpenAI Codex OAuth setup:${NC}"
        hermes auth add openai-codex
    fi

    echo -e "${GREEN}[✓] Core Engine and Providers configured.${NC}"
}

# Module 2: Steam Gaming Mode & Grid Art
install_gaming_mode() {
    echo -e "\n${BOLD}${CYAN}=== Configuring Steam Gaming Mode & Grid Artwork ===${NC}"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "${script_dir}/scripts/install-gaming-mode.py" ]]; then
        python3 "${script_dir}/scripts/install-gaming-mode.py"
    else
        echo "Error: install-gaming-mode.py not found."
    fi
}

# Module 3: Steam Input Official Controller Template
install_steam_input() {
    echo -e "\n${BOLD}${CYAN}=== Installing Steam Input Radial Touch Menu Gamepad Profile ===${NC}"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "${script_dir}/scripts/setup-steam-input.py" ]]; then
        python3 "${script_dir}/scripts/setup-steam-input.py"
    else
        echo "Error: setup-steam-input.py not found."
    fi
}

# Module 4: Decky Loader QAM Plugin
install_decky_plugin() {
    echo -e "\n${BOLD}${CYAN}=== Deploying Decky Loader QAM Plugin ===${NC}"
    local DECKY_PLUGINS_DIR="${HOME}/homebrew/plugins"
    local TARGET_DIR="${DECKY_PLUGINS_DIR}/hermes-decky"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    mkdir -p "${TARGET_DIR}"
    if [[ -d "${script_dir}/decky-plugin" ]]; then
        cp -r "${script_dir}/decky-plugin/"* "${TARGET_DIR}/"
        echo -e "${GREEN}[✓] Decky plugin installed to ${TARGET_DIR}.${NC}"
    fi
}

# Module 5: Offline Adaptive Local AI
install_offline_engine() {
    echo -e "\n${BOLD}${CYAN}=== Setting up Offline Adaptive Vulkan Local AI ===${NC}"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "${script_dir}/scripts/setup-offline-models.sh" ]]; then
        bash "${script_dir}/scripts/setup-offline-models.sh"
        
        local SERVICE_DIR="${HOME}/.config/systemd/user"
        mkdir -p "${SERVICE_DIR}"
        cat <<EOF > "${SERVICE_DIR}/hermes-adaptive-model.service"
[Unit]
Description=Hermes Game-Aware Adaptive Local Model Daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 ${script_dir}/scripts/adaptive-model-daemon.py
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF
        systemctl --user daemon-reload >/dev/null 2>&1 || true
        systemctl --user enable --now hermes-adaptive-model.service >/dev/null 2>&1 || true
        echo -e "${GREEN}[✓] Adaptive local model daemon enabled as user service.${NC}"
    fi
}

# Module 6: Hybrid Voice Assistant
install_voice_assistant() {
    echo -e "\n${BOLD}${CYAN}=== Configuring Hybrid Voice Assistant ===${NC}"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "${script_dir}/scripts/setup-voice.sh" ]]; then
        bash "${script_dir}/scripts/setup-voice.sh"
    fi
}

# Module 7: SteamOS Ops Skills
install_steamos_ops() {
    echo -e "\n${BOLD}${CYAN}=== Installing SteamOS Ops Skill into Hermes ===${NC}"
    local SKILLS_DIR="${HOME}/.hermes/skills/steamos-ops"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    mkdir -p "${SKILLS_DIR}"

    if [[ -d "${script_dir}/skills/steamos-ops" ]]; then
        cp -r "${script_dir}/skills/steamos-ops/"* "${SKILLS_DIR}/"
        echo -e "${GREEN}[✓] Installed steamos-ops skill to ${SKILLS_DIR}.${NC}"
    fi
}

# Module 8: Developer Studio & App Dev Suite (Hardened)
install_developer_studio() {
    echo -e "\n${BOLD}${MAGENTA}=== Setting up Steam Deck Developer Studio & App Dev Suite (Hardened) ===${NC}"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    echo -e "\n[1/4] Installing Distrobox & Podman Arch Dev Container..."
    if [[ -f "${script_dir}/scripts/setup-distrobox-podman.sh" ]]; then
        bash "${script_dir}/scripts/setup-distrobox-podman.sh"
    fi

    echo -e "\n[2/4] Setting up code-server Web IDE & SSH Remote Access (Hardened)..."
    if [[ -f "${script_dir}/scripts/setup-code-server.sh" ]]; then
        bash "${script_dir}/scripts/setup-code-server.sh"
    fi

    echo -e "\n[3/4] Installing Portable Godot 4 Game Engine..."
    if [[ -f "${script_dir}/scripts/setup-godot.sh" ]]; then
        bash "${script_dir}/scripts/setup-godot.sh"
    fi

    echo -e "\n[4/4] Registering App Development Skills (godot-agent, decky-builder, container-ops)..."
    local skills_base="${HOME}/.hermes/skills"
    mkdir -p "${skills_base}/godot-agent" "${skills_base}/decky-builder" "${skills_base}/container-ops"

    for s in "godot-agent" "decky-builder" "container-ops"; do
        if [[ -d "${script_dir}/skills/${s}" ]]; then
            cp -r "${script_dir}/skills/${s}/"* "${skills_base}/${s}/"
            echo "Installed ${s} skill."
        fi
    done

    echo -e "${GREEN}[✓] Developer Studio Suite installed successfully!${NC}"
}

# Module 9: Diagnostics
run_diagnostics() {
    echo -e "\n${BOLD}${CYAN}=== Running Full System Diagnostics ===${NC}"
    
    echo -n "Checking Hermes CLI: "
    if command -v hermes >/dev/null 2>&1; then echo -e "${GREEN}OK (${NC}$(hermes --version 2>/dev/null || echo 'Installed')${GREEN})${NC}"; else echo -e "${RED}MISSING${NC}"; fi

    echo -n "Checking Claude DirectSDK: "
    if hermes chat -q "Respond with 'Claude OK' and nothing else." 2>&1 | grep -iq "Claude OK"; then
        echo -e "${GREEN}PASSED${NC}"
    else
        echo -e "${RED}FAILED${NC}"
    fi

    echo -n "Checking OpenAI Codex OAuth: "
    if hermes chat --provider openai-codex -q "Respond with 'Codex OK' and nothing else." 2>&1 | grep -iq "Codex OK"; then
        echo -e "${GREEN}PASSED${NC}"
    else
        echo -e "${YELLOW}NOT CONFIGURED / FAILED${NC}"
    fi

    echo -n "Checking Steam Gaming Mode Shortcut: "
    local found_sc=false
    for f in "${HOME}"/.steam/steam/userdata/*/config/shortcuts.vdf "${HOME}"/.local/share/Steam/userdata/*/config/shortcuts.vdf; do
        if [[ -f "${f}" ]] && grep -q "Hermes Agent" "${f}" 2>/dev/null; then found_sc=true; break; fi
    done
    if [[ "${found_sc}" == "true" ]]; then echo -e "${GREEN}INSTALLED${NC}"; else echo -e "${YELLOW}NOT FOUND${NC}"; fi

    echo -n "Checking Godot 4: "
    if command -v godot4 >/dev/null 2>&1; then echo -e "${GREEN}INSTALLED${NC}"; else echo -e "${YELLOW}NOT INSTALLED${NC}"; fi

    echo -n "Checking code-server: "
    if command -v code-server >/dev/null 2>&1; then echo -e "${GREEN}INSTALLED (Port 8443, Protected)${NC}"; else echo -e "${YELLOW}NOT INSTALLED${NC}"; fi

    echo -n "Checking Distrobox: "
    if command -v distrobox >/dev/null 2>&1; then echo -e "${GREEN}INSTALLED${NC}"; else echo -e "${YELLOW}NOT INSTALLED${NC}"; fi
}

# 🌟 Option 1: Complete Ultimate Setup (Gaming + Dev + Steam Input)
run_ultimate_setup() {
    clear
    echo -e "${BOLD}${MAGENTA}====================================================================${NC}"
    echo -e "${BOLD}   Executing Ultimate Steam Deck Setup (All Gaming & Dev Modules)${NC}"
    echo -e "${BOLD}${MAGENTA}====================================================================${NC}"
    install_core_engine
    install_gaming_mode
    install_steam_input
    install_decky_plugin
    install_offline_engine
    install_voice_assistant
    install_steamos_ops
    install_developer_studio
    run_diagnostics
    msg_success "Ultimate Steam Deck Setup Complete! Hermes is now fully configured as your gaming companion AND autonomous handheld developer studio with official controller profiles."
}

# ------------------------------------------------------------------------------
# Main Interactive Menu
# ------------------------------------------------------------------------------

show_gui_menu() {
    if [[ "${UI_BACKEND}" == "kdialog" ]]; then
        kdialog --title "${APP_TITLE}" --menu "Select an option for your Steam Deck:" \
            "1" "🌟 Full Ultimate Setup (Gaming + Dev + Gamepad Profile)" \
            "2" "Core Engine (Hermes + Claude + Codex)" \
            "3" "🛠️ Developer Studio Suite (code-server, Godot 4, Distrobox)" \
            "4" "Steam Gaming Mode & Grid Art Injection" \
            "5" "🎮 Install Steam Input Radial Touch Menu Gamepad Profile" \
            "6" "Decky Loader QAM Plugin Deployment" \
            "7" "Offline Adaptive AI (Vulkan llama.cpp + 3B/7B GGUF)" \
            "8" "Hybrid Voice Assistant (Whisper + Piper TTS)" \
            "9" "SteamOS Ops Toolkit Skill" \
            "10" "Run Full Health & Diagnostics" \
            "11" "Check for Updates from GitHub" \
            "12" "Launch Hermes Agent" \
            "13" "🧹 Clean Uninstaller & Storage Prune" \
            "14" "Exit" 2>/dev/null
    elif [[ "${UI_BACKEND}" == "zenity" ]]; then
        zenity --list --title="${APP_TITLE}" --text="Select an option for your Steam Deck:" \
            --column="Option" --column="Description" --width=560 --height=460 \
            "1" "🌟 Full Ultimate Setup (Gaming + Dev + Gamepad Profile)" \
            "2" "Core Engine (Hermes + Claude + Codex)" \
            "3" "🛠️ Developer Studio Suite (code-server, Godot 4, Distrobox)" \
            "4" "Steam Gaming Mode & Grid Art Injection" \
            "5" "🎮 Install Steam Input Radial Touch Menu Gamepad Profile" \
            "6" "Decky Loader QAM Plugin Deployment" \
            "7" "Offline Adaptive AI (Vulkan llama.cpp + 3B/7B GGUF)" \
            "8" "Hybrid Voice Assistant (Whisper + Piper TTS)" \
            "9" "SteamOS Ops Toolkit Skill" \
            "10" "Run Full Health & Diagnostics" \
            "11" "Check for Updates from GitHub" \
            "12" "Launch Hermes Agent" \
            "13" "🧹 Clean Uninstaller & Storage Prune" \
            "14" "Exit" 2>/dev/null
    fi
}

main() {
    check_for_updates

    while true; do
        local choice=""
        if [[ "${UI_BACKEND}" != "terminal" ]]; then
            choice=$(show_gui_menu)
            if [[ -z "${choice}" ]]; then exit 0; fi
        else
            echo -e "\n${BOLD}${CYAN}====================================================================${NC}"
            echo -e "${BOLD}   ${APP_TITLE} (v${SCRIPT_VERSION})${NC}"
            echo -e "${BOLD}${CYAN}====================================================================${NC}"
            echo -e "  ${BOLD}${MAGENTA}1)${NC} 🌟 ${BOLD}Full Ultimate Setup${NC} (Gaming + Dev + Steam Input Profile)"
            echo -e "  ${BOLD}2)${NC} Core Engine (Hermes + Claude DirectSDK + Codex OAuth)"
            echo -e "  ${BOLD}3)${NC} 🛠️ ${BOLD}Developer Studio Suite${NC} (code-server, Godot 4, Distrobox, Dev Skills)"
            echo -e "  ${BOLD}4)${NC} Steam Gaming Mode & Grid Art Injection"
            echo -e "  ${BOLD}5)${NC} 🎮 ${BOLD}Install Steam Input Radial Menu Gamepad Profile${NC}"
            echo -e "  ${BOLD}6)${NC} Decky Loader QAM Plugin Deployment"
            echo -e "  ${BOLD}7)${NC} Offline Adaptive Local AI (Vulkan llama.cpp + Dual GGUF)"
            echo -e "  ${BOLD}8)${NC} Hybrid Voice Assistant (Faster-Whisper + Piper TTS)"
            echo -e "  ${BOLD}9)${NC} SteamOS Ops Toolkit Skill (ProtonDB, Compatdata, Saves)"
            echo -e "  ${BOLD}10)${NC} Run Full Health & Diagnostics Check"
            echo -e "  ${BOLD}11)${NC} Check for Updates from GitHub"
            echo -e "  ${BOLD}12)${NC} Launch Hermes Agent"
            echo -e "  ${BOLD}13)${NC} 🧹 ${BOLD}Clean Uninstaller & Storage Prune${NC}"
            echo -e "  ${BOLD}14)${NC} Exit"
            echo -e "--------------------------------------------------------------------"
            read -r -p "Enter selection [1-14]: " choice
        fi

        case "${choice}" in
            1) run_ultimate_setup; read -r -p "Press Enter to continue..." ;;
            2) install_core_engine; read -r -p "Press Enter to continue..." ;;
            3) install_developer_studio; read -r -p "Press Enter to continue..." ;;
            4) install_gaming_mode; read -r -p "Press Enter to continue..." ;;
            5) install_steam_input; read -r -p "Press Enter to continue..." ;;
            6) install_decky_plugin; read -r -p "Press Enter to continue..." ;;
            7) install_offline_engine; read -r -p "Press Enter to continue..." ;;
            8) install_voice_assistant; read -r -p "Press Enter to continue..." ;;
            9) install_steamos_ops; read -r -p "Press Enter to continue..." ;;
            10) run_diagnostics; read -r -p "Press Enter to continue..." ;;
            11) check_for_updates; read -r -p "Press Enter to continue..." ;;
            12)
                if command -v konsole >/dev/null 2>&1; then
                    konsole -e bash -c "hermes; bash" &
                else
                    hermes
                fi
                ;;
            13)
                local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
                if [[ -f "${script_dir}/scripts/uninstall-hermes-steamdeck.sh" ]]; then
                    bash "${script_dir}/scripts/uninstall-hermes-steamdeck.sh"
                fi
                read -r -p "Press Enter to continue..."
                ;;
            14) echo "Exiting."; exit 0 ;;
            *) echo "Invalid option."; sleep 1 ;;
        esac
    done
}

main
