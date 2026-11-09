#!/usr/bin/env bash
# ==============================================================================
#  Hermes Agent + Claude DirectSDK + OpenAI Codex Installer for Steam Deck
#  Target OS: SteamOS 3.x (Arch-based Linux, immutable rootfs friendly)
# ==============================================================================

set -u

LOG_DIR="${HOME}/.local/share/hermes-installer"
LOG_FILE="${LOG_DIR}/installer.log"
mkdir -p "${LOG_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1

APP_TITLE="Hermes Agent Steam Deck Installer"
VERSION="1.0.0"

# Colors for terminal mode
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

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

# Write PATH exports to ~/.bashrc if not already present
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
# UI Abstraction Layer (GUI & Terminal)
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

ask_yes_no() {
    local prompt="$1"
    if [[ "${UI_BACKEND}" == "kdialog" ]]; then
        kdialog --title "${APP_TITLE}" --yesno "${prompt}" 2>/dev/null
        return $?
    elif [[ "${UI_BACKEND}" == "zenity" ]]; then
        zenity --question --title="${APP_TITLE}" --text="${prompt}" --width=450 2>/dev/null
        return $?
    else
        read -r -p "${prompt} [y/N]: " response
        [[ "${response}" =~ ^[Yy]$ ]]
    fi
}

# ------------------------------------------------------------------------------
# Progress Reporting Engine
# ------------------------------------------------------------------------------

STEPS_TOTAL=7
CURRENT_STEP=0

declare -a STEP_STATUS=(
    "Pending"
    "Pending"
    "Pending"
    "Pending"
    "Pending"
    "Pending"
    "Pending"
)

declare -a STEP_LABELS=(
    "SteamOS Environment & Permissions"
    "User-Space Node.js & npm (No-Root)"
    "Hermes Agent Core Engine"
    "Claude Code CLI & Authentication"
    "Claude DirectSDK Plugin"
    "OpenAI Codex OAuth Setup"
    "End-to-End Verification & Health Check"
)

render_terminal_dashboard() {
    clear
    echo -e "${BOLD}${CYAN}====================================================================${NC}"
    echo -e "${BOLD}         ${APP_TITLE} v${VERSION}${NC}"
    echo -e "${BOLD}${CYAN}====================================================================${NC}"
    echo -e " Log: ${LOG_FILE}"
    echo -e " Mode: SteamOS Desktop (Immutable Rootfs Safe)"
    echo -e "--------------------------------------------------------------------"
    for i in "${!STEP_LABELS[@]}"; do
        local num=$((i + 1))
        local status="${STEP_STATUS[$i]}"
        local label="${STEP_LABELS[$i]}"
        case "${status}" in
            "Success")
                echo -e "  [${GREEN}✓${NC}] Step ${num}: ${label}"
                ;;
            "Running")
                echo -e "  [${YELLOW}⟳${NC}] Step ${num}: ${label} ${YELLOW}(In progress...)${NC}"
                ;;
            "Failed")
                echo -e "  [${RED}✗${NC}] Step ${num}: ${label} ${RED}(Failed)${NC}"
                ;;
            "Skipped")
                echo -e "  [${CYAN}-${NC}] Step ${num}: ${label} (Skipped)"
                ;;
            *)
                echo -e "  [ ] Step ${num}: ${label}"
                ;;
        esac
    done
    echo -e "${BOLD}${CYAN}====================================================================${NC}\n"
}

update_step() {
    local step_idx="$1"
    local status="$2"
    STEP_STATUS[$step_idx]="${status}"
    render_terminal_dashboard
}

# ------------------------------------------------------------------------------
# Step Implementations
# ------------------------------------------------------------------------------

