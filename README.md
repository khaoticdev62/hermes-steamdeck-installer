# Hermes Agent Steam Deck Ultimate Edition (v2.1.0)

[![Release](https://img.shields.io/github/v/release/khaoticdev62/hermes-steamdeck-installer?color=blue)](https://github.com/khaoticdev62/hermes-steamdeck-installer/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

An automated, modular management hub and suite that transforms [Hermes Agent](https://github.com/NousResearch/hermes-agent) into a first-class **handheld AI gaming companion and autonomous developer studio** for **SteamOS 3.x (Steam Deck)**.

Designed specifically for SteamOS's immutable ostree rootfs: everything installs rootless into `/home/deck`, requiring **no `sudo`** and completely surviving SteamOS system updates.

---

## 🌟 Capabilities & Features

### 🎮 Handheld Gaming Companion
* **Steam Gaming Mode Integration:** Injects Hermes into Steam's Non-Game library (`shortcuts.vdf`) with custom high-res Grid, Hero, Logo, and Poster art.
* **Decky Loader QAM Plugin (`hermes-decky`):** Access Hermes from the Quick Access Menu (`...` button) over running games without pausing or minimizing.
* **Adaptive Dual-Tier Offline AI:** Game-aware Vulkan `llama.cpp` local daemon:
  - **In-Game Tier:** Automatically drops to **Qwen 2.5 Coder 3B** (~2GB RAM footprint) when a 3D game is active to eliminate memory contention or OOM stuttering.
  - **Desktop / Idle Tier:** Scales up to **Qwen 2.5 7B** when idle or in Desktop Mode for deep reasoning and code generation.
* **Hybrid Voice Assistant:** Hands-free paddle chord push-to-talk (L4/R4) using local **Faster-Whisper** and **Piper Neural TTS** with zero cloud latency.
* **SteamOS Ops Toolkit Skill (`steamos-ops`):**
  - Clean orphaned Proton compatdata prefixes to reclaim gigabytes of storage.
  - Look up ProtonDB compatibility ratings, GE-Proton recommendations, and community launch options.
  - Discover and backup game saves across all Wine prefixes and emulators (Yuzu, Ryujinx, RPCS3, RetroArch).
  - Real-time battery discharge wattage, health percentage, and thermal monitoring.

### 🛠️ Autonomous Developer Studio Suite (New in v2.1.0)
* **Distrobox & Podman Arch Dev Containers:** Home-persisted Arch Linux container with full `pacman -S gcc clang rustup go cmake make` access that survives SteamOS updates without touching `steamos-readonly`.
* **Dual-Mode Web IDE & SSH:**
  - Lightweight browser-based **code-server** (VS Code in the browser) running on port `8443` as a systemd user service.
  - Zero-configuration SSH remote pairing toggle (`hermes-ssh-toggle`) to develop directly on your Steam Deck from a laptop (`ssh deck@steamdeck.local`).
* **Godot 4 Game Studio Agent (`godot-agent`):**
  - Installs standalone Godot 4.3 engine.
  - Scaffolds 2D/3D projects pre-configured with Steam Deck's 1280x800 resolution and gamepad input mappings (twin sticks, buttons, paddles).
  - Headless test execution to catch script syntax and runtime errors autonomously.
* **Decky Plugin Builder (`decky-builder`):** Scaffolds complete React/TypeScript frontend + Python backend Decky plugins, deploys them into `~/homebrew/plugins/`, and live-debugs logs.
* **Container & Full-Stack Tooling (`container-ops`):** Build Dockerfiles and launch `podman-compose` multi-container stacks rootlessly.

---

## Quick Install on Steam Deck

Switch your Steam Deck to **Desktop Mode** (*Steam Button > Power > Switch to Desktop*), open **Konsole**, and run:

```bash
curl -fsSL https://raw.githubusercontent.com/khaoticdev62/hermes-steamdeck-installer/main/install-hermes-steamdeck.sh | bash
```

Or extract the pre-packaged executable release tarball:

```bash
curl -fsSL -O https://github.com/khaoticdev62/hermes-steamdeck-installer/releases/latest/download/hermes-steamdeck.tar.gz
tar -xzf hermes-steamdeck.tar.gz
./install-hermes-steamdeck.sh
```

---

## Interactive Modular Menu

Running `./install-hermes-steamdeck.sh` presents the interactive management hub:

```text
====================================================================
   Hermes Agent - Steam Deck Developer & Gaming Suite (v2.1.0)
====================================================================
  1) 🌟 Full Ultimate Setup (Installs both Gaming + Dev Studio Suites)
  2) Core Engine (Hermes + Claude DirectSDK + Codex OAuth)
  3) 🛠️ Developer Studio Suite (code-server, Godot 4, Distrobox, Dev Skills)
  4) Steam Gaming Mode & Grid Art Injection
  5) Decky Loader QAM Plugin Deployment
  6) Offline Adaptive Local AI (Vulkan llama.cpp + Dual GGUF)
  7) Hybrid Voice Assistant (Faster-Whisper + Piper TTS)
  8) SteamOS Ops Toolkit Skill (ProtonDB, Compatdata, Saves)
  9) Run Full Health & Diagnostics Check
  10) Check for Updates from GitHub
  11) Launch Hermes Agent
  12) Exit
====================================================================
```

---

## Desktop Shortcut Setup

To place a clickable shortcut on your SteamOS Desktop:
```bash
mv Hermes-Setup.desktop ~/Desktop/
gio set ~/Desktop/Hermes-Setup.desktop metadata::trusted true
```
Double-click **"Hermes Agent Setup"** anytime to open the management hub.
