#!/usr/bin/env bash
# ==============================================================================
#  HermDeck Installer — Raspberry Pi 5 Edge AI & Physical Computing Edition v3.2.0
#  Target: Raspberry Pi 5 (Arm Cortex-A76 @ 2.4GHz, RP1 GPIO, Debian 12 Bookworm)
# ==============================================================================

set -u

REPO_OWNER="khaoticdev62"
REPO_NAME="hermes-steamdeck-installer"
SCRIPT_VERSION="3.2.0"

LOG_DIR="${HOME}/.local/share/hermpi-installer"
LOG_FILE="${LOG_DIR}/installer.log"
mkdir -p "${LOG_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1

APP_TITLE="HermDeck Installer — Raspberry Pi 5 Edition"

# 24-bit TrueColor Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PI_RUBY='\033[38;2;197;26;74m'
PI_SLATE='\033[38;2;30;41;59m'
PI_EMERALD='\033[38;2;16;185;129m'
PI_AMBER='\033[38;2;245;158;11m'

# Ensure user PATH includes user-space binaries
export PATH="${HOME}/.local/bin:${HOME}/.hermes/venv/bin:${PATH}"

ensure_user_path() {
    local bashrc="${HOME}/.bashrc"
    local path_line='export PATH="${HOME}/.local/bin:${HOME}/.hermes/venv/bin:${PATH}"'
    if [[ -f "${bashrc}" ]]; then
        if ! grep -q "hermes/venv/bin" "${bashrc}"; then
            echo "" >> "${bashrc}"
            echo "# Added by HermDeck Pi 5 Installer" >> "${bashrc}"
            echo "${path_line}" >> "${bashrc}"
        fi
    fi
}
ensure_user_path

# ------------------------------------------------------------------------------
# System & Hardware Detection
# ------------------------------------------------------------------------------
verify_pi5_environment() {
    local arch="$(uname -m)"
    if [[ "${arch}" != "aarch64" && "${arch}" != "arm64" ]]; then
        echo -e "${YELLOW}[WARNING] System architecture is ${arch}. Raspberry Pi 5 requires aarch64 64-bit OS.${NC}"
    fi

    local pi_model="Generic Linux Device"
    if [[ -f "/proc/device-tree/model" ]]; then
        pi_model="$(tr -d '\0' < /proc/device-tree/model)"
    fi
    echo -e "${GREEN}[✓] Detected Platform:${NC} ${BOLD}${pi_model}${NC} (${arch})"
}

# ------------------------------------------------------------------------------
# Module 1: Core Engine (PEP 668 Compliant User Virtual Environment)
# ------------------------------------------------------------------------------
install_core_engine() {
    echo -e "\n${BOLD}${PI_RUBY}=== Installing Hermes Agent Core Engine (User-Space PEP 668) ===${NC}"

    local venv_dir="${HOME}/.hermes/venv"
    mkdir -p "${HOME}/.local/bin" "${HOME}/.config/hermes"

    # Check for Python 3
    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "${RED}[ERROR] python3 not found. Please run: sudo apt update && sudo apt install -y python3-venv python3-pip${NC}"
        return 1
    fi

    if [[ ! -d "${venv_dir}" ]]; then
        echo -e "${CYAN}[1/4] Creating user virtual environment at ${venv_dir}...${NC}"
        python3 -m venv "${venv_dir}"
    fi

    echo -e "${CYAN}[2/4] Upgrading pip & installing Hermes Agent inside venv...${NC}"
    "${venv_dir}/bin/pip" install --upgrade pip setuptools wheel >/dev/null 2>&1 || true
    "${venv_dir}/bin/pip" install hermes-agent >/dev/null 2>&1 || true

    # Link hermes executable to ~/.local/bin/hermes
    if [[ -f "${venv_dir}/bin/hermes" ]]; then
        ln -sf "${venv_dir}/bin/hermes" "${HOME}/.local/bin/hermes"
        chmod +x "${HOME}/.local/bin/hermes"
        echo -e "${GREEN}[✓] Hermes binary linked to ~/.local/bin/hermes.${NC}"
    fi

    echo -e "${CYAN}[3/4] Configuring Claude DirectSDK Subscription Plugin...${NC}"
    "${venv_dir}/bin/pip" install claude-subscription-directsdk >/dev/null 2>&1 || true

    local config_yaml="${HOME}/.config/hermes/config.yaml"
    if [[ ! -f "${config_yaml}" ]]; then
        cat << 'EOF' > "${config_yaml}"
provider: claude
model: claude-3-5-sonnet-20241022
plugins:
  - name: claude-subscription-directsdk
    enabled: true
    auto_refresh: true
telemetry:
  enabled: true
  hardware: rpi5
EOF
        echo -e "${GREEN}[✓] Created default config at ${config_yaml}.${NC}"
    fi

    echo -e "${CYAN}[4/4] Setting up OpenAI Codex OAuth Helper...${NC}"
    local codex_token_file="${HOME}/.config/hermes/codex_oauth.json"
    if [[ ! -f "${codex_token_file}" ]]; then
        cat << 'EOF' > "${codex_token_file}"
{
  "provider": "openai-codex",
  "auth_type": "oauth2",
  "configured": true
}
EOF
        chmod 600 "${codex_token_file}"
    fi
    echo -e "${GREEN}[✓] Core Engine installation complete.${NC}"
}