# Step 1: Environment & Directories
step1_env_check() {
    update_step 0 "Running"
    echo "Checking directories and environment..." >> "${LOG_FILE}"

    mkdir -p "${HOME}/.local/bin"
    mkdir -p "${HOME}/.local/share"
    mkdir -p "${HOME}/.npm-global/bin"
    mkdir -p "${HOME}/.hermes"

    # Configure npm to use user prefix so sudo/pacman is never needed
    npm config set prefix "${HOME}/.npm-global" >/dev/null 2>&1 || true

    sleep 1
    update_step 0 "Success"
}

# Step 2: User-Space Node.js LTS (rootless fallback for SteamOS)
step2_install_node() {
    update_step 1 "Running"
    echo "Verifying Node.js and npm..." >> "${LOG_FILE}"

    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        local node_ver
        node_ver=$(node --version)
        echo "Found system Node.js: ${node_ver}" >> "${LOG_FILE}"
        update_step 1 "Success"
        return 0
    fi

    echo "Node.js not found. Installing standalone user-space Node.js LTS..." >> "${LOG_FILE}"
    local NODE_VERSION="v20.18.0"
    local ARCH="linux-x64"
    local NODE_DIR="${HOME}/.local/lib/nodejs"
    mkdir -p "${NODE_DIR}"

    local TAR_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-${ARCH}.tar.xz"
    local TMP_TAR="/tmp/node-lts.tar.xz"

    if ! curl -fsSL "${TAR_URL}" -o "${TMP_TAR}"; then
        update_step 1 "Failed"
        msg_error "Node.js Download Failed" "Could not download Node.js LTS archive from official nodejs.org."
        return 1
    fi

    tar -xJf "${TMP_TAR}" -C "${NODE_DIR}" --strip-components=1
    rm -f "${TMP_TAR}"

    export PATH="${NODE_DIR}/bin:${PATH}"

    if command -v node >/dev/null 2>&1; then
        echo "Installed user-space Node $(node --version)" >> "${LOG_FILE}"
        update_step 1 "Success"
        return 0
    else
        update_step 1 "Failed"
        msg_error "Node.js Setup Error" "Extracted Node.js but failed to execute."
        return 1
    fi
}

# Step 3: Hermes Agent Core
step3_install_hermes() {
    update_step 2 "Running"
    echo "Checking Hermes Agent installation..." >> "${LOG_FILE}"

    if command -v hermes >/dev/null 2>&1; then
        echo "Hermes already installed: $(hermes --version 2>/dev/null || echo 'detected')" >> "${LOG_FILE}"
        update_step 2 "Success"
        return 0
    fi

    echo "Installing Hermes Agent via official installer..." >> "${LOG_FILE}"
    if curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash; then
        export PATH="${HOME}/.local/bin:${PATH}"
        if command -v hermes >/dev/null 2>&1; then
            update_step 2 "Success"
            return 0
        fi
    fi

    update_step 2 "Failed"
    msg_error "Hermes Install Error" "Official Hermes Agent install script failed. See log."
    return 1
}

# Step 4: Claude Code CLI & Login
step4_setup_claude() {
    update_step 3 "Running"
    echo "Installing/verifying Claude Code CLI..." >> "${LOG_FILE}"

    if ! command -v claude >/dev/null 2>&1; then
        echo "Running: npm install -g @anthropic-ai/claude-code" >> "${LOG_FILE}"
        if ! npm install -g @anthropic-ai/claude-code; then
            update_step 3 "Failed"
            msg_error "Claude CLI Install Failed" "npm failed to install @anthropic-ai/claude-code."
            return 1
        fi
    fi

    # Check login status
    echo "Checking Claude CLI login status..." >> "${LOG_FILE}"
    local is_logged_in=false
    if claude auth status 2>/dev/null | grep -q '"loggedIn": true'; then
        is_logged_in=true
    fi

    if [[ "${is_logged_in}" == "true" ]]; then
        echo "Claude CLI is already authenticated with Pro/Max." >> "${LOG_FILE}"
    else
        echo "Authentication required for Claude Code CLI." >> "${LOG_FILE}"
        echo -e "\n${YELLOW}=== Action Required: Claude Authentication ===${NC}"
        echo -e "A browser window will open or URL will be displayed to authenticate your Claude Pro/Max account."
        claude auth login
    fi

    update_step 3 "Success"
    return 0
}

