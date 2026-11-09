# Hermes Agent Steam Deck Automated Installer

Automated, single-script installer designed specifically for **SteamOS 3.x (Steam Deck)**. It automates:

1. **System & Environment Check:** Non-root, user-space paths (`~/.local/bin`, `~/.npm-global/bin`) that survive SteamOS system updates.
2. **Node.js & npm (Rootless):** Automatic user-space Node.js LTS fallback if missing (never touches the read-only rootfs).
3. **Hermes Agent Engine:** Official Hermes installation and initialization.
4. **Claude Code CLI & Authentication:** Installs `@anthropic-ai/claude-code`, verifies Claude Pro/Max login status, and launches sign-in when needed.
5. **Claude Subscription DirectSDK Plugin:** Installs and enables `claude-subscription-directsdk-experimental`, sets model default to `sonnet`.
6. **OpenAI Codex OAuth:** Guides through the device-code OAuth flow for ChatGPT/Codex subscription pairing.
7. **End-to-End Health Checks:** Performs automated test turns against both Claude and Codex to guarantee operational readiness.

---

## Quick Install on Steam Deck

Switch your Steam Deck to **Desktop Mode** (*Steam Button > Power > Switch to Desktop*), open **Konsole**, and run:

```bash
curl -fsSL https://raw.githubusercontent.com/khaoticdev62/hermes-steamdeck-installer/main/install-hermes-steamdeck.sh | bash
```

Or download and extract the pre-built release package:

```bash
curl -fsSL -O https://github.com/khaoticdev62/hermes-steamdeck-installer/releases/latest/download/hermes-steamdeck.tar.gz
tar -xzf hermes-steamdeck.tar.gz
./install-hermes-steamdeck.sh
```

---

## Desktop Shortcut Setup

To place a clickable shortcut directly onto your SteamOS Desktop:
```bash
mv Hermes-Setup.desktop ~/Desktop/
gio set ~/Desktop/Hermes-Setup.desktop metadata::trusted true
```
Now you can double-click **"Hermes Agent Setup"** directly on your Steam Deck desktop.

---

## Features
- **Interactive UI:** Automatically uses native KDE Plasma GUI dialogs (`kdialog`) or `zenity`, falling back to an ANSI terminal menu in Konsole.
- **Progress Dashboard:** Shows step-by-step progress `[✓]`, `[⟳]`, `[✗]` for all 7 stages.
- **Fail-Safe & Logging:** All output is mirrored to `~/.local/share/hermes-installer/installer.log`. Any error is caught with clean diagnostic dialogs.
- **Menu Options:** Full installer, standalone setup for Claude or Codex, diagnostic verification runner, and one-click Hermes launcher.
