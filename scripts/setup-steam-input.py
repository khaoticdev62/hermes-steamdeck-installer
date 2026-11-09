#!/usr/bin/env python3
"""Install the official Steam Input controller template for Hermes Agent."""

from __future__ import annotations

import binascii
import os
import shutil
import sys
from pathlib import Path

STEAM_DIR = Path.home() / ".steam" / "steam"
if not STEAM_DIR.is_dir():
    STEAM_DIR = Path.home() / ".local" / "share" / "Steam"

TEMPLATES_DIR = STEAM_DIR / "controller_base" / "templates"
TEMPLATE_SRC = Path(__file__).resolve().parent.parent / "assets" / "controller_templates" / "hermes_gamepad_template.vdf"


def compute_app_id(exe: str, app_name: str) -> int:
    unique_key = f"{exe}{app_name}"
    crc = binascii.crc32(unique_key.encode("utf-8")) | 0x80000000
    return crc & 0xFFFFFFFF


def install_controller_template() -> None:
    print("====================================================================")
    print(" Installing Official Steam Input Gamepad Profile for Hermes")
    print("====================================================================")

    if not TEMPLATE_SRC.is_file():
        print(f"[Error] Source template not found at {TEMPLATE_SRC}")
        return

    TEMPLATES_DIR.mkdir(parents=True, exist_ok=True)
    dest_file = TEMPLATES_DIR / "hermes_gamepad_template.vdf"
    shutil.copyfile(TEMPLATE_SRC, dest_file)
    print(f"[✓] Installed controller template to: {dest_file}")

    # Calculate Hermes AppID
    exe = f'"{Path.home()}/.local/bin/hermes"'
    app_id = compute_app_id(exe, "Hermes Agent")

    # Also place template into user controller configurations if userdata exists
    userdata_dir = STEAM_DIR / "userdata"
    if userdata_dir.is_dir():
        for user_dir in userdata_dir.glob("*"):
            user_config_dir = user_dir / "config" / "controller_configs" / "apps" / str(app_id)
            user_config_dir.mkdir(parents=True, exist_ok=True)
            user_dest = user_config_dir / "controller_configuration.vdf"
            shutil.copyfile(TEMPLATE_SRC, user_dest)
            print(f"[✓] Linked controller configuration for AppID {app_id} in {user_dir.name}")

    print("\n[✓] Steam Input Profile configuration complete!")
    print("Controls:")
    print("  • Left Trackpad:  On-Screen 5-Way Radial Touch Menu (Ask Hermes, Fix Game, Saves, Battery)")
    print("  • Right Trackpad: High-precision Trackball Mouse + Click")
    print("  • L4 Paddle:      Voice Push-to-Talk")
    print("  • R4 Paddle:      Virtual On-Screen Keyboard")
    print("  • Triggers:       Left & Right Mouse Clicks")


if __name__ == "__main__":
    install_controller_template()
