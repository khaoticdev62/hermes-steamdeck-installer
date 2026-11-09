---
name: decky-builder
description: Autonomous Decky Loader plugin developer for SteamOS. Scaffolds complete React/TypeScript and Python plugins, deploys them to ~/homebrew/plugins/, and reads runtime logs to diagnose bugs.
---

# Decky Loader Plugin Builder Skill

Equips Hermes with autonomous capabilities to design, scaffold, build, and debug plugins for the Steam Deck's Decky Loader framework.

## Capabilities

1. **`scaffold_decky_plugin(plugin_name, description)`**: Generates boilerplate with UI components, TypeScript configuration, and Python daemon.
2. **`deploy_decky_plugin(plugin_path)`**: Installs the plugin into `~/homebrew/plugins/` and reloads the service.
3. **`tail_decky_logs(lines=40)`**: Reads recent entries from `/home/deck/homebrew/logs/decky.log` to troubleshoot errors.
