import {
  ButtonItem,
  PanelSection,
  PanelSectionRow,
  TextField,
  ToggleField,
  DropdownItem,
  ProgressBar,
  staticClasses,
  definePlugin,
  ServerAPI,
} from "@decky/ui";
import { useState, useEffect, FC } from "react";
import {
  FaRobot,
  FaGamepad,
  FaCode,
  FaCogs,
  FaMicrophone,
  FaBolt,
  FaCheckCircle,
  FaExclamationTriangle,
  FaSyncAlt,
} from "react-icons/fa";

type TabKey = "chat" | "game_ops" | "dev" | "settings";

interface ActiveGame {
  running: boolean;
  app_id: string;
  title: string;
  compat_tool: string;
}

interface ProtonFixes {
  app_id: string;
  tier: string;
  confidence: string;
  recommended_proton: string;
  recommended_flags: string;
  summary: string;
}

interface SystemTelemetry {
  battery_pct: number;
  status: string;
  power_watts: number;
  temp_c: number;
  ram_pct: number;
}

interface DevStatus {
  code_server_active: boolean;
  code_server_url: string;
  code_server_password: string;
  ssh_active: boolean;
  ssh_command: string;
  local_ip: string;
  godot_installed: boolean;
  distrobox_installed: boolean;
}

interface PluginSettings {
  provider: string;
  model: string;
  voice_enabled: boolean;
  voice_engine: string;
  auto_offline_fallback: boolean;
  stream_responses: boolean;
}

