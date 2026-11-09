#!/usr/bin/env bash
# HermDeck Installer Launcher Wrapper
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${script_dir}/install-hermes-steamdeck.sh" "$@"