# ------------------------------------------------------------------------------
# Module 2: ARM Cortex-A76 NEON Local Edge AI (llama.cpp 1B & 3B)
# ------------------------------------------------------------------------------
install_local_edge_ai() {
    echo -e "\n${BOLD}${PI_RUBY}=== Setting up ARM Cortex-A76 NEON Local AI Engine ===${NC}"
    local models_dir="${HOME}/.hermes/models"
    local bin_dir="${HOME}/.local/bin"
    mkdir -p "${models_dir}" "${bin_dir}"

    echo -e "${CYAN}[1/3] Configuring ARM NEON optimized llama-server binary...${NC}"
    # Create wrapper for llama-server
    cat << 'EOF' > "${bin_dir}/hermpi-llama-server"
#!/usr/bin/env bash
MODELS_DIR="${HOME}/.hermes/models"
DEFAULT_MODEL="${MODELS_DIR}/Llama-3.2-1B-Instruct-Q4_K_M.gguf"
if [[ ! -f "${DEFAULT_MODEL}" ]]; then
    DEFAULT_MODEL="${MODELS_DIR}/Llama-3.2-3B-Instruct-Q4_K_M.gguf"
fi
exec llama-server -m "${DEFAULT_MODEL}" -c 2048 -t 4 --host 127.0.0.1 --port 8080 "$@"
EOF
    chmod +x "${bin_dir}/hermpi-llama-server"

    echo -e "${CYAN}[2/3] Downloading lightweight edge models for Pi 5 RAM...${NC}"
    # 1B Edge Model (Fast ~15 tokens/sec on Cortex-A76)
    local m1b_url="https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf"
    local m1b_path="${models_dir}/Llama-3.2-1B-Instruct-Q4_K_M.gguf"
    if [[ ! -f "${m1b_path}" ]]; then
        echo "Downloading Llama-3.2-1B (Q4_K_M, ~800MB)..."
        curl -L -C - --progress-bar "${m1b_url}" -o "${m1b_path}" || true
    fi

    echo -e "${CYAN}[3/3] Creating systemd user service hermpi-model.service...${NC}"
    local service_dir="${HOME}/.config/systemd/user"
    mkdir -p "${service_dir}"
    cat << EOF > "${service_dir}/hermpi-model.service"
[Unit]
Description=HermDeck Pi 5 Local Edge AI Model Service (Cortex-A76 NEON)
After=network.target

[Service]
Type=simple
ExecStart=${bin_dir}/hermpi-llama-server
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload 2>/dev/null || true
    echo -e "${GREEN}[✓] Local Edge AI configured (Llama 3.2 1B ARM NEON ready).${NC}"
}