const HermesContent: FC<{ serverApi: ServerAPI }> = ({ serverApi }) => {
  const [activeTab, setActiveTab] = useState<TabKey>("chat");

  // Chat Tab State
  const [prompt, setPrompt] = useState("");
  const [response, setResponse] = useState("Hermes Handheld Assistant is ready.");
  const [loading, setLoading] = useState(false);

  // Game Ops Tab State
  const [activeGame, setActiveGame] = useState<ActiveGame>({
    running: false,
    app_id: "",
    title: "Checking running game...",
    compat_tool: "None",
  });
  const [protonFixes, setProtonFixes] = useState<ProtonFixes | null>(null);
  const [gamePrompt, setGamePrompt] = useState("");
  const [gameLoading, setGameLoading] = useState(false);

  // Dev & Telemetry Tab State
  const [telemetry, setTelemetry] = useState<SystemTelemetry>({
    battery_pct: 100,
    status: "Normal",
    power_watts: 0.0,
    temp_c: 45.0,
    ram_pct: 35,
  });
  const [devStatus, setDevStatus] = useState<DevStatus>({
    code_server_active: false,
    code_server_url: "http://127.0.0.1:18888",
    code_server_password: "deck",
    ssh_active: false,
    ssh_command: "ssh -p 2222 deck@127.0.0.1",
    local_ip: "127.0.0.1",
    godot_installed: true,
    distrobox_installed: true,
  });

  // Settings State
  const [settings, setSettings] = useState<PluginSettings>({
    provider: "claude",
    model: "claude-3-5-sonnet-20241022",
    voice_enabled: true,
    voice_engine: "piper",
    auto_offline_fallback: true,
    stream_responses: true,
  });

  // Load telemetry and active game on mount / tab change
  const refreshGameOps = async () => {
    setGameLoading(true);
    try {
      const gameRes = await serverApi.callPluginMethod<{}, ActiveGame>("get_active_game", {});
      const game = gameRes.result || { running: false, app_id: "", title: "No Game Running", compat_tool: "None" };
      setActiveGame(game);

      if (game.running && game.app_id) {
        const fixesRes = await serverApi.callPluginMethod<{ app_id: string }, ProtonFixes>(
          "get_protondb_fixes",
          { app_id: game.app_id }
        );
        if (fixesRes.result) setProtonFixes(fixesRes.result);
      }
    } catch (e: any) {
      console.error("Failed to refresh game ops:", e);
    } finally {
      setGameLoading(false);
    }
  };

  const refreshTelemetry = async () => {
    try {
      const telemRes = await serverApi.callPluginMethod<{}, SystemTelemetry>("get_system_telemetry", {});
      if (telemRes.result) setTelemetry(telemRes.result);

      const devRes = await serverApi.callPluginMethod<{}, DevStatus>("get_dev_status", {});
      if (devRes.result) setDevStatus(devRes.result);
    } catch (e) {
      console.error("Failed to load telemetry:", e);
    }
  };

  const loadSettings = async () => {
    try {
      const sRes = await serverApi.callPluginMethod<{}, PluginSettings>("get_settings", {});
      if (sRes.result) setSettings(sRes.result);
    } catch (e) {
      console.error("Failed to load settings:", e);
    }
  };

  useEffect(() => {
    loadSettings();
    refreshTelemetry();
    refreshGameOps();
    const interval = setInterval(refreshTelemetry, 5000);
    return () => clearInterval(interval);
  }, []);

  // Handlers
  const handleSendChat = async (overridePrompt?: string) => {
    const textToSend = overridePrompt || prompt;
    if (!textToSend.trim()) return;
    setLoading(true);
    setResponse("Thinking...");
    try {
      const res = await serverApi.callPluginMethod<{ prompt: string; game_context?: string }, string>(
        "query_hermes",
        {
          prompt: textToSend,
          game_context: activeGame.running ? activeGame.title : undefined,
        }
      );
      const reply = res.result || "No response received.";
      setResponse(reply);

      // Toast notification when response finishes in background
      serverApi.toaster.toast({
        title: "Hermes Assistant",
        body: reply.length > 60 ? reply.substring(0, 57) + "..." : reply,
      });
    } catch (e: any) {
      setResponse(`Error: ${e?.message || e}`);
    } finally {
      setLoading(false);
    }
  };

  const handleApplyLaunchFlags = async () => {
    if (!protonFixes?.recommended_flags || !activeGame.app_id) return;
    setGameLoading(true);
    try {
      const res = await serverApi.callPluginMethod<
        { app_id: string; flags: string },
        { success: boolean; message: string }
      >("apply_launch_options", {
        app_id: activeGame.app_id,
        flags: protonFixes.recommended_flags,
      });
      const msg = res.result?.message || "Launch options applied.";
      serverApi.toaster.toast({
        title: "ProtonDB Auto-Fix",
        body: msg,
      });
      setResponse(msg);
    } catch (e: any) {
      serverApi.toaster.toast({
        title: "Error Applying Fixes",
        body: e?.message || "Failed to update launch options.",
      });
    } finally {
      setGameLoading(false);
    }
  };

  const handleToggleCodeServer = async (enabled: boolean) => {
    try {
      await serverApi.callPluginMethod<{ service_name: string; enable: boolean }, any>(
        "toggle_service",
        { service_name: "code-server", enable: enabled }
      );
      setDevStatus((prev) => ({ ...prev, code_server_active: enabled }));
      serverApi.toaster.toast({
        title: "Dev Station",
        body: enabled ? `code-server started on port 18888` : `code-server stopped`,
      });
    } catch (e: any) {
      console.error(e);
    }
  };

  const handleToggleSSH = async (enabled: boolean) => {
    try {
      await serverApi.callPluginMethod<{ service_name: string; enable: boolean }, any>(
        "toggle_service",
        { service_name: "ssh", enable: enabled }
      );
      setDevStatus((prev) => ({ ...prev, ssh_active: enabled }));
      serverApi.toaster.toast({
        title: "Dev Station",
        body: enabled ? `SSH daemon started on port 2222` : `SSH daemon stopped`,
      });
    } catch (e: any) {
      console.error(e);
    }
  };

  const handleSaveSettings = async (updated: Partial<PluginSettings>) => {
    const newConfig = { ...settings, ...updated };
    setSettings(newConfig);
    try {
      await serverApi.callPluginMethod<{ new_settings: any }, any>("save_settings", {
        new_settings: newConfig,
      });
      serverApi.toaster.toast({
        title: "Hermes Settings",
        body: "Settings saved successfully.",
      });
    } catch (e) {
      console.error(e);
    }
  };

  const getTierColor = (tier: string) => {
    switch (tier.toLowerCase()) {
      case "platinum":
        return "#b4e0e5";
      case "gold":
        return "#cfb53b";
      case "silver":
        return "#c0c0c0";
      case "bronze":
        return "#cd7f32";
      case "borked":
        return "#e05656";
      default:
        return "#8a9ba8";
    }
  };

  return (
    <PanelSection title="Hermes Handheld Command Center">
      {/* Tab Navigation Strip */}
      <PanelSectionRow>
        <div style={{ display: "flex", gap: "6px", width: "100%", marginBottom: "10px" }}>
          <button
            onClick={() => setActiveTab("chat")}
            style={{
              flex: 1,
              padding: "8px 4px",
              background: activeTab === "chat" ? "#1a9fff" : "rgba(255,255,255,0.1)",
              color: "#fff",
              border: "none",
              borderRadius: "4px",
              fontSize: "12px",
              fontWeight: activeTab === "chat" ? "bold" : "normal",
              cursor: "pointer",
            }}
          >
            💬 Chat
          </button>
          <button
            onClick={() => {
              setActiveTab("game_ops");
              refreshGameOps();
            }}
            style={{
              flex: 1,
              padding: "8px 4px",
              background: activeTab === "game_ops" ? "#1a9fff" : "rgba(255,255,255,0.1)",
              color: "#fff",
              border: "none",
              borderRadius: "4px",
              fontSize: "12px",
              fontWeight: activeTab === "game_ops" ? "bold" : "normal",
              cursor: "pointer",
            }}
          >
            🎮 Game Ops
          </button>
          <button
            onClick={() => {
              setActiveTab("dev");
              refreshTelemetry();
            }}
            style={{
              flex: 1,
              padding: "8px 4px",
              background: activeTab === "dev" ? "#1a9fff" : "rgba(255,255,255,0.1)",
              color: "#fff",
              border: "none",
              borderRadius: "4px",
              fontSize: "12px",
              fontWeight: activeTab === "dev" ? "bold" : "normal",
              cursor: "pointer",
            }}
          >
            🛠️ Dev
          </button>
          <button
            onClick={() => setActiveTab("settings")}
            style={{
              flex: 1,
              padding: "8px 4px",
              background: activeTab === "settings" ? "#1a9fff" : "rgba(255,255,255,0.1)",
              color: "#fff",
              border: "none",
              borderRadius: "4px",
              fontSize: "12px",
              fontWeight: activeTab === "settings" ? "bold" : "normal",
              cursor: "pointer",
            }}
          >
            ⚙️ Setup
          </button>
        </div>
      </PanelSectionRow>

      {/* TAB 1: 💬 ASSISTANT & STREAMING CHAT */}
      {activeTab === "chat" && (
        <>
          <PanelSectionRow>
            <div style={{ display: "flex", gap: "6px", flexWrap: "wrap", marginBottom: "8px" }}>
              {[
                "Beat current boss?",
                "Boost FPS / stutter fix",
                "Check battery wattage",
                "Summarize quest",
              ].map((chip) => (
                <button
                  key={chip}
                  onClick={() => {
                    setPrompt(chip);
                    handleSendChat(chip);
                  }}
                  style={{
                    background: "rgba(26,159,255,0.15)",
                    border: "1px solid rgba(26,159,255,0.4)",
                    color: "#66c0f4",
                    borderRadius: "12px",
                    padding: "4px 10px",
                    fontSize: "11px",
                    cursor: "pointer",
                  }}
                >
                  {chip}
                </button>
              ))}
            </div>
          </PanelSectionRow>

          <PanelSectionRow>
            <TextField
              value={prompt}
              onChange={(e) => setPrompt(e.target.value)}
              placeholder="Ask Hermes a question or task..."
            />
          </PanelSectionRow>

          <PanelSectionRow>
            <div style={{ display: "flex", gap: "8px", width: "100%" }}>
              <div style={{ flex: 3 }}>
                <ButtonItem layout="below" onClick={() => handleSendChat()} disabled={loading}>
                  {loading ? "Thinking..." : "Send Prompt"}
                </ButtonItem>
              </div>
              <div style={{ flex: 1 }}>
                <ButtonItem
                  layout="below"
                  onClick={() => {
                    serverApi.toaster.toast({
                      title: "Voice Assistant",
                      body: "Listening via microphone... Speak now.",
                    });
                    handleSendChat("Voice assistant listening trigger");
                  }}
                >
                  🎤 Mic
                </ButtonItem>
              </div>
            </div>
          </PanelSectionRow>

          <PanelSectionRow>
            <div
              style={{
                padding: "10px",
                background: "rgba(10, 14, 20, 0.75)",
                border: "1px solid rgba(255,255,255,0.1)",
                borderRadius: "6px",
                fontSize: "12px",
                maxHeight: "180px",
                overflowY: "auto",
                whiteSpace: "pre-wrap",
                color: "#dcdedf",
                lineHeight: "1.4",
              }}
            >
              {response}
            </div>
          </PanelSectionRow>
        </>
      )}

      {/* TAB 2: 🎮 GAME OPS & PROTONDB */}
      {activeTab === "game_ops" && (
        <>
          <PanelSectionRow>
            <div
              style={{
                width: "100%",
                padding: "10px",
                background: "rgba(15, 23, 42, 0.7)",
                borderRadius: "6px",
                border: "1px solid rgba(255,255,255,0.1)",
              }}
            >
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <strong style={{ fontSize: "14px", color: "#fff" }}>
                  {activeGame.running ? activeGame.title : "No Game Active"}
                </strong>
                <button
                  onClick={refreshGameOps}
                  style={{
                    background: "transparent",
                    border: "none",
                    color: "#66c0f4",
                    cursor: "pointer",
                    fontSize: "12px",
                  }}
                >
                  🔄 Refresh
                </button>
              </div>
              <div style={{ fontSize: "11px", color: "#8a9ba8", marginTop: "4px" }}>
                AppID: {activeGame.app_id || "None"} | Compat: {activeGame.compat_tool}
              </div>

              {protonFixes && (
                <div style={{ marginTop: "8px", paddingTop: "8px", borderTop: "1px solid rgba(255,255,255,0.1)" }}>
                  <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                    <span style={{ fontSize: "11px", color: "#fff" }}>ProtonDB Rating:</span>
                    <span
                      style={{
                        background: getTierColor(protonFixes.tier),
                        color: "#000",
                        padding: "2px 8px",
                        borderRadius: "4px",
                        fontWeight: "bold",
                        fontSize: "11px",
                        textTransform: "uppercase",
                      }}
                    >
                      {protonFixes.tier}
                    </span>
                  </div>
                  <div style={{ fontSize: "11px", color: "#66c0f4", marginTop: "4px" }}>
                    Recommended: <code>{protonFixes.recommended_proton}</code>
                  </div>
                  <div
                    style={{
                      fontSize: "10px",
                      background: "rgba(0,0,0,0.4)",
                      padding: "6px",
                      borderRadius: "4px",
                      marginTop: "6px",
                      fontFamily: "monospace",
                      color: "#90caf9",
                    }}
                  >
                    {protonFixes.recommended_flags}
                  </div>
                </div>
              )}
            </div>
          </PanelSectionRow>

          {protonFixes && (
            <PanelSectionRow>
              <ButtonItem layout="below" onClick={handleApplyLaunchFlags} disabled={gameLoading}>
                ⚡ 1-Click Apply Recommended Flags
              </ButtonItem>
            </PanelSectionRow>
          )}

          <PanelSectionRow>
            <TextField
              value={gamePrompt}
              onChange={(e) => setGamePrompt(e.target.value)}
              placeholder={`Ask walkthrough/strategy for ${activeGame.title}...`}
            />
          </PanelSectionRow>

          <PanelSectionRow>
            <ButtonItem
              layout="below"
              onClick={() => {
                if (!gamePrompt.trim()) return;
                handleSendChat(`[Strategy & Walkthrough for ${activeGame.title}]: ${gamePrompt}`);
                setActiveTab("chat");
              }}
            >
              Ask In-Game Strategy AI
            </ButtonItem>
          </PanelSectionRow>
        </>
      )}

      {/* TAB 3: 🛠️ DEV & SYSTEM STATION */}
      {activeTab === "dev" && (
        <>
          <PanelSectionRow>
            <div
              style={{
                width: "100%",
                padding: "8px 12px",
                background: "rgba(10, 25, 47, 0.7)",
                borderRadius: "6px",
                border: "1px solid rgba(100, 255, 218, 0.2)",
                display: "grid",
                gridTemplateColumns: "1fr 1fr",
                gap: "8px",
                fontSize: "12px",
              }}
            >
              <div>
                <span style={{ color: "#8892b0" }}>Battery: </span>
                <strong style={{ color: telemetry.battery_pct > 20 ? "#64ffda" : "#ff5555" }}>
                  {telemetry.battery_pct}% ({telemetry.status})
                </strong>
              </div>
              <div>
                <span style={{ color: "#8892b0" }}>Power Draw: </span>
                <strong style={{ color: "#64ffda" }}>{telemetry.power_watts} W</strong>
              </div>
              <div>
                <span style={{ color: "#8892b0" }}>Deck Temp: </span>
                <strong style={{ color: telemetry.temp_c < 75 ? "#64ffda" : "#ffaa00" }}>
                  {telemetry.temp_c}°C
                </strong>
              </div>
              <div>
                <span style={{ color: "#8892b0" }}>RAM Load: </span>
                <strong style={{ color: "#64ffda" }}>{telemetry.ram_pct}%</strong>
              </div>
            </div>
          </PanelSectionRow>

          <PanelSectionRow>
            <ToggleField
              label="code-server (VS Code)"
              description={`URL: ${devStatus.code_server_url} | Token: ${devStatus.code_server_password}`}
              checked={devStatus.code_server_active}
              onChange={handleToggleCodeServer}
            />
          </PanelSectionRow>

          <PanelSectionRow>
            <ToggleField
              label="SSH Daemon (Port 2222)"
              description={devStatus.ssh_command}
              checked={devStatus.ssh_active}
              onChange={handleToggleSSH}
            />
          </PanelSectionRow>

          <PanelSectionRow>
            <div style={{ display: "flex", gap: "8px", width: "100%" }}>
              <div style={{ flex: 1 }}>
                <ButtonItem
                  layout="below"
                  onClick={() => {
                    handleSendChat("Run Godot 4 headless project unit tests and report status.");
                    setActiveTab("chat");
                  }}
                >
                  🎮 Test Godot 4
                </ButtonItem>
              </div>
              <div style={{ flex: 1 }}>
                <ButtonItem
                  layout="below"
                  onClick={() => {
                    handleSendChat("Open Distrobox Arch Linux container and inspect dev packages.");
                    setActiveTab("chat");
                  }}
                >
                  📦 Distrobox Shell
                </ButtonItem>
              </div>
            </div>
          </PanelSectionRow>
        </>
      )}

      {/* TAB 4: ⚙️ SETTINGS & MODEL SWITCHER */}
      {activeTab === "settings" && (
        <>
          <PanelSectionRow>
            <DropdownItem
              label="Active AI Engine"
              description="Switch between cloud LLMs and offline local models"
              rgOptions={[
                { data: "claude-3-5-sonnet-20241022", label: "Claude 3.5 Sonnet (DirectSDK)" },
                { data: "claude-3-5-haiku-20241022", label: "Claude 3.5 Haiku (Low Latency)" },
                { data: "openai-codex", label: "OpenAI Codex / GPT-4o (OAuth)" },
                { data: "vulkan-llama-3b", label: "Local Vulkan Llama 3.2 3B (Offline)" },
                { data: "vulkan-qwen-7b", label: "Local Vulkan Qwen 2.5 Coder 7B (Offline)" },
              ]}
              selectedOption={settings.model}
              onChange={(opt) => handleSaveSettings({ model: opt.data as string })}
            />
          </PanelSectionRow>

          <PanelSectionRow>
            <ToggleField
              label="Piper TTS Voice Output"
              description="Speak Hermes responses aloud through Deck speakers"
              checked={settings.voice_enabled}
              onChange={(val) => handleSaveSettings({ voice_enabled: val })}
            />
          </PanelSectionRow>

          <PanelSectionRow>
            <ToggleField
              label="Auto Offline Fallback"
              description="Automatically switch to Vulkan 3B when Wi-Fi is lost"
              checked={settings.auto_offline_fallback}
              onChange={(val) => handleSaveSettings({ auto_offline_fallback: val })}
            />
          </PanelSectionRow>

          <PanelSectionRow>
            <ButtonItem
              layout="below"
              onClick={() => {
                serverApi.toaster.toast({
                  title: "Settings Saved",
                  body: `Active Model: ${settings.model}`,
                });
              }}
            >
              Save Configuration
            </ButtonItem>
          </PanelSectionRow>
        </>
      )}
    </PanelSection>
  );
};

export default definePlugin((serverApi: ServerAPI) => {
  return {
    title: <div className={staticClasses.Title}>Hermes Assistant</div>,
    content: <HermesContent serverApi={serverApi} />,
    icon: <FaRobot />,
  };
});
