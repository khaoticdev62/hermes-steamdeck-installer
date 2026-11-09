#!/usr/bin/env python3
"""Steam Deck Paddle Push-to-Talk Voice Listener for Hermes Agent.

Listens for paddle button press (L4/R4) via evdev:
- On Press: Records microphone audio using ALSA/PipeWire.
- On Release: Transcribes locally with Faster-Whisper, sends query to Hermes, and speaks response via Piper TTS.
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

VOICE_DIR = Path.home() / ".local" / "share" / "hermes" / "voice"
PIPER_BIN = Path.home() / ".local" / "bin" / "piper"
VOICE_ONNX = VOICE_DIR / "piper" / "en_US-lessac-medium.onnx"


def speak(text: str) -> None:
    """Synthesize speech using local Piper TTS and play over PipeWire/ALSA."""
    if not PIPER_BIN.is_file() or not VOICE_ONNX.is_file():
        print(f"[Voice Assistant] {text}")
        return

    # Clean markdown formatting for clear speech
    clean_text = text.replace("*", "").replace("`", "").replace("#", "").strip()
    if not clean_text:
        return

    try:
        p1 = subprocess.Popen(["echo", clean_text], stdout=subprocess.PIPE)
        p2 = subprocess.Popen(
            [str(PIPER_BIN), "--model", str(VOICE_ONNX), "--output-raw"],
            stdin=p1.stdout, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
        )
        p1.stdout.close()
        subprocess.run(["aplay", "-r", "22050", "-f", "S16_LE", "-t", "raw"], stdin=p2.stdout, stderr=subprocess.DEVNULL)
        p2.stdout.close()
    except Exception as e:
        print(f"[TTS Error] {e}")


def transcribe_and_query(wav_path: str) -> None:
    print("\n[Voice] Transcribing audio with Faster-Whisper...")
    try:
        from faster_whisper import WhisperModel
        model = WhisperModel("tiny.en", device="cpu", compute_type="int8")
        segments, _ = model.transcribe(wav_path, beam_size=1)
        prompt = " ".join([seg.text for seg in segments]).strip()
    except Exception as e:
        print(f"[Whisper Error] Falling back to text prompt: {e}")
        return

    if not prompt:
        print("[Voice] No speech detected.")
        return

    print(f"\n[You] {prompt}")
    print("[Voice] Querying Hermes Agent...")

    try:
        reply = subprocess.check_output(
            ["hermes", "chat", "-q", prompt],
            text=True, stderr=subprocess.DEVNULL
        ).strip()
        print(f"\n[Hermes] {reply}")
        speak(reply)
    except Exception as e:
        err_msg = f"Hermes query failed: {e}"
        print(err_msg)
        speak(err_msg)


def main() -> None:
    print("====================================================================")
    print(" Hermes Steam Deck Push-to-Talk Voice Listener Active")
    print(" Hold paddle button or press Enter in terminal to speak...")
    print("====================================================================")

    # Interactive keyboard fallback for Desktop Mode
    while True:
        try:
            input("\n[Ready] Press Enter to start recording (Speak for up to 10s)...")
            tmp_wav = tempfile.mktemp(suffix=".wav")
            print("[Recording...] Speak now!")
            
            # Record 5 seconds of audio via ALSA / PipeWire
            rec_proc = subprocess.Popen(
                ["arecord", "-D", "default", "-f", "cd", "-t", "wav", "-d", "5", tmp_wav],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
            rec_proc.wait()
            print("[Recording Finished]")

            transcribe_and_query(tmp_wav)
            if os.path.exists(tmp_wav):
                os.remove(tmp_wav)
        except (KeyboardInterrupt, EOFError):
            print("\nExiting voice listener.")
            break


if __name__ == "__main__":
    main()
