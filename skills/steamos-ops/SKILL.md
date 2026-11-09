---
name: steamos-ops
description: SteamOS and Steam Deck gaming operations suite. Clean orphaned Proton compatdata prefixes, query ProtonDB compatibility and recommended launch options, back up game saves across Wine prefixes and emulators, and monitor battery/thermal telemetry.
---

# SteamOS Operations Skill

Equips Hermes with native commands to maintain, troubleshoot, and optimize games and system health on Steam Deck running SteamOS.

## Capabilities

1. **`clean_compatdata(dry_run=True)`**: Scans `~/.local/share/Steam/steamapps/compatdata` for orphaned Proton prefixes from uninstalled games and calculates reclaimable space. Set `dry_run=False` to prune them and free disk space.
2. **`lookup_protondb(game_query)`**: Searches ProtonDB for community rating tiers (Platinum, Gold, Silver, Bronze, Borked), recommended Proton versions (GE-Proton), and suggested launch option flags for any game title or Steam AppID.
3. **`backup_game_saves(destination_dir=None)`**: Discovers save data across all active Proton prefixes and major emulators (Yuzu, Ryujinx, RPCS3, RetroArch) and zips them into a timestamped archive.
4. **`deck_power_telemetry()`**: Probes hardware power supplies to return battery charge %, charging/discharging state, live wattage draw, remaining battery life in minutes/hours, battery health %, and APU thermal metrics.

## Example Queries

- "Check my Steam Deck battery health and how much time I have left"
- "Look up ProtonDB fixes for Cyberpunk 2077"
- "How much disk space can I reclaim by cleaning orphaned Proton prefixes?"
- "Back up all my game saves and emulator data"
