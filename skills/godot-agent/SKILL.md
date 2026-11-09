---
name: godot-agent
description: Godot 4 game studio assistant for Steam Deck. Scaffolds 2D/3D projects pre-configured for the 1280x800 handheld display and Steam Deck controller inputs, generates GDScript 2.0 code, and runs headless diagnostic checks.
---

# Godot 4 Game Studio Agent for Steam Deck

Turns Hermes into an autonomous game development assistant tailored for SteamOS and the Steam Deck hardware.

## Capabilities

1. **`scaffold_godot_project(project_name, target_dir=None)`**: Generates a complete Godot 4 project with built-in 1280x800 aspect ratio, Vulkan Forward+ mobile renderer, and Steam Deck controller button bindings (`deck_jump`, `deck_action`).
2. **`test_project_headless(project_path)`**: Runs the Godot project in headless mode for 60 frames to catch script errors, undefined references, and engine warnings, enabling autonomous self-healing.

## Example Queries

- "Scaffold a new 2D platformer project in Godot 4 for my Steam Deck"
- "Test my Godot game headlessly and tell me if there are any GDScript errors"
