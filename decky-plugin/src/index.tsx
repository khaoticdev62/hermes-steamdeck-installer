import {
  ButtonItem,
  PanelSection,
  PanelSectionRow,
  TextField,
  ToggleField,
  DropdownItem,
  staticClasses,
  definePlugin,
  ServerAPI,
} from "@decky/ui";
import { useState, useEffect, FC } from "react";
import {
  FaRobot,
  FaGamepad,
  FaMicrophone,
  FaCheckCircle,
  FaBolt,
  FaSyncAlt,
  FaCode,
  FaCogs,
  FaVolumeUp,
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
  audio_sfx_enabled: boolean;
}

// -----------------------------------------------------------------------------
// SteamOS Web Audio SFX Synthesizer (Authentic Valve UI Sound Cues)
// -----------------------------------------------------------------------------
class SteamAudioSynthesizer {
  private ctx: AudioContext | null = null;
  public enabled: boolean = true;

  private initCtx() {
    if (!this.ctx && typeof window !== "undefined") {
      const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
      if (AudioCtx) this.ctx = new AudioCtx();
    }
  }

  public playFocusBlip() {
    if (!this.enabled) return;
    try {
      this.initCtx();
      if (!this.ctx) return;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = "sine";
      const now = this.ctx.currentTime;
      osc.frequency.setValueAtTime(460, now);
      osc.frequency.exponentialRampToValueAtTime(560, now + 0.04);
      gain.gain.setValueAtTime(0.08, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.04);
      osc.connect(gain);
      gain.connect(this.ctx.destination);
      osc.start(now);
      osc.stop(now + 0.045);
    } catch (_) {}
  }

  public playClick() {
    if (!this.enabled) return;
    try {
      this.initCtx();
      if (!this.ctx) return;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = "triangle";
      const now = this.ctx.currentTime;
      osc.frequency.setValueAtTime(820, now);
      gain.gain.setValueAtTime(0.12, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.035);
      osc.connect(gain);
      gain.connect(this.ctx.destination);
      osc.start(now);
      osc.stop(now + 0.04);
    } catch (_) {}
  }

  public playSuccessChime() {
    if (!this.enabled) return;
    try {
      this.initCtx();
      if (!this.ctx) return;
      const notes = [523.25, 659.25, 783.99]; // C5, E5, G5 Major Triad
      notes.forEach((freq, idx) => {
        const osc = this.ctx!.createOscillator();
        const gain = this.ctx!.createGain();
        osc.type = "sine";
        const start = this.ctx!.currentTime + idx * 0.07;
        osc.frequency.setValueAtTime(freq, start);
        gain.gain.setValueAtTime(0.15, start);
        gain.gain.exponentialRampToValueAtTime(0.001, start + 0.18);
        osc.connect(gain);
        gain.connect(this.ctx!.destination);
        osc.start(start);
        osc.stop(start + 0.2);
      });
    } catch (_) {}
  }
}

const steamAudio = new SteamAudioSynthesizer();