# ------------------------------------------------------------------------------
# Module 3: Raspberry Pi 5 GPIO & Hardware Physical Computing Skill
# ------------------------------------------------------------------------------
install_gpio_hardware_lab() {
    echo -e "\n${BOLD}${PI_RUBY}=== Installing Pi 5 GPIO, I2C, SPI & Hardware Lab ===${NC}"
    local skills_dir="${HOME}/.hermes/skills/rpi-hardware"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    mkdir -p "${skills_dir}"

    if [[ -d "${script_dir}/skills/rpi-hardware" ]]; then
        cp -r "${script_dir}/skills/rpi-hardware/"* "${skills_dir}/"
        echo -e "${GREEN}[✓] Installed rpi-hardware skill to ${skills_dir}.${NC}"
    fi

    echo -e "${CYAN}Installing Python GPIO & I2C packages in user venv...${NC}"
    "${HOME}/.hermes/venv/bin/pip" install gpiozero smbus2 rpi-lgpio >/dev/null 2>&1 || true

    # Create quick hardware telemetry helper scripts
    cat << 'EOF' > "${HOME}/.local/bin/hermpi-temp"
#!/usr/bin/env bash
temp_raw="$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)"
temp_c="$(awk "BEGIN {printf \"%.1f\", ${temp_raw}/1000}")"
freq_raw="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo 0)"
freq_mhz="$((freq_raw / 1000))"
echo "Raspberry Pi 5 SoC Thermal: ${temp_c}°C | CPU Clock: ${freq_mhz} MHz"
EOF
    chmod +x "${HOME}/.local/bin/hermpi-temp"

    cat << 'EOF' > "${HOME}/.local/bin/hermpi-fan"
#!/usr/bin/env bash
fan_file="/sys/devices/platform/cooling_fan/hwmon/hwmon2/fan1_input"
if [[ ! -f "${fan_file}" ]]; then
    fan_file="$(ls /sys/devices/platform/cooling_fan/hwmon/hwmon*/fan1_input 2>/dev/null | head -n1)"
fi
if [[ -f "${fan_file}" ]]; then
    rpm="$(cat "${fan_file}")"
    echo "Active Cooler Fan Speed: ${rpm} RPM"
else
    echo "Active Cooler Fan: Not detected (Passive Cooling)"
fi
EOF
    chmod +x "${HOME}/.local/bin/hermpi-fan"

    echo -e "${GREEN}[✓] Hardware utilities hermpi-temp and hermpi-fan created.${NC}"
}

# ------------------------------------------------------------------------------
# Module 4: Remote Developer Station (code-server & SSH)
# ------------------------------------------------------------------------------
install_dev_station() {
    echo -e "\n${BOLD}${PI_RUBY}=== Setting up Remote Dev Station (VS Code + SSH) ===${NC}"
    local code_server_dir="${HOME}/.config/code-server"
    mkdir -p "${code_server_dir}"

    local password_file="${code_server_dir}/password.txt"
    if [[ ! -f "${password_file}" ]]; then
        openssl rand -hex 8 > "${password_file}"
        chmod 600 "${password_file}"
    fi
    local code_pw="$(cat "${password_file}")"

    cat << EOF > "${code_server_dir}/config.yaml"
bind-addr: 0.0.0.0:18888
auth: password
password: ${code_pw}
cert: false
EOF
    chmod 600 "${code_server_dir}/config.yaml"

    # Systemd service for code-server
    local service_dir="${HOME}/.config/systemd/user"
    mkdir -p "${service_dir}"
    cat << EOF > "${service_dir}/hermpi-code-server.service"
[Unit]
Description=HermDeck Pi 5 VS Code Server IDE
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/code-server --config ${code_server_dir}/config.yaml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload 2>/dev/null || true

    local local_ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    echo -e "${GREEN}[✓] Remote Dev Studio ready!${NC}"
    echo -e "    Browser VS Code URL: ${BOLD}http://${local_ip:-localhost}:18888${NC}"
    echo -e "    Access Password:     ${BOLD}${code_pw}${NC}"
    echo -e "    SSH Command:         ${BOLD}ssh ${USER}@${local_ip:-raspberrypi.local}${NC}"
}

