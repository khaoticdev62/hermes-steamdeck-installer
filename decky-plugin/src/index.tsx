import {
  ButtonItem,
  PanelSection,
  PanelSectionRow,
  TextField,
  staticClasses,
  definePlugin,
  ServerAPI,
} from "@decky/ui";
import { useState, FC } from "react";
import { FaRobot, FaGamepad, FaBatteryHalf } from "react-icons/fa";

const HermesContent: FC<{ serverApi: ServerAPI }> = ({ serverApi }) => {
  const [prompt, setPrompt] = useState("");
  const [response, setResponse] = useState("Ready for questions...");
  const [loading, setLoading] = useState(false);

  const handleSend = async () => {
    if (!prompt.trim()) return;
    setLoading(true);
    setResponse("Thinking...");
    try {
      const res = await serverApi.callPluginMethod<{ prompt: string }, string>(
        "query_hermes",
        { prompt }
      );
      setResponse(res.result || "No response received.");
    } catch (e: any) {
      setResponse(`Error: ${e?.message || e}`);
    } finally {
      setLoading(false);
    }
  };

  const handleFixGame = async () => {
    setLoading(true);
    setResponse("Querying ProtonDB for current game fixes...");
    try {
      const res = await serverApi.callPluginMethod<{ app_id: string }, string>(
        "fix_game_protondb",
        { app_id: "current" }
      );
      setResponse(res.result || "Check complete.");
    } catch (e: any) {
      setResponse(`Error: ${e?.message || e}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <PanelSection title="Hermes Handheld AI">
      <PanelSectionRow>
        <TextField
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
          placeholder="Ask Hermes a question or task..."
        />
      </PanelSectionRow>

      <PanelSectionRow>
        <ButtonItem
          layout="below"
          onClick={handleSend}
          disabled={loading}
        >
          {loading ? "Processing..." : "Ask Hermes"}
        </ButtonItem>
      </PanelSectionRow>

      <PanelSectionRow>
        <div style={{ padding: "8px", background: "rgba(0,0,0,0.4)", borderRadius: "4px", fontSize: "12px", maxHeight: "150px", overflowY: "auto", whiteSpace: "pre-wrap" }}>
          {response}
        </div>
      </PanelSectionRow>

      <PanelSectionRow>
        <ButtonItem layout="below" onClick={handleFixGame}>
          Fix Game (ProtonDB)
        </ButtonItem>
      </PanelSectionRow>
    </PanelSection>
  );
};

export default definePlugin((serverApi: ServerAPI) => {
  return {
    title: <div className={staticClasses.Title}>Hermes Agent</div>,
    content: <HermesContent serverApi={serverApi} />,
    icon: <FaRobot />,
  };
});
