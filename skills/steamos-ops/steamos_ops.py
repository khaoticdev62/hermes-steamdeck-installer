"""SteamOS Ops Toolkit for Hermes Agent.

Provides native system and gaming management tools for the Steam Deck:
- Proton prefix & compatdata pruning
- ProtonDB compatibility & launch options lookup
- Game save discovery and backup across Proton prefixes and emulators
- Battery, thermal, and power telemetry
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import time
import zipfile
from pathlib import Path
from typing import Any, Dict, List, Optional
import urllib.request
import urllib.parse


STEAM_HOME = Path.home() / ".local" / "share" / "Steam"
COMPATDATA_DIR = STEAM_HOME / "steamapps" / "compatdata"
STEAMAPPS_DIR = STEAM_HOME / "steamapps"


def get_installed_app_ids() -> set[str]:
    """Return all currently installed Steam AppIDs by scanning appmanifest files."""
    installed = set()
    if not STEAMAPPS_DIR.is_dir():
        return installed

    for acf in STEAMAPPS_DIR.glob("appmanifest_*.acf"):
        match = re.search(r"appmanifest_(\d+)\.acf", acf.name)
        if match:
            installed.add(match.group(1))
    return installed


def clean_compatdata(dry_run: bool = True) -> Dict[str, Any]:
    """Scan compatdata directory and identify or remove orphaned Proton prefixes.

    Args:
        dry_run: If True (default), lists orphaned prefixes and reclaimable disk space without deleting.
    """
    if not COMPATDATA_DIR.is_dir():
        return {"status": "error", "message": f"Compatdata directory not found at {COMPATDATA_DIR}"}

    installed = get_installed_app_ids()
    orphans = []
    total_reclaimable_bytes = 0

    for item in COMPATDATA_DIR.iterdir():
        if item.is_dir() and item.name.isdigit():
            app_id = item.name
            if app_id not in installed:
                # Calculate size
                size = 0
                for root, _, files in os.walk(item):
                    for f in files:
                        try:
                            size += os.path.getsize(os.path.join(root, f))
                        except (OSError, FileNotFoundError):
                            pass
                orphans.append({
                    "app_id": app_id,
                    "path": str(item),
                    "size_mb": round(size / (1024 * 1024), 2)
                })
                total_reclaimable_bytes += size

    if not dry_run and orphans:
        deleted = []
        for orphan in orphans:
            try:
                shutil.rmtree(orphan["path"])
                deleted.append(orphan["app_id"])
            except Exception as e:
                orphan["error"] = str(e)
        return {
            "status": "success",
            "dry_run": False,
            "deleted_count": len(deleted),
            "reclaimed_mb": round(total_reclaimable_bytes / (1024 * 1024), 2),
            "orphans": orphans
        }

    return {
        "status": "success",
        "dry_run": True,
        "orphan_count": len(orphans),
        "reclaimable_mb": round(total_reclaimable_bytes / (1024 * 1024), 2),
        "orphans": orphans,
        "hint": "Run with dry_run=False to delete these orphaned prefixes."
    }


def lookup_protondb(game_query: str) -> Dict[str, Any]:
    """Search ProtonDB for community tier rating, recommended Proton version, and launch options.

    Args:
        game_query: Steam AppID (e.g. '1091500') or game title (e.g. 'Cyberpunk 2077').
    """
    app_id = game_query.strip()

    # If query is not numeric, query Steam Store API for AppID
    if not app_id.isdigit():
        search_url = f"https://store.steampowered.com/api/storesearch/?term={urllib.parse.quote(app_id)}&l=english&cc=US"
        try:
            req = urllib.request.Request(search_url, headers={"User-Agent": "Hermes-SteamDeck/1.0"})
            with urllib.request.urlopen(req, timeout=5) as response:
                data = json.loads(response.read().decode())
                items = data.get("items", [])
                if not items:
                    return {"status": "error", "message": f"No Steam game found matching '{game_query}'."}
                app_id = str(items[0]["id"])
                game_title = items[0]["name"]
        except Exception as e:
            return {"status": "error", "message": f"Failed to search Steam Store API: {e}"}
    else:
        game_title = f"Steam AppID {app_id}"

    # Query ProtonDB summary
    pdb_url = f"https://www.protondb.com/api/v1/reports/summaries/{app_id}.json"
    try:
        req = urllib.request.Request(pdb_url, headers={"User-Agent": "Hermes-SteamDeck/1.0"})
        with urllib.request.urlopen(req, timeout=5) as response:
            pdb_data = json.loads(response.read().decode())
    except Exception as e:
        return {
            "status": "error",
            "game": game_title,
            "app_id": app_id,
            "message": f"Could not retrieve ProtonDB data for AppID {app_id}: {e}"
        }

    tier = pdb_data.get("tier", "unknown").capitalize()
    confidence = pdb_data.get("confidence", "unknown")
    trending_tier = pdb_data.get("trendingTier", tier).capitalize()

    # Recommended community launch options template
    recommended_launch_options = "DXVK_ASYNC=1 PROTON_ENABLE_NVAPI=1 %command%"

    return {
        "status": "success",
        "game": game_title,
        "app_id": app_id,
        "protondb_tier": tier,
        "trending_tier": trending_tier,
        "confidence": confidence,
        "protondb_url": f"https://www.protondb.com/app/{app_id}",
        "suggested_launch_options": recommended_launch_options,
        "notes": f"ProtonDB rating is {tier}. In Gaming Mode: Game > Settings > Properties > Compatibility to set GE-Proton or Proton Experimental."
    }


def backup_game_saves(destination_dir: Optional[str] = None) -> Dict[str, Any]:
    """Discover game saves across Proton prefixes and emulators, creating a compressed backup archive.

    Args:
        destination_dir: Directory to save archive to (defaults to ~/GameSaveBackups).
    """
    dest = Path(destination_dir).expanduser() if destination_dir else Path.home() / "GameSaveBackups"
    dest.mkdir(parents=True, exist_ok=True)

    timestamp = time.strftime("%Y%m%d_%H%M%S")
    archive_path = dest / f"steamos_saves_backup_{timestamp}.zip"

    discovered_paths: List[Path] = []

    # 1. Search Proton prefixes for AppData / Saved Games
    if COMPATDATA_DIR.is_dir():
        for prefix in COMPATDATA_DIR.iterdir():
            pfx_users = prefix / "pfx" / "drive_c" / "users" / "steamuser"
            if pfx_users.is_dir():
                for sub in ["Saved Games", "Documents/My Games", "AppData/Local", "AppData/Roaming"]:
                    target = pfx_users / sub
                    if target.is_dir():
                        discovered_paths.append(target)

    # 2. Emulators (Flatpak & Local)
    emu_paths = [
        Path.home() / ".var" / "app" / "org.yuzu_emu.yuzu" / "data" / "yuzu" / "nand" / "user" / "save",
        Path.home() / ".config" / "RPCS3" / "dev_hdd0" / "home",
        Path.home() / ".config" / "retroarch" / "saves",
        Path.home() / ".var" / "app" / "net.rpcs3.RPCS3" / "config" / "rpcs3" / "dev_hdd0" / "home",
    ]
    for ep in emu_paths:
        if ep.is_dir():
            discovered_paths.append(ep)

    backed_up_count = 0
    with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED) as zipf:
        for p in discovered_paths:
            for root, _, files in os.walk(p):
                for f in files:
                    file_path = Path(root) / f
                    try:
                        arcname = file_path.relative_to(Path.home())
                        zipf.write(file_path, arcname)
                        backed_up_count += 1
                    except Exception:
                        pass

    size_mb = round(os.path.getsize(archive_path) / (1024 * 1024), 2)
    return {
        "status": "success",
        "archive_path": str(archive_path),
        "files_archived": backed_up_count,
        "archive_size_mb": size_mb,
        "sources_scanned": len(discovered_paths)
    }


def deck_power_telemetry() -> Dict[str, Any]:
    """Retrieve Steam Deck battery health, charge state, wattage draw, and thermal telemetry."""
    bat_dir = Path("/sys/class/power_supply/BAT1")
    if not bat_dir.is_dir():
        bat_dir = Path("/sys/class/power_supply/BAT0")

    telemetry: Dict[str, Any] = {"hardware": "Steam Deck", "battery_detected": bat_dir.is_dir()}

    if bat_dir.is_dir():
        def _read_sys(name: str) -> Optional[str]:
            p = bat_dir / name
            return p.read_text().strip() if p.is_file() else None

        capacity = _read_sys("capacity")
        status = _read_sys("status")
        power_now = _read_sys("power_now")  # microwatts
        energy_now = _read_sys("energy_now")  # microwatt-hours
        energy_full = _read_sys("energy_full")
        energy_full_design = _read_sys("energy_full_design")

        telemetry["battery_percentage"] = int(capacity) if capacity and capacity.isdigit() else None
        telemetry["charging_status"] = status

        watts = None
        if power_now and power_now.isdigit():
            watts = round(int(power_now) / 1_000_000, 2)
            telemetry["power_draw_watts"] = watts

        if watts and watts > 0 and energy_now and energy_now.isdigit() and status == "Discharging":
            hours_left = round((int(energy_now) / 1_000_000) / watts, 1)
            telemetry["estimated_runtime_hours"] = hours_left
            telemetry["estimated_runtime_minutes"] = int(hours_left * 60)

        if energy_full and energy_full_design and energy_full.isdigit() and energy_full_design.isdigit():
            health = round((int(energy_full) / int(energy_full_design)) * 100, 1)
            telemetry["battery_health_percentage"] = min(100.0, health)

    # Thermal probe
    try:
        thermal_zones = list(Path("/sys/class/thermal").glob("thermal_zone*"))
        temps = []
        for tz in thermal_zones:
            temp_file = tz / "temp"
            if temp_file.is_file():
                raw = temp_file.read_text().strip()
                if raw.isdigit():
                    temps.append(round(int(raw) / 1000, 1))
        if temps:
            telemetry["max_temp_celsius"] = max(temps)
            telemetry["avg_temp_celsius"] = round(sum(temps) / len(temps), 1)
    except Exception:
        pass

    return telemetry