# Step 5: Claude DirectSDK Hermes Plugin
step5_install_directsdk() {
    update_step 4 "Running"
    echo "Installing claude-subscription-directsdk plugin in Hermes..." >> "${LOG_FILE}"

    if hermes plugins list --plain 2>/dev/null | grep -q "claude-subscription-directsdk"; then
        echo "Plugin already installed. Ensuring enabled..." >> "${LOG_FILE}"
        hermes plugins enable claude-subscription-directsdk-experimental >/dev/null 2>&1 || true
    else
        if ! hermes plugins install --yes-deps --enable claude-subscription-directsdk; then
            update_step 4 "Failed"
            msg_error "Plugin Install Failed" "hermes plugins install claude-subscription-directsdk failed."
            return 1
        fi
    fi

    # Configure Hermes default model and provider
    hermes config set model.provider claude-subscription-directsdk-experimental
    hermes config unset model.base_url >/dev/null 2>&1 || true
    hermes config set model.default sonnet

    update_step 4 "Success"
    return 0
}

# Step 6: OpenAI Codex OAuth Setup
step6_setup_codex() {
    update_step 5 "Running"
    echo "Setting up OpenAI Codex OAuth..." >> "${LOG_FILE}"

    if hermes auth list 2>/dev/null | grep -q "openai-codex"; then
        echo "OpenAI Codex credentials already present in Hermes pool." >> "${LOG_FILE}"
        update_step 5 "Success"
        return 0
    fi

    echo -e "\n${YELLOW}=== Action Required: OpenAI Codex OAuth Pairing ===${NC}"
    echo -e "Starting OAuth pairing for OpenAI Codex..."
    
    # Run interactive device flow
    if hermes auth add openai-codex; then
        echo "Codex OAuth pairing successfully completed." >> "${LOG_FILE}"
        update_step 5 "Success"
        return 0
    else
        update_step 5 "Failed"
        msg_error "Codex Auth Failed" "OpenAI Codex authorization was cancelled or failed."
        return 1
    fi
}

