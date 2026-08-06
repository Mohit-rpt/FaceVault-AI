import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { Save, Sliders, Shield, Bell, Camera, Brain, Gauge, Loader2, AlertCircle, CheckCircle2 } from "lucide-react";
import GlassCard from "../components/ui/GlassCard";
import { getSettings, updateSetting, getApiErrorMessage } from "../lib/api";
import type { Setting } from "../types";

// Keys we display in the UI and their defaults
const SETTING_KEYS = {
  recognition_threshold: "60",
  frame_skip: "3",
  auto_save_unknown: "true",
  alert_unknown: "true",
  save_logs: "true",
  camera_sound: "false",
};

type SettingKey = keyof typeof SETTING_KEYS;

export default function Settings() {
  const [settings, setSettings] = useState<Record<SettingKey, string>>(SETTING_KEYS);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saveMsg, setSaveMsg] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    setError(null);
    getSettings()
      .then((data: Setting[]) => {
        // Merge fetched settings over defaults
        const merged = { ...SETTING_KEYS };
        for (const s of data) {
          if (s.setting_key in merged && s.setting_value !== undefined && s.setting_value !== null) {
            (merged as Record<string, string>)[s.setting_key] = s.setting_value;
          }
        }
        setSettings(merged as Record<SettingKey, string>);
      })
      .catch((err) => {
        setError(getApiErrorMessage(err, "Failed to load settings"));
      })
      .finally(() => setLoading(false));
  }, []);

  const getSetting = (key: SettingKey) => settings[key] ?? SETTING_KEYS[key];

  const setSetting = (key: SettingKey, value: string) => {
    setSettings((prev) => ({ ...prev, [key]: value }));
  };

  const toggleSetting = (key: SettingKey) => {
    const current = getSetting(key) === "true";
    setSetting(key, String(!current));
  };

  const handleSave = async () => {
    setSaving(true);
    setSaveMsg(null);
    setError(null);
    try {
      await Promise.all(
        Object.entries(settings).map(([key, value]) =>
          updateSetting(key, value)
        )
      );
      setSaveMsg("Configuration saved successfully");
      setTimeout(() => setSaveMsg(null), 3000);
    } catch (err) {
      setError(getApiErrorMessage(err, "Failed to save settings"));
    } finally {
      setSaving(false);
    }
  };

  const threshold = Number(getSetting("recognition_threshold"));
  const frameSkip = Number(getSetting("frame_skip"));

  const toggles: { key: SettingKey; icon: typeof Shield; label: string; desc: string }[] = [
    { key: "auto_save_unknown", icon: Shield, label: "Auto-save unknown faces", desc: "Store unrecognized faces to disk for review" },
    { key: "alert_unknown", icon: Bell, label: "Alert on unknown detection", desc: "Push notification when stranger detected" },
    { key: "save_logs", icon: Gauge, label: "Persistent recognition logs", desc: "Save all recognition events to database" },
    { key: "camera_sound", icon: Camera, label: "Shutter sound effect", desc: "Play sound on face detection" },
  ];

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      <GlassCard>
        <h2 className="text-xl font-semibold mb-6 flex items-center gap-2">
          <Sliders className="w-6 h-6 text-cyber-cyan" />
          SYSTEM CONFIGURATION
        </h2>

        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="w-8 h-8 border-2 border-cyber-cyan border-t-transparent rounded-full animate-spin" />
          </div>
        ) : (
          <div className="space-y-8">
            {/* Error Banner */}
            {error && (
              <div className="flex items-center gap-3 p-4 rounded-lg bg-red-500/10 border border-red-500/30">
                <AlertCircle className="w-5 h-5 text-red-400 shrink-0" />
                <div>
                  <p className="text-red-400 text-sm font-medium">{error}</p>
                  <p className="text-cyber-muted/70 text-xs mt-0.5">Showing defaults — changes will attempt to save to backend</p>
                </div>
              </div>
            )}

            {/* Success Banner */}
            {saveMsg && (
              <div className="flex items-center gap-3 p-4 rounded-lg bg-emerald-500/10 border border-emerald-500/30">
                <CheckCircle2 className="w-5 h-5 text-emerald-400 shrink-0" />
                <p className="text-emerald-400 text-sm font-medium">{saveMsg}</p>
              </div>
            )}

            {/* Threshold */}
            <div>
              <div className="flex items-center justify-between mb-3">
                <label className="text-sm text-white flex items-center gap-2">
                  <Brain className="w-4 h-4 text-cyber-cyan" />
                  Recognition Threshold
                </label>
                <span className="text-lg font-mono font-bold text-cyber-cyan">{threshold}%</span>
              </div>
              <input
                type="range"
                min="30"
                max="95"
                value={threshold}
                onChange={(e) => setSetting("recognition_threshold", e.target.value)}
                className="w-full h-2 bg-white/10 rounded-lg appearance-none cursor-pointer accent-cyber-cyan"
              />
              <div className="flex justify-between text-xs text-cyber-muted font-mono mt-2">
                <span>Lenient (30%)</span>
                <span>Balanced</span>
                <span>Strict (95%)</span>
              </div>
            </div>

            {/* Frame Skip */}
            <div>
              <div className="flex items-center justify-between mb-3">
                <label className="text-sm text-white flex items-center gap-2">
                  <Camera className="w-4 h-4 text-cyber-cyan" />
                  Live Frame Skip
                </label>
                <span className="text-lg font-mono font-bold text-cyber-cyan">
                  Every {frameSkip} frames
                </span>
              </div>
              <input
                type="range"
                min="1"
                max="15"
                value={frameSkip}
                onChange={(e) => setSetting("frame_skip", e.target.value)}
                className="w-full h-2 bg-white/10 rounded-lg appearance-none cursor-pointer accent-cyber-cyan"
              />
              <div className="flex justify-between text-xs text-cyber-muted font-mono mt-2">
                <span>Realtime (1)</span>
                <span>Balanced</span>
                <span>Performance (15)</span>
              </div>
            </div>

            {/* Toggles */}
            <div className="space-y-4">
              {toggles.map((setting) => {
                const isOn = getSetting(setting.key) === "true";
                return (
                  <div
                    key={setting.key}
                    className="flex items-center justify-between p-4 rounded-lg bg-white/5 border border-white/5 hover:border-white/10 transition-colors"
                  >
                    <div className="flex items-center gap-3">
                      <div className="w-9 h-9 rounded-lg bg-cyber-cyan/10 flex items-center justify-center">
                        <setting.icon className="w-4 h-4 text-cyber-cyan" />
                      </div>
                      <div>
                        <p className="text-sm text-white">{setting.label}</p>
                        <p className="text-xs text-cyber-muted">{setting.desc}</p>
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={() => toggleSetting(setting.key)}
                      className={`relative w-12 h-6 rounded-full transition-colors ${
                        isOn ? "bg-cyber-cyan" : "bg-white/10"
                      }`}
                    >
                      <motion.div
                        animate={{ x: isOn ? 24 : 2 }}
                        transition={{ type: "spring", stiffness: 500, damping: 30 }}
                        className="absolute top-1 w-4 h-4 bg-black rounded-full shadow"
                      />
                    </button>
                  </div>
                );
              })}
            </div>

            <motion.button
              whileHover={{ scale: 1.01 }}
              whileTap={{ scale: 0.99 }}
              onClick={handleSave}
              disabled={saving}
              className="w-full py-3 bg-cyber-cyan text-black font-bold rounded-lg hover:bg-cyber-cyan/90 transition-colors flex items-center justify-center gap-2 disabled:opacity-60 disabled:cursor-not-allowed"
            >
              {saving ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  SAVING...
                </>
              ) : (
                <>
                  <Save className="w-4 h-4" />
                  SAVE CONFIGURATION
                </>
              )}
            </motion.button>
          </div>
        )}
      </GlassCard>
    </div>
  );
}