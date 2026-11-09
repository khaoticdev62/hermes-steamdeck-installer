#!/usr/bin/env python3
"""SteamOS Game-Aware Adaptive Model Daemon for Hermes Agent.

Monitors gamescope / active game processes on the Steam Deck:
- When a game is active: Pins llama-server to the lightweight 3B model (low VRAM/RAM footprint).
- When idle / Desktop Mode: Scales up llama-server to the 7B model for maximum intelligence.
- Exposes an OpenAI-compatible /v1 endpoint on port 8080.
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional

MODELS_DIR = Path.home() / ".local" / "share" / "hermes" / "models"
MODEL_3B = MODELS_DIR / "qwen2.5-coder-3b-instruct-q4_k_m.gguf"
MODEL_7B = MODELS_DIR / "qwen2.5-7b-instruct-q4_k_m.gguf"

LLAMA_SERVER_BIN = shutil_which = Path.home() / ".local" / "bin" / "llama-server"
if not LLAMA_SERVER_BIN.is_file():
    LLAMA_SERVER_BIN = Path("/usr/bin/llama-server")

SERVER_PORT = 8080
SERVER_HOST = "127.0.0.1"


class AdaptiveModelServer:
    def __init__(self) -> None:
        self.current_model_tier: Optional[str] = None
        self.process: Optional[subprocess.Popen] = None
        self.running = True

    def is_game_active(self) -> bool:
        """Detect whether a game is currently running under SteamOS Gamescope."""
        # 1. Check gamescope client processes
        try:
            # Gamescope runs Steam and its game clients. Search for common game engines/wine processes
            output = subprocess.check_output(
                ["pgrep", "-f", "steamapps/common|wine-preloader|Proton|re horrors|wineserver"],
                text=True, stderr=subprocess.DEVNULL
            ).strip()
            if output:
                return True
        except Exception:
            pass

        # 2. Check /sys power profiles or active process count
        return False

    def start_model(self, tier: str) -> None:
        if self.current_model_tier == tier and self.process and self.process.poll() is None:
            return

        model_path = MODEL_3B if tier == "3B" else MODEL_7B
        if not model_path.is_file():
            # Fallback to whichever model is available
            model_path = MODEL_3B if MODEL_3B.is_file() else MODEL_7B
            if not model_path.is_file():
                print(f"[Error] No GGUF model files found in {MODELS_DIR}")
                return

        self.stop_model()

        print(f"[AdaptiveDaemon] Starting {tier} model ({model_path.name}) on port {SERVER_PORT}...")
        
        # Steam Deck APU: 4 cores / 8 threads Zen 2, unified LPDDR5
        # Threads: 4 (physical cores), Context: 4096 (in-game) or 8192 (desktop)
        ctx_size = 4096 if tier == "3B" else 8192
        ngl = 33  # Offload layers to AMD RDNA2 GPU via Vulkan

        cmd = [
            str(LLAMA_SERVER_BIN),
            "-m", str(model_path),
            "--host", SERVER_HOST,
            "--port", str(SERVER_PORT),
            "-c", str(ctx_size),
            "-t", "4",
            "-ngl", str(ngl),
            "--cont-batching",
            "--log-disable"
        ]

        try:
            self.process = subprocess.Popen(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                preexec_fn=os.setsid
            )
            self.current_model_tier = tier
            print(f"[AdaptiveDaemon] Active tier: {tier}")
        except Exception as e:
            print(f"[AdaptiveDaemon] Failed to start llama-server: {e}")

    def stop_model(self) -> None:
        if self.process and self.process.poll() is None:
            print(f"[AdaptiveDaemon] Stopping previous model process...")
            try:
                os.killpg(os.getpgid(self.process.pid), signal.SIGTERM)
                self.process.wait(timeout=5)
            except Exception:
                try:
                    os.killpg(os.getpgid(self.process.pid), signal.SIGKILL)
                except Exception:
                    pass
            self.process = None

    def run(self) -> None:
        print("[AdaptiveDaemon] Started Steam Deck Adaptive Model Daemon.")
        while self.running:
            target_tier = "3B" if self.is_game_active() else "7B"
            if target_tier != self.current_model_tier:
                print(f"[AdaptiveDaemon] State change detected. Active game: {target_tier == '3B'}. Switching to {target_tier} tier.")
                self.start_model(target_tier)
            time.sleep(10)


if __name__ == "__main__":
    server = AdaptiveModelServer()

    def handle_exit(sig, frame):
        server.running = False
        server.stop_model()
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_exit)
    signal.signal(signal.SIGTERM, handle_exit)
    server.run()
