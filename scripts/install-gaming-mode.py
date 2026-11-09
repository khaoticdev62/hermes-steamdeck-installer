#!/usr/bin/env python3
"""Inject Hermes Agent into Steam Gaming Mode (shortcuts.vdf) with Steam Grid Artwork."""

from __future__ import annotations

import binascii
import glob
import os
import struct
import sys
from pathlib import Path


STEAM_DIR = Path.home() / ".steam" / "steam"
if not STEAM_DIR.is_dir():
    STEAM_DIR = Path.home() / ".local" / "share" / "Steam"

USERDATA_DIR = STEAM_DIR / "userdata"
GRID_DIR = STEAM_DIR / "appcache" / "grid"


def generate_app_id(exe: str, app_name: str) -> int:
    """Compute the 32-bit unsigned Steam Non-Game AppID CRC algorithm."""
    unique_key = f"{exe}{app_name}"
    crc = binascii.crc32(unique_key.encode("utf-8")) | 0x80000000
    return crc & 0xFFFFFFFF


def find_shortcuts_vdf_files() -> list[Path]:
    """Find all shortcuts.vdf files across all user accounts in userdata."""
    if not USERDATA_DIR.is_dir():
        return []
    return list(USERDATA_DIR.glob("*/config/shortcuts.vdf"))


def create_hermes_shortcut_bytes(app_name: str, exe: str, start_dir: str, launch_options: str, app_id: int) -> bytes:
    """Encode shortcut into binary VDF format."""
    b = bytearray()
    b.extend(b"\x000\x00")  # Index 0
    b.extend(b"\x02appid\x00" + struct.pack("<I", app_id))
    b.extend(b"\x01AppName\x00" + app_name.encode("utf-8") + b"\x00")
    b.extend(b"\x01Exe\x00" + exe.encode("utf-8") + b"\x00")
    b.extend(b"\x01StartDir\x00" + start_dir.encode("utf-8") + b"\x00")
    b.extend(b"\x01icon\x00\x00")
    b.extend(b"\x01ShortcutPath\x00\x00")
    b.extend(b"\x01LaunchOptions\x00" + launch_options.encode("utf-8") + b"\x00")
    b.extend(b"\x02IsHidden\x00" + struct.pack("<I", 0))
    b.extend(b"\x02AllowDesktopConfig\x00" + struct.pack("<I", 1))
    b.extend(b"\x02AllowOverlay\x00" + struct.pack("<I", 1))
    b.extend(b"\x02OpenVR\x00" + struct.pack("<I", 0))
    b.extend(b"\x02Devkit\x00" + struct.pack("<I", 0))
    b.extend(b"\x01DevkitGameID\x00\x00")
    b.extend(b"\x02DevkitOverrideAppID\x00" + struct.pack("<I", 0))
    b.extend(b"\x02LastPlayTime\x00" + struct.pack("<I", 0))
    b.extend(b"\x01FlatpakAppID\x00\x00")
    b.extend(b"\x00tags\x00\x010\x00AI\x00\x011\x00Assistant\x00\x08")
    b.extend(b"\x08")  # End of entry
    return bytes(b)


def install_gaming_mode() -> None:
    print("====================================================================")
    print(" Adding Hermes Agent to Steam Gaming Mode")
    print("====================================================================")

    GRID_DIR.mkdir(parents=True, exist_ok=True)

    app_name = "Hermes Agent"
    # Launch Hermes dashboard or fullscreen interactive session
    exe = f'"{Path.home()}/.local/bin/hermes"'
    start_dir = f'"{Path.home()}"'
    launch_options = "dashboard --port 9119"

    app_id = generate_app_id(exe, app_name)
    grid_app_id = (app_id << 32) | 0x02000000
    short_grid_id = str(app_id)

    print(f"Generated Steam Non-Game AppID: {app_id}")

    # Inject into shortcuts.vdf
    vdf_files = find_shortcuts_vdf_files()
    if not vdf_files:
        # Fallback create in first user dir or standard
        user_dirs = list(USERDATA_DIR.glob("*"))
        if user_dirs:
            target_vdf = user_dirs[0] / "config" / "shortcuts.vdf"
            target_vdf.parent.mkdir(parents=True, exist_ok=True)
            vdf_files = [target_vdf]

    for vdf_path in vdf_files:
        print(f"Processing: {vdf_path}")
        existing = b""
        if vdf_path.is_file():
            existing = vdf_path.read_bytes()

        if b"Hermes Agent" in existing:
            print(f"Hermes Agent is already present in {vdf_path}.")
            continue

        shortcut_bytes = create_hermes_shortcut_bytes(app_name, exe, start_dir, launch_options, app_id)

        if not existing or not existing.startswith(b"\x00shortcuts\x00"):
            new_data = b"\x00shortcuts\x00" + shortcut_bytes + b"\x08\x08"
        else:
            # Strip the trailing double \x08 and insert
            trimmed = existing.rstrip(b"\x08")
            new_data = trimmed + shortcut_bytes + b"\x08\x08"

        vdf_path.write_bytes(new_data)
        print(f"[✓] Added Hermes Agent to {vdf_path}")

    # Copy / Create placeholder high-res Steam Grid art
    assets_dir = Path(__file__).resolve().parent.parent / "assets"
    for art_type, target_name in [
        ("grid.png", f"{short_grid_id}.png"),         # Banner (460x215 or 920x430)
        ("poster.png", f"{short_grid_id}p.png"),      # Portrait (600x900)
        ("hero.png", f"{short_grid_id}_hero.png"),    # Hero (1920x620)
        ("logo.png", f"{short_grid_id}_logo.png")     # Logo
    ]:
        src = assets_dir / art_type
        dst = GRID_DIR / target_name
        if src.is_file():
            dst.write_bytes(src.read_bytes())
            print(f"[✓] Installed Steam Grid asset: {dst.name}")

    print("\n[✓] Steam Gaming Mode integration complete! Restart Steam to see Hermes Agent in your Library.")


if __name__ == "__main__":
    install_gaming_mode()