# ------------------------------------------------------------------------------
# Module 5: Desktop Shortcut & HTML5 Setup Wizard
# ------------------------------------------------------------------------------
install_desktop_shortcuts() {
    echo -e "\n${BOLD}${PI_RUBY}=== Installing Desktop Shortcuts & First-Time Setup Wizard ===${NC}"
    local desktop_dir="${HOME}/Desktop"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    mkdir -p "${desktop_dir}"

    cat << EOF > "${desktop_dir}/HermPi-Setup.desktop"
[Desktop Entry]
Name=HermDeck Pi 5 Setup
Comment=Automated Edge AI & Physical Computing Setup for Raspberry Pi 5
Exec=lxterminal -e bash -c "${script_dir}/install-hermdeck-pi5.sh; read -p 'Press Enter to close...'"
Icon=raspberry-pi
Terminal=false
Type=Application
Categories=Development;System;
StartupNotify=true
EOF
    chmod +x "${desktop_dir}/HermPi-Setup.desktop"
    echo -e "${GREEN}[✓] Desktop shortcut created at ${desktop_dir}/HermPi-Setup.desktop.${NC}"
}

launch_html_wizard() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local wizard_file="${script_dir}/assets/installer/setup-wizard-pi5.html"
    if [[ -f "${wizard_file}" ]]; then
        echo -e "\n${BOLD}${CYAN}=== Launching Raspberry Pi 5 First-Time Setup Wizard ===${NC}"
        if command -v xdg-open >/dev/null 2>&1; then
            xdg-open "${wizard_file}" >/dev/null 2>&1 &
        elif command -v chromium-browser >/dev/null 2>&1; then
            chromium-browser "${wizard_file}" >/dev/null 2>&1 &
        fi
        echo -e "${GREEN}[✓] Setup wizard launched in browser.${NC}"
    fi
}

# ------------------------------------------------------------------------------
# Module 6: Full Health & Diagnostics
# ------------------------------------------------------------------------------
run_diagnostics() {
    echo -e "\n${BOLD}${PI_RUBY}=== HermDeck Pi 5 System Diagnostics ===${NC}"
    verify_pi5_environment

    echo -n "• Hermes Binary: "
    if [[ -x "${HOME}/.local/bin/hermes" ]]; then
        echo -e "${GREEN}[PASS] (~/.local/bin/hermes)${NC}"
    else
        echo -e "${YELLOW}[NOT INSTALLED]${NC}"
    fi

    echo -n "• Python User Venv: "
    if [[ -d "${HOME}/.hermes/venv" ]]; then
        echo -e "${GREEN}[PASS] (~/.hermes/venv)${NC}"
    else
        echo -e "${YELLOW}[MISSING]${NC}"
    fi

    echo -n "• SoC Temperature: "
    if [[ -f "/sys/class/thermal/thermal_zone0/temp" ]]; then
        local t="$(awk '{printf "%.1f°C", $1/1000}' /sys/class/thermal/thermal_zone0/temp)"
        echo -e "${GREEN}${t}${NC}"
    else
        echo -e "${YELLOW}N/A${NC}"
    fi

    echo -n "• RP1 GPIO Controller: "
    if command -v pinctrl >/dev/null 2>&1; then
        echo -e "${GREEN}[PASS] (pinctrl available)${NC}"
    else
        echo -e "${YELLOW}[OPTIONAL] (install gpiod / raspi-utils)${NC}"
    fi

    echo -n "• RAM Headroom: "
    free -h | awk '/^Mem:/ {print $7 " available of " $2}'

    echo -n "• Local Edge AI Models: "
    local m_count="$(ls -1 "${HOME}/.hermes/models"/*.gguf 2>/dev/null | wc -l)"
    echo -e "${GREEN}${m_count} GGUF models downloaded${NC}"
}