// -----------------------------------------------------------------------------
// Main Decky QAM Interface Component
// -----------------------------------------------------------------------------
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
    audio_sfx_enabled: true,
  });

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
      if (sRes.result) {
        setSettings(sRes.result);
        steamAudio.enabled = sRes.result.audio_sfx_enabled ?? true;
      }
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

  const handleTabSwitch = (tab: TabKey) => {
    steamAudio.playFocusBlip();
    setActiveTab(tab);
    if (tab === "game_ops") refreshGameOps();
    if (tab === "dev") refreshTelemetry();
  };

  const handleSendChat = async (overridePrompt?: string) => {
    steamAudio.playClick();
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
      steamAudio.playSuccessChime();

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
    steamAudio.playClick();
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
      steamAudio.playSuccessChime();
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
    steamAudio.playClick();
    try {
      await serverApi.callPluginMethod<{ service_name: string; enable: boolean }, any>(
        "toggle_service",
        { service_name: "code-server", enable: enabled }
      );
      setDevStatus((prev) => ({ ...prev, code_server_active: enabled }));
      serverApi.toaster.toast({
        title: "Dev Station",
        body: enabled ? `code-server active on port 18888` : `code-server stopped`,
      });
    } catch (e: any) {
      console.error(e);
    }
  };

  const handleToggleSSH = async (enabled: boolean) => {
    steamAudio.playClick();
    try {
      await serverApi.callPluginMethod<{ service_name: string; enable: boolean }, any>(
        "toggle_service",
        { service_name: "ssh", enable: enabled }
      );
      setDevStatus((prev) => ({ ...prev, ssh_active: enabled }));
      serverApi.toaster.toast({
        title: "Dev Station",
        body: enabled ? `SSH daemon active on port 2222` : `SSH daemon stopped`,
      });
    } catch (e: any) {
      console.error(e);
    }
  };

  const handleSaveSettings = async (updated: Partial<PluginSettings>) => {
    steamAudio.playClick();
    const newConfig = { ...settings, ...updated };
    setSettings(newConfig);
    if (updated.audio_sfx_enabled !== undefined) {
      steamAudio.enabled = updated.audio_sfx_enabled;
    }
    try {
      await serverApi.callPluginMethod<{ new_settings: any }, any>("save_settings", {
        new_settings: newConfig,
      });
      steamAudio.playSuccessChime();
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

  // Valve SteamOS 3.x System Tokens
  const steamTokens = {
    fontFamily: 'Motiva Sans, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
    cardBg: "#1a1f29",
    cardBorder: "1px solid rgba(255, 255, 255, 0.08)",
    highlightCyan: "#67c1f5",
    steamBlue: "#1a9fff",
    verifiedGold: "#cfb53b",
  };

  return (
    <PanelSection title="Hermes Command Center (v3.0.0)">
      {/* 4-Tab Valve Navigation Strip with Gamepad Focus Rings */}
      <PanelSectionRow>
        <div style={{ display: "flex", gap: "6px", width: "100%", marginBottom: "12px", fontFamily: steamTokens.fontFamily }}>
          {(
            [
              { id: "chat", label: "💬 Assistant" },
              { id: "game_ops", label: "🎮 Game Ops" },
              { id: "dev", label: "🛠️ Dev Station" },
              { id: "settings", label: "⚙️ Setup" },
            ] as const
          ).map((t) => (
            <button
              key={t.id}
              onClick={() => handleTabSwitch(t.id)}
              style={{
                flex: 1,
                padding: "8px 2px",
                background: activeTab === t.id ? steamTokens.steamBlue : "rgba(255,255,255,0.08)",
                color: activeTab === t.id ? "#ffffff" : "#94a3b8",
                border: activeTab === t.id ? "1px solid #67c1f5" : "1px solid transparent",
                borderRadius: "6px",
                fontSize: "11px",
                fontWeight: activeTab === t.id ? 700 : 500,
                cursor: "pointer",
                boxShadow: activeTab === t.id ? "0 0 12px rgba(103, 193, 245, 0.45)" : "none",
                transition: "all 0.15s cubic-bezier(0.2, 0, 0, 1)",
              }}
            >
              {t.label}
            </button>
          ))}
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
                    background: "rgba(26,159,255,0.12)",
                    border: "1px solid rgba(103,193,245,0.35)",
                    color: "#67c1f5",
                    borderRadius: "14px",
                    padding: "4px 10px",
                    fontSize: "11px",
                    cursor: "pointer",
                    transition: "transform 0.12s ease",
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
                    steamAudio.playClick();
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
                padding: "12px",
                background: steamTokens.cardBg,
                border: steamTokens.cardBorder,
                borderRadius: "8px",
                fontSize: "12px",
                maxHeight: "180px",
                overflowY: "auto",
                whiteSpace: "pre-wrap",
                color: "#dcdedf",
                lineHeight: "1.45",
                fontFamily: steamTokens.fontFamily,
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
                padding: "12px",
                background: steamTokens.cardBg,
                borderRadius: "8px",
                border: steamTokens.cardBorder,
                fontFamily: steamTokens.fontFamily,
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
                    color: steamTokens.highlightCyan,
                    cursor: "pointer",
                    fontSize: "12px",
                  }}
                >
                  🔄 Refresh
                </button>
              </div>
              <div style={{ fontSize: "11px", color: "#8a9ba8", marginTop: "4px" }}>
                AppID: {activeGame.app_id || "None"} | Tool: {activeGame.compat_tool}
              </div>

              {protonFixes && (
                <div style={{ marginTop: "10px", paddingTop: "8px", borderTop: "1px solid rgba(255,255,255,0.08)" }}>
                  <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                    <span style={{ fontSize: "11px", color: "#94a3b8" }}>ProtonDB Tier:</span>
                    <span
                      style={{
                        background: getTierColor(protonFixes.tier),
                        color: "#000",
                        padding: "2px 8px",
                        borderRadius: "4px",
                        fontWeight: 800,
                        fontSize: "10px",
                        letterSpacing: "0.5px",
                        textTransform: "uppercase",
                      }}
                    >
                      {protonFixes.tier}
                    </span>
                  </div>
                  <div style={{ fontSize: "11px", color: steamTokens.highlightCyan, marginTop: "6px" }}>
                    Recommended: <code>{protonFixes.recommended_proton}</code>
                  </div>
                  <div
                    style={{
                      fontSize: "10px",
                      background: "#0c0f14",
                      padding: "8px",
                      borderRadius: "6px",
                      marginTop: "6px",
                      fontFamily: "monospace",
                      color: "#90caf9",
                      border: "1px solid rgba(103, 193, 245, 0.2)",
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
                padding: "10px 14px",
                background: steamTokens.cardBg,
                borderRadius: "8px",
                border: steamTokens.cardBorder,
                display: "grid",
                gridTemplateColumns: "1fr 1fr",
                gap: "10px",
                fontSize: "11px",
                fontFamily: steamTokens.fontFamily,
              }}
            >
              <div>
                <span style={{ color: "#8a9ba8" }}>Battery: </span>
                <strong style={{ color: telemetry.battery_pct > 20 ? "#64ffda" : "#ff5555" }}>
                  {telemetry.battery_pct}% ({telemetry.status})
                </strong>
              </div>
              <div>
                <span style={{ color: "#8a9ba8" }}>Power Draw: </span>
                <strong style={{ color: steamTokens.highlightCyan }}>{telemetry.power_watts} W</strong>
              </div>
              <div>
                <span style={{ color: "#8a9ba8" }}>APU Temp: </span>
                <strong style={{ color: telemetry.temp_c < 75 ? "#64ffda" : "#ffaa00" }}>
                  {telemetry.temp_c}°C
                </strong>
              </div>
              <div>
                <span style={{ color: "#8a9ba8" }}>RAM Load: </span>
                <strong style={{ color: steamTokens.highlightCyan }}>{telemetry.ram_pct}%</strong>
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
              label="Steam Audio UI Chimes"
              description="Play authentic Valve audio cues for navigation & completion"
              checked={settings.audio_sfx_enabled}
              onChange={(val) => handleSaveSettings({ audio_sfx_enabled: val })}
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
        </>
      )}

      {/* Steam Deck Native Button Glyph Footer */}
      <PanelSectionRow>
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            width: "100%",
            marginTop: "12px",
            paddingTop: "10px",
            borderTop: "1px solid rgba(255, 255, 255, 0.08)",
            fontSize: "10px",
            color: "#8a9ba8",
            fontFamily: steamTokens.fontFamily,
          }}
        >
          <div style={{ display: "flex", gap: "10px" }}>
            <span><strong style={{ color: "#fff", background: "rgba(255,255,255,0.15)", padding: "1px 5px", borderRadius: "8px" }}>A</strong> SELECT</span>
            <span><strong style={{ color: "#fff", background: "rgba(255,255,255,0.15)", padding: "1px 5px", borderRadius: "8px" }}>B</strong> BACK</span>
            <span><strong style={{ color: "#fff", background: "rgba(255,255,255,0.15)", padding: "1px 5px", borderRadius: "8px" }}>X</strong> PTT</span>
          </div>
          <div>
            <span><strong style={{ color: steamTokens.highlightCyan }}>VERIFIED</strong></span>
          </div>
        </div>
      </PanelSectionRow>
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
