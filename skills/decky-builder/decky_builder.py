"""Decky Loader Plugin Builder Skill for Hermes Agent."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path
from typing import Any, Dict, Optional

DECKY_PLUGINS_DIR = Path.home() / "homebrew" / "plugins"
DECKY_LOG_FILE = Path.home() / "homebrew" / "logs" / "decky.log"


def scaffold_decky_plugin(plugin_name: str, description: str = "A custom Decky plugin", author: str = "deck") -> Dict[str, Any]:
    """Scaffold a full React/TypeScript + Python Decky Loader plugin.

    Args:
        plugin_name: Machine name (e.g. 'my-cool-plugin').
        description: User visible description in Quick Access Menu.
        author: Author name.
    """
    dest = Path.home() / "Projects" / plugin_name
    src_dir = dest / "src"
    src_dir.mkdir(parents=True, exist_ok=True)

    # plugin.json
    plugin_json = {
        "name": plugin_name.replace("-", " ").title(),
        "author": author,
        "flags": ["root"],
        "description": description,
        "version": "1.0.0"
    }
    (dest / "plugin.json").write_text(json.dumps(plugin_json, indent=2))

    # package.json
    package_json = {
        "name": plugin_name,
        "version": "1.0.0",
        "description": description,
        "scripts": {"build": "decky-frontend-lib build"},
        "dependencies": {"@decky/ui": "^5.0.0"},
        "devDependencies": {"@decky/frontend-lib": "^4.0.0", "typescript": "^5.0.0"}
    }
    (dest / "package.json").write_text(json.dumps(package_json, indent=2))

    # main.py
    main_py = f'''"""Backend daemon service for {plugin_name}."""

class Plugin:
    async def get_status(self) -> str:
        return "Plugin active and operational on Steam Deck!"
'''
    (dest / "main.py").write_text(main_py)

    # src/index.tsx
    index_tsx = f'''import {{ PanelSection, PanelSectionRow, ButtonItem, staticClasses, definePlugin, ServerAPI }} from "@decky/ui";
import {{ useState, FC }} from "react";
import {{ FaGamepad }} from "react-icons/fa";

const Content: FC<{{ serverApi: ServerAPI }}> = ({{ serverApi }}) => {{
  const [status, setStatus] = useState("Tap button to test");

  const check = async () => {{
    const res = await serverApi.callPluginMethod<Record<string, never>, string>("get_status", {{}});
    setStatus(res.result || "No response");
  }};

  return (
    <PanelSection title="{plugin_name.replace('-', ' ').title()}">
      <PanelSectionRow>
        <div>{{status}}</div>
      </PanelSectionRow>
      <PanelSectionRow>
        <ButtonItem layout="below" onClick={{check}}>Test Backend</ButtonItem>
      </PanelSectionRow>
    </PanelSection>
  );
}};

export default definePlugin((serverApi: ServerAPI) => ({{
  title: <div className={{staticClasses.Title}}>{plugin_name.replace('-', ' ').title()}</div>,
  content: <Content serverApi={{serverApi}} />,
  icon: <FaGamepad />
}}));
'''
    (src_dir / "index.tsx").write_text(index_tsx)

    return {
        "status": "success",
        "plugin_name": plugin_name,
        "path": str(dest),
        "files_created": ["plugin.json", "package.json", "main.py", "src/index.tsx"]
    }


def deploy_decky_plugin(plugin_path: str) -> Dict[str, Any]:
    """Copy plugin into ~/homebrew/plugins/ and restart the plugin service."""
    p = Path(plugin_path).expanduser()
    if not (p / "plugin.json").is_file():
        return {"status": "error", "message": f"Invalid Decky plugin directory at {p} (missing plugin.json)"}

    plugin_name = p.name
    target = DECKY_PLUGINS_DIR / plugin_name
    DECKY_PLUGINS_DIR.mkdir(parents=True, exist_ok=True)

    try:
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(p, target)
        # Try to restart decky service
        subprocess.run(["sudo", "systemctl", "restart", "plugin_loader"], stderr=subprocess.DEVNULL)
        return {
            "status": "success",
            "plugin_name": plugin_name,
            "deployed_to": str(target),
            "restarted_service": True
        }
    except Exception as e:
        return {"status": "error", "message": f"Deployment failed: {e}"}


def tail_decky_logs(lines: int = 40) -> Dict[str, Any]:
    """Retrieve recent lines from Decky Loader's runtime log."""
    if not DECKY_LOG_FILE.is_file():
        return {"status": "error", "message": f"Log file not found at {DECKY_LOG_FILE}"}

    try:
        content = DECKY_LOG_FILE.read_text(errors="replace").splitlines()
        return {
            "status": "success",
            "log_path": str(DECKY_LOG_FILE),
            "lines": content[-lines:]
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}
