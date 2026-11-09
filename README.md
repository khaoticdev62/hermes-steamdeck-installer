# Hermes Agent Steam Deck Ultimate Edition (v2.0.0)

[![Release](https://img.shields.io/github/v/release/khaoticdev62/hermes-steamdeck-installer?color=blue)](https://github.com/khaoticdev62/hermes-steamdeck-installer/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

An automated, modular management hub and suite that transforms [Hermes Agent](https://github.com/NousResearch/hermes-agent) into a first-class handheld AI companion for **SteamOS 3.x (Steam Deck)**.

Designed specifically for SteamOS's read-only ostree rootfs: everything installs rootless into `/home/deck`, requiring **no `sudo`** and completely surviving SteamOS system updates.

---

## 🌟 What's New in Ultimate Edition v2.0

1. **🎮 Steam Gaming Mode Integration:** Automatically injects Hermes Agent into Steam's `shortcuts.vdf` with custom high-res Grid, Hero, Logo, and Poster art.
2. **🔌 Decky Loader QAM Plugin:** Access Hermes directly from the Quick Access Menu (`...` button) over active gameplay.
3. **⚡ Adaptive Dual-Tier Offline AI:** Game-aware Vulkan `llama.cpp` local daemon:
   - **In-Game Tier:** Automatically drops to **Qwen 2.5 Coder 3B** (~2GB RAM footprint) when a 3D game is active to eliminate memory contention or OOM stuttering.
   - **Desktop / Idle Tier:** Scales up to **Qwen 2.5 7B** when idle or in Desktop Mode for deep reasoning and code generation.
4. **🎙️ Hybrid Voice Assistant:** Hands-free paddle chord push-to-talk (L4/R4) using local **Faster-Whisper** and **Piper Neural TTS** with zero cloud latency.
5. **🛠️ SteamOS Ops Toolkit Skill:** Equips Hermes with native tools:
   - Clean orphaned Proton compatdata prefixes to reclaim gigabytes of storage.
   - Look up ProtonDB compatibility ratings, GE-Proton recommendations, and community launch options.
   - Discover and backup game saves across all Wine prefixes and emulators (Yuzu, Ryujinx, RPCS3, RetroArch).
   - Real-time battery discharge wattage, health percentage, and thermal monitoring.
6. **🔄 Auto-Updater:** The installer automatically detects new GitHub releases and can update itself in-place.

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
   Hermes Agent - Steam Deck Ultimate Edition (v2.0.0)
====================================================================
  1) 🌟 Full Ultimate Setup (Installs all 6 enhancement modules)
  2) Core Engine (Hermes + Claude DirectSDK + Codex OAuth)
  3) Steam Gaming Mode & Grid Art Injection
  4) Decky Loader QAM Plugin Deployment
  5) Offline Adaptive Local AI (Vulkan llama.cpp + Dual GGUF)
  6) Hybrid Voice Assistant (Faster-Whisper + Piper TTS)
  7) SteamOS Ops Toolkit Skill (ProtonDB, Compatdata, Saves)
  8) Run Full Health & Diagnostics Check
  9) Check for Updates from GitHub
  10) Launch Hermes Agent
  11) Exit
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