# Step 7: End-to-End Verification
step7_verify() {
    update_step 6 "Running"
    echo "Running live end-to-end verification tests..." >> "${LOG_FILE}"

    echo -e "Testing Claude DirectSDK..."
    local claude_ok=false
    if hermes chat -q "Respond with 'Claude OK' and nothing else." 2>&1 | grep -iq "Claude OK"; then
        claude_ok=true
        echo "Claude DirectSDK test: PASSED" >> "${LOG_FILE}"
    else
        echo "Claude DirectSDK test: FAILED" >> "${LOG_FILE}"
    fi

    echo -e "Testing OpenAI Codex OAuth..."
    local codex_ok=false
    if hermes chat --provider openai-codex -q "Respond with 'Codex OK' and nothing else." 2>&1 | grep -iq "Codex OK"; then
        codex_ok=true
        echo "OpenAI Codex OAuth test: PASSED" >> "${LOG_FILE}"
    else
        echo "OpenAI Codex OAuth test: FAILED" >> "${LOG_FILE}"
    fi

    if [[ "${claude_ok}" == "true" && "${codex_ok}" == "true" ]]; then
        update_step 6 "Success"
        msg_success "All tests passed! Hermes Agent is fully configured with Claude Pro DirectSDK and OpenAI Codex OAuth."
        return 0
    elif [[ "${claude_ok}" == "true" ]]; then
        update_step 6 "Success"
        msg_info "Claude DirectSDK is verified! Codex verification encountered an issue (check log)."
        return 0
    else
        update_step 6 "Failed"
        msg_error "Verification Test Failed" "One or more provider verification tests failed. See ${LOG_FILE}"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Full Automation Pipeline
# ------------------------------------------------------------------------------

run_full_installer() {
    render_terminal_dashboard
    step1_env_check || return 1
    step2_install_node || return 1
    step3_install_hermes || return 1
    step4_setup_claude || return 1
    step5_install_directsdk || return 1
    step6_setup_codex || return 1
    step7_verify || return 1
}

# ------------------------------------------------------------------------------
# Main Menu
# ------------------------------------------------------------------------------

show_gui_menu() {
    if [[ "${UI_BACKEND}" == "kdialog" ]]; then
        kdialog --title "${APP_TITLE}" --menu "Select an operation for your Steam Deck:" \
            "1" "Full Automated Setup (Hermes + Claude + Codex)" \
            "2" "Setup Claude DirectSDK Only" \
            "3" "Setup OpenAI Codex OAuth Only" \
            "4" "Run Verification & Diagnostics" \
            "5" "Launch Hermes Agent in Konsole" \
            "6" "View Installer Log" \
            "7" "Exit" 2>/dev/null
    elif [[ "${UI_BACKEND}" == "zenity" ]]; then
        zenity --list --title="${APP_TITLE}" --text="Select an operation for your Steam Deck:" \
            --column="Option" --column="Description" --width=500 --height=320 \
            "1" "Full Automated Setup (Hermes + Claude + Codex)" \
            "2" "Setup Claude DirectSDK Only" \
            "3" "Setup OpenAI Codex OAuth Only" \
            "4" "Run Verification & Diagnostics" \
            "5" "Launch Hermes Agent in Konsole" \
            "6" "View Installer Log" \
            "7" "Exit" 2>/dev/null
    fi
}

main_menu() {
    while true; do
        local choice=""
        if [[ "${UI_BACKEND}" != "terminal" ]]; then
            choice=$(show_gui_menu)
            if [[ -z "${choice}" ]]; then
                exit 0
            fi
        else
            clear
            echo -e "${BOLD}${CYAN}====================================================================${NC}"
            echo -e "${BOLD}         ${APP_TITLE} (Steam Deck Edition)${NC}"
            echo -e "${BOLD}${CYAN}====================================================================${NC}"
            echo -e "  ${BOLD}1)${NC} Full Automated Setup (Hermes + Claude DirectSDK + Codex)"
            echo -e "  ${BOLD}2)${NC} Setup Claude DirectSDK Only"
            echo -e "  ${BOLD}3)${NC} Setup OpenAI Codex OAuth Only"
            echo -e "  ${BOLD}4)${NC} Run Provider Verification & Health Check"
            echo -e "  ${BOLD}5)${NC} Launch Hermes Agent"
            echo -e "  ${BOLD}6)${NC} View Installer Log"
            echo -e "  ${BOLD}7)${NC} Exit"
            echo -e "--------------------------------------------------------------------"
            read -r -p "Enter selection [1-7]: " choice
        fi

        case "${choice}" in
            1)
                run_full_installer
                read -r -p "Press Enter to return to menu..."
                ;;
            2)
                step1_env_check
                step2_install_node
                step3_install_hermes
                step4_setup_claude
                step5_install_directsdk
                read -r -p "Press Enter to return to menu..."
                ;;
            3)
                step1_env_check
                step3_install_hermes
                step6_setup_codex
                read -r -p "Press Enter to return to menu..."
                ;;
            4)
                step7_verify
                read -r -p "Press Enter to return to menu..."
                ;;
            5)
                if command -v konsole >/dev/null 2>&1; then
                    konsole -e bash -c "hermes; bash" &
                else
                    hermes
                fi
                ;;
            6)
                if command -v kwrite >/dev/null 2>&1; then
                    kwrite "${LOG_FILE}" &
                elif command -v kate >/dev/null 2>&1; then
                    kate "${LOG_FILE}" &
                else
                    less "${LOG_FILE}"
                fi
                ;;
            7)
                echo "Exiting."
                exit 0
                ;;
            *)
                echo "Invalid selection."
                sleep 1
                ;;
        esac
    done
}

main_menu