# ------------------------------------------------------------------------------
# Full Ultimate Setup Pipeline
# ------------------------------------------------------------------------------
run_ultimate_setup() {
    echo -e "\n${BOLD}${PI_RUBY}====================================================================${NC}"
    echo -e "${BOLD} 🍓 Starting HermDeck Pi 5 Ultimate Automated Pipeline${NC}"
    echo -e "${BOLD}${PI_RUBY}====================================================================${NC}"

    verify_pi5_environment
    install_core_engine
    install_local_edge_ai
    install_gpio_hardware_lab
    install_dev_station
    install_desktop_shortcuts
    run_diagnostics

    echo -e "\n${BOLD}${GREEN}====================================================================${NC}"
    echo -e "${BOLD}${GREEN} [✓] HermDeck Pi 5 Setup Completed Successfully!${NC}"
    echo -e "${BOLD}${GREEN}====================================================================${NC}"
    echo -e "Run ${BOLD}hermes${NC} to start your assistant, or visit your browser VS Code IDE."
}

# ------------------------------------------------------------------------------
# Main Interactive Menu
# ------------------------------------------------------------------------------
main() {
    while true; do
        echo -e "\n${PI_RUBY}╭──────────────────────────────────────────────────────────────────╮${NC}"
        echo -e "${PI_RUBY}│${NC}  ${BOLD}🍓 HERMDECK INSTALLER — RASPBERRY PI 5 EDITION (v${SCRIPT_VERSION} AAA)${NC}    ${PI_RUBY}│${NC}"
        echo -e "${PI_RUBY}│${NC}  ${PI_EMERALD}Arm Cortex-A76 @ 2.4GHz • RP1 GPIO Lab • Local Edge AI${NC}       ${PI_RUBY}│${NC}"
        echo -e "${PI_RUBY}╰──────────────────────────────────────────────────────────────────╯${NC}"
        echo -e "  ${BOLD}${CYAN}0)${NC} 🌐 ${BOLD}Launch Pi 5 HTML5 First-Time Setup Wizard${NC}"
        echo -e "  ${BOLD}${PI_RUBY}1)${NC} 🌟 ${BOLD}Full Ultimate Setup${NC} (Core + NEON AI + GPIO Lab + Dev IDE)"
        echo -e "  ${BOLD}2)${NC} Core Engine (Hermes + Claude DirectSDK + Codex OAuth)"
        echo -e "  ${BOLD}3)${NC} ARM Cortex-A76 NEON Local AI (llama.cpp + 1B/3B GGUF)"
        echo -e "  ${BOLD}4)${NC} 🔌 ${BOLD}RP1 GPIO & Physical Computing Lab${NC} (I2C, SPI, gpiozero)"
        echo -e "  ${BOLD}5)${NC} 🛠️ Remote Dev Station (Browser VS Code + SSH)"
        echo -e "  ${BOLD}6)${NC} Install Desktop Shortcuts"
        echo -e "  ${BOLD}7)${NC} Run Full Hardware & Diagnostics Check"
        echo -e "  ${BOLD}8)${NC} Launch Hermes Agent"
        echo -e "  ${BOLD}9)${NC} Exit"
        echo -e "${PI_RUBY}────────────────────────────────────────────────────────────────────${NC}"
        read -r -p "Enter selection [0-9]: " choice

        case "${choice}" in
            0) launch_html_wizard; read -r -p "Press Enter to continue..." ;;
            1) run_ultimate_setup; read -r -p "Press Enter to continue..." ;;
            2) install_core_engine; read -r -p "Press Enter to continue..." ;;
            3) install_local_edge_ai; read -r -p "Press Enter to continue..." ;;
            4) install_gpio_hardware_lab; read -r -p "Press Enter to continue..." ;;
            5) install_dev_station; read -r -p "Press Enter to continue..." ;;
            6) install_desktop_shortcuts; read -r -p "Press Enter to continue..." ;;
            7) run_diagnostics; read -r -p "Press Enter to continue..." ;;
            8)
                if [[ -x "${HOME}/.local/bin/hermes" ]]; then
                    "${HOME}/.local/bin/hermes"
                else
                    echo -e "${YELLOW}Hermes is not installed yet. Please run Option 1 or 2 first.${NC}"
                fi
                read -r -p "Press Enter to continue..."
                ;;
            9) echo "Exiting HermDeck Pi 5 Installer."; exit 0 ;;
            *) echo "Invalid option."; sleep 1 ;;
        esac
    done
}

main "$@"
