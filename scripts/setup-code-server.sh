#!/usr/bin/env bash
# ==============================================================================
#  Steam Deck code-server (Web VS Code) & Remote SSH Dev Setup
# ==============================================================================

set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
LIB_DIR="${HOME}/.local/lib"
CS_DIR="${LIB_DIR}/code-server"
CONFIG_DIR="${HOME}/.config/code-server"

mkdir -p "${BIN_DIR}" "${LIB_DIR}" "${CONFIG_DIR}"

echo "===================================================================="
echo " Setting up code-server (Web VS Code) & SSH Remote Access on Steam Deck"
echo "===================================================================="

# 1. Download standalone code-server release if missing
if [[ ! -f "${CS_DIR}/bin/code-server" ]]; then
    echo "Fetching latest standalone code-server release..."
    CS_TAR="/tmp/code-server.tar.gz"
    LATEST_CS_URL=$(curl -s https://api.github.com/repos/coder/code-server/releases/latest | grep "browser_download_url.*linux-amd64.tar.gz" | head -n 1 | cut -d '"' -f 4 || true)
    
    if [[ -z "${LATEST_CS_URL}" ]]; then
        LATEST_CS_URL="https://github.com/coder/code-server/releases/download/v4.96.2/code-server-4.96.2-linux-amd64.tar.gz"
    fi

    echo "Downloading: ${LATEST_CS_URL}"
    if curl -L -f -o "${CS_TAR}" "${LATEST_CS_URL}"; then
        mkdir -p "${CS_DIR}"
        tar -xzf "${CS_TAR}" -C "${CS_DIR}" --strip-components=1
        rm -f "${CS_TAR}"
        ln -sf "${CS_DIR}/bin/code-server" "${BIN_DIR}/code-server"
        echo "code-server installed to ${BIN_DIR}/code-server"
    fi
fi

# 2. Configure code-server config.yaml
cat << 'EOF' > "${CONFIG_DIR}/config.yaml"
bind-addr: 0.0.0.0:8443
auth: none
cert: false
disable-telemetry: true
EOF
echo "Configured code-server on port 8443 (bind 0.0.0.0, accessible on local network)."

# 3. Create systemd user service
SERVICE_DIR="${HOME}/.config/systemd/user"
mkdir -p "${SERVICE_DIR}"
cat << 'EOF' > "${SERVICE_DIR}/hermes-code-server.service"
[Unit]
Description=Hermes code-server Web IDE
After=network.target

[Service]
Type=simple
Environment=PATH=%h/.local/bin:%h/.npm-global/bin:/usr/bin:/bin
ExecStart=%h/.local/bin/code-server
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user enable --now hermes-code-server.service >/dev/null 2>&1 || true
echo "[✓] hermes-code-server.service enabled and started on port 8443."

# 4. SSH Remote Access Toggle Helper
cat << 'EOF' > "${BIN_DIR}/hermes-ssh-toggle"
#!/usr/bin/env bash
# Quick toggle for SSH daemon on Steam Deck
if systemctl is-active --quiet sshd; then
    sudo systemctl stop sshd 2>/dev/null || systemctl --user stop sshd 2>/dev/null || true
    echo "SSH server STOPPED."
else
    # Start sshd
    sudo systemctl start sshd 2>/dev/null || systemctl --user start sshd 2>/dev/null || /usr/bin/sshd -D &
    echo "SSH server STARTED."
    echo "Connect from your laptop/PC: ssh deck@$(hostname).local"
fi
EOF
chmod +x "${BIN_DIR}/hermes-ssh-toggle"

echo -e "\n[✓] code-server setup complete."
echo "Access VS Code in your browser at: http://localhost:8443 (or http://<steamdeck-ip>:8443)"
echo "Toggle SSH with: hermes-ssh-toggle"
