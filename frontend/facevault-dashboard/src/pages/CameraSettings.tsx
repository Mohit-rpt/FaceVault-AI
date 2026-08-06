import { useEffect, useState, useCallback, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Camera,
  Smartphone,
  Video,
  Monitor,
  Wifi,
  WifiOff,
  Play,
  Square,
  CheckCircle2,
  AlertCircle,
  Loader2,
  Zap,
  RefreshCw,
  Link2,
  Signal,
} from "lucide-react";
import GlassCard from "../components/ui/GlassCard";
import NeonBadge from "../components/ui/NeonBadge";
import CameraLiveFeed from "../components/ui/CameraLiveFeed";
import {
  connectCamera,
  disconnectCamera,
  getCameraStatus,
  testCameraConnection,
  getApiErrorMessage,
} from "../lib/api";
import type { CameraType, CameraStatus } from "../types";

// ==================== Presets ====================

const CAMERA_PRESETS: Record<
  CameraType,
  { label: string; icon: typeof Smartphone; examples: string[]; placeholder: string }
> = {
  mobile: {
    label: "Mobile Camera",
    icon: Smartphone,
    examples: [
      "http://192.168.x.x:4747/video",
      "http://192.168.x.x:8080/video",
      "http://192.168.x.x:8080/videofeed",
    ],
    placeholder: "http://192.168.1.5:4747/video",
  },
  cctv: {
    label: "CCTV / IP Camera",
    icon: Video,
    examples: [
      "rtsp://admin:password@192.168.1.100:554/stream1",
      "rtsp://192.168.1.100:554/Streaming/Channels/101",
    ],
    placeholder: "rtsp://admin:password@192.168.1.100:554/stream1",
  },
  local: {
    label: "Local Webcam",
    icon: Monitor,
    examples: ["0", "1", "2"],
    placeholder: "0",
  },
};

// ==================== Component ====================

export default function CameraSettings() {
  const [cameraType, setCameraType] = useState<CameraType>("mobile");
  const [streamUrl, setStreamUrl] = useState("");
  const [status, setStatus] = useState<CameraStatus | null>(null);
  const [connecting, setConnecting] = useState(false);
  const [disconnecting, setDisconnecting] = useState(false);
  const [testing, setTesting] = useState(false);
  const [testResult, setTestResult] = useState<{
    ok: boolean;
    message: string;
  } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [showPreview, setShowPreview] = useState(false);

  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const imgRef = useRef<HTMLImageElement>(null);

  const preset = CAMERA_PRESETS[cameraType];

  // ====== Poll status ======
  const fetchStatus = useCallback(async () => {
    try {
      const s = await getCameraStatus();
      setStatus(s);
      if (s.connected && !showPreview) {
        setShowPreview(true);
      }
      if (!s.connected && showPreview) {
        setShowPreview(false);
      }
    } catch {
      // Silently fail during polling
    }
  }, [showPreview]);

  useEffect(() => {
    fetchStatus();
    pollRef.current = setInterval(fetchStatus, 3000);
    return () => {
      if (pollRef.current) clearInterval(pollRef.current);
    };
  }, [fetchStatus]);

  // ====== Connect ======
  const handleConnect = async () => {
    const url = streamUrl.trim();
    if (!url) {
      setError("Please enter a stream URL");
      return;
    }

    setConnecting(true);
    setError(null);
    setTestResult(null);

    try {
      const result = await connectCamera(url, cameraType);
      setStatus(result);
      if (result.connected) {
        setShowPreview(true);
      } else if (result.error) {
        setError(result.error);
      }
    } catch (err) {
      setError(getApiErrorMessage(err, "Failed to connect camera"));
    } finally {
      setConnecting(false);
    }
  };

  // ====== Disconnect ======
  const handleDisconnect = async () => {
    setDisconnecting(true);
    setError(null);

    try {
      const result = await disconnectCamera();
      setStatus(result);
      setShowPreview(false);
    } catch (err) {
      setError(getApiErrorMessage(err, "Failed to disconnect camera"));
    } finally {
      setDisconnecting(false);
    }
  };

  // ====== Test ======
  const handleTest = async () => {
    const url = streamUrl.trim();
    if (!url) {
      setError("Please enter a stream URL to test");
      return;
    }

    setTesting(true);
    setError(null);
    setTestResult(null);

    try {
      const result = await testCameraConnection(url);
      if (result.ok) {
        setTestResult({
          ok: true,
          message: `Connection OK — ${result.resolution?.width}×${result.resolution?.height}`,
        });
      } else {
        setTestResult({
          ok: false,
          message: result.error || "Connection test failed",
        });
      }
    } catch (err) {
      setTestResult({
        ok: false,
        message: getApiErrorMessage(err, "Test failed"),
      });
    } finally {
      setTesting(false);
    }
  };

  const isConnected = status?.connected ?? false;

  return (
    <div className="max-w-5xl mx-auto space-y-6">
      {/* ========== HEADER ========== */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-3">
            <Camera className="w-7 h-7 text-cyber-cyan" />
            CAMERA CONFIGURATION
          </h1>
          <p className="text-sm text-cyber-muted mt-1 font-mono">
            Connect mobile or CCTV cameras for live recognition
          </p>
        </div>
        <NeonBadge
          text={isConnected ? "CONNECTED" : "DISCONNECTED"}
          color={isConnected ? "green" : "red"}
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* ========== LEFT — CONFIG PANEL ========== */}
        <div className="lg:col-span-2 space-y-6">
          {/* Camera Type Selector */}
          <GlassCard delay={0.1}>
            <h3 className="text-xs font-mono text-cyber-muted mb-4 tracking-[0.2em] uppercase flex items-center gap-2">
              <Signal className="w-4 h-4" />
              Camera Type
            </h3>
            <div className="grid grid-cols-3 gap-3">
              {(Object.keys(CAMERA_PRESETS) as CameraType[]).map((type) => {
                const p = CAMERA_PRESETS[type];
                const isActive = cameraType === type;
                return (
                  <motion.button
                    key={type}
                    whileHover={{ scale: 1.02 }}
                    whileTap={{ scale: 0.98 }}
                    onClick={() => {
                      setCameraType(type);
                      setTestResult(null);
                      setError(null);
                    }}
                    className={`flex flex-col items-center gap-2 p-4 rounded-xl border transition-all duration-200 ${
                      isActive
                        ? "bg-cyber-cyan/10 border-cyber-cyan/50 text-cyber-cyan shadow-[0_0_20px_rgba(0,240,255,0.1)]"
                        : "bg-white/5 border-white/10 text-cyber-muted hover:border-white/20 hover:text-white"
                    }`}
                  >
                    <p.icon className="w-6 h-6" />
                    <span className="text-xs font-mono font-medium">
                      {p.label}
                    </span>
                  </motion.button>
                );
              })}
            </div>
          </GlassCard>

          {/* Stream URL Input */}
          <GlassCard delay={0.2}>
            <h3 className="text-xs font-mono text-cyber-muted mb-4 tracking-[0.2em] uppercase flex items-center gap-2">
              <Link2 className="w-4 h-4" />
              Stream URL
            </h3>
            <div className="space-y-4">
              <div className="relative">
                <input
                  type="text"
                  value={streamUrl}
                  onChange={(e) => {
                    setStreamUrl(e.target.value);
                    setTestResult(null);
                    setError(null);
                  }}
                  placeholder={preset.placeholder}
                  disabled={isConnected}
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-sm text-white placeholder:text-cyber-muted/50 focus:outline-none focus:border-cyber-cyan/50 transition-colors font-mono disabled:opacity-50 disabled:cursor-not-allowed"
                />
                {isConnected && (
                  <div className="absolute right-3 top-1/2 -translate-y-1/2">
                    <div className="flex items-center gap-1.5">
                      <span className="relative flex h-2 w-2">
                        <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
                        <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500" />
                      </span>
                    </div>
                  </div>
                )}
              </div>

              {/* URL Examples */}
              <div>
                <p className="text-[10px] text-cyber-muted/70 font-mono mb-2 uppercase tracking-wider">
                  Examples
                </p>
                <div className="flex flex-wrap gap-2">
                  {preset.examples.map((ex) => (
                    <button
                      key={ex}
                      onClick={() => {
                        if (!isConnected) {
                          setStreamUrl(ex);
                          setTestResult(null);
                          setError(null);
                        }
                      }}
                      disabled={isConnected}
                      className="px-2.5 py-1 bg-white/5 border border-white/10 rounded text-[11px] font-mono text-cyber-muted hover:text-white hover:border-white/20 transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
                    >
                      {ex}
                    </button>
                  ))}
                </div>
              </div>

              {/* Action Buttons */}
              <div className="flex flex-wrap gap-3 pt-2">
                {!isConnected ? (
                  <>
                    <motion.button
                      whileHover={{ scale: 1.02 }}
                      whileTap={{ scale: 0.98 }}
                      onClick={handleConnect}
                      disabled={connecting || !streamUrl.trim()}
                      className="flex items-center gap-2 px-5 py-2.5 bg-cyber-cyan/10 border border-cyber-cyan/50 text-cyber-cyan rounded-lg hover:bg-cyber-cyan/20 transition-all duration-200 text-sm font-mono font-medium disabled:opacity-40 disabled:cursor-not-allowed"
                    >
                      {connecting ? (
                        <Loader2 className="w-4 h-4 animate-spin" />
                      ) : (
                        <Play className="w-4 h-4" />
                      )}
                      {connecting ? "CONNECTING..." : "CONNECT"}
                    </motion.button>

                    <motion.button
                      whileHover={{ scale: 1.02 }}
                      whileTap={{ scale: 0.98 }}
                      onClick={handleTest}
                      disabled={testing || !streamUrl.trim()}
                      className="flex items-center gap-2 px-5 py-2.5 bg-white/5 border border-white/10 text-cyber-muted rounded-lg hover:text-white hover:border-white/20 transition-all duration-200 text-sm font-mono font-medium disabled:opacity-40 disabled:cursor-not-allowed"
                    >
                      {testing ? (
                        <Loader2 className="w-4 h-4 animate-spin" />
                      ) : (
                        <Zap className="w-4 h-4" />
                      )}
                      {testing ? "TESTING..." : "TEST CONNECTION"}
                    </motion.button>
                  </>
                ) : (
                  <motion.button
                    whileHover={{ scale: 1.02 }}
                    whileTap={{ scale: 0.98 }}
                    onClick={handleDisconnect}
                    disabled={disconnecting}
                    className="flex items-center gap-2 px-5 py-2.5 bg-red-500/10 border border-red-500/40 text-red-400 rounded-lg hover:bg-red-500/20 transition-all duration-200 text-sm font-mono font-medium disabled:opacity-40 disabled:cursor-not-allowed"
                  >
                    {disconnecting ? (
                      <Loader2 className="w-4 h-4 animate-spin" />
                    ) : (
                      <Square className="w-4 h-4" />
                    )}
                    {disconnecting ? "DISCONNECTING..." : "DISCONNECT"}
                  </motion.button>
                )}
              </div>
            </div>
          </GlassCard>

          {/* Error / Test Result Banners */}
          <AnimatePresence>
            {error && (
              <motion.div
                initial={{ opacity: 0, y: -10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                className="flex items-center gap-3 p-4 rounded-lg bg-red-500/10 border border-red-500/30"
              >
                <AlertCircle className="w-5 h-5 text-red-400 shrink-0" />
                <p className="text-red-400 text-sm font-mono">{error}</p>
              </motion.div>
            )}

            {testResult && (
              <motion.div
                initial={{ opacity: 0, y: -10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                className={`flex items-center gap-3 p-4 rounded-lg border ${
                  testResult.ok
                    ? "bg-emerald-500/10 border-emerald-500/30"
                    : "bg-red-500/10 border-red-500/30"
                }`}
              >
                {testResult.ok ? (
                  <CheckCircle2 className="w-5 h-5 text-emerald-400 shrink-0" />
                ) : (
                  <AlertCircle className="w-5 h-5 text-red-400 shrink-0" />
                )}
                <p
                  className={`text-sm font-mono ${
                    testResult.ok ? "text-emerald-400" : "text-red-400"
                  }`}
                >
                  {testResult.message}
                </p>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Live Preview */}
          <GlassCard delay={0.3} className="p-0 overflow-hidden">
            <div className="p-4 pb-0 flex items-center justify-between">
              <h3 className="text-xs font-mono text-cyber-muted tracking-[0.2em] uppercase flex items-center gap-2">
                <Camera className="w-4 h-4" />
                Live Preview
              </h3>
              {isConnected && (
                <div className="flex items-center gap-2">
                  <span className="relative flex h-2 w-2">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75" />
                    <span className="relative inline-flex rounded-full h-2 w-2 bg-red-500" />
                  </span>
                  <span className="text-xs font-mono text-red-400 tracking-wider">
                    LIVE
                  </span>
                </div>
              )}
            </div>
            <div className="relative w-full bg-black/50" style={{ aspectRatio: "16/9" }}>
              {showPreview && isConnected ? (
                <CameraLiveFeed alt="Camera Preview" aspectRatio="16/9" />
              ) : (
                <div className="absolute inset-0 flex flex-col items-center justify-center">
                  <Camera className="w-12 h-12 text-cyber-muted/40 mb-3" />
                  <p className="text-cyber-muted/60 font-mono text-sm">
                    {isConnected ? "Loading stream..." : "NO FEED — CONNECT CAMERA"}
                  </p>
                </div>
              )}

              {/* HUD overlay corners */}
              {isConnected && (
                <div className="absolute inset-0 pointer-events-none">
                  {[
                    "top-2 left-2 border-t-2 border-l-2",
                    "top-2 right-2 border-t-2 border-r-2",
                    "bottom-2 left-2 border-b-2 border-l-2",
                    "bottom-2 right-2 border-b-2 border-r-2",
                  ].map((cls, i) => (
                    <div
                      key={i}
                      className={`absolute w-5 h-5 ${cls} border-cyber-cyan/40 rounded-sm`}
                    />
                  ))}
                </div>
              )}
            </div>
          </GlassCard>
        </div>

        {/* ========== RIGHT — STATUS PANEL ========== */}
        <div className="space-y-4">
          {/* Connection Status */}
          <GlassCard delay={0.2}>
            <h3 className="text-xs font-mono text-cyber-muted mb-4 tracking-[0.2em] uppercase flex items-center gap-2">
              {isConnected ? (
                <Wifi className="w-4 h-4 text-emerald-400" />
              ) : (
                <WifiOff className="w-4 h-4 text-red-400" />
              )}
              Connection Status
            </h3>
            <div className="space-y-3">
              {[
                {
                  label: "State",
                  value: status?.state?.toUpperCase() ?? "DISCONNECTED",
                  highlight: isConnected,
                },
                {
                  label: "Camera Type",
                  value: status?.camera_type?.toUpperCase() ?? "—",
                  highlight: false,
                },
                {
                  label: "Resolution",
                  value: status?.resolution
                    ? `${status.resolution.width}×${status.resolution.height}`
                    : "—",
                  highlight: false,
                },
                {
                  label: "FPS",
                  value: status?.fps ? `${status.fps}` : "—",
                  highlight: false,
                },
                {
                  label: "Stream URL",
                  value: status?.url ?? "—",
                  highlight: false,
                  truncate: true,
                },
              ].map((item) => (
                <div
                  key={item.label}
                  className="flex items-center justify-between py-1.5 border-b border-white/5 last:border-0"
                >
                  <span className="text-xs text-cyber-muted">{item.label}</span>
                  <span
                    className={`text-xs font-mono font-medium ${
                      item.highlight ? "text-emerald-400" : "text-cyber-cyan"
                    } ${(item as {truncate?: boolean}).truncate ? "max-w-[120px] truncate" : ""}`}
                    title={(item as {truncate?: boolean}).truncate ? String(item.value) : undefined}
                  >
                    {item.value}
                  </span>
                </div>
              ))}
            </div>

            {/* Refresh button */}
            <button
              onClick={fetchStatus}
              className="mt-4 w-full flex items-center justify-center gap-2 py-2 text-xs font-mono text-cyber-muted hover:text-cyber-cyan bg-white/5 rounded-lg border border-white/5 hover:border-cyber-cyan/30 transition-all"
            >
              <RefreshCw className="w-3 h-3" />
              REFRESH STATUS
            </button>
          </GlassCard>

          {/* Quick Setup Guide */}
          <GlassCard delay={0.3}>
            <h3 className="text-xs font-mono text-cyber-muted mb-4 tracking-[0.2em] uppercase">
              Quick Setup
            </h3>
            <div className="space-y-3">
              {cameraType === "mobile" && (
                <>
                  <Step n={1} text='Install "DroidCam" or "IP Webcam" on your phone' />
                  <Step n={2} text="Connect phone to same WiFi as this computer" />
                  <Step n={3} text="Open the app and note the IP address" />
                  <Step
                    n={4}
                    text="Enter the URL above and click Connect"
                  />
                </>
              )}
              {cameraType === "cctv" && (
                <>
                  <Step n={1} text="Find your CCTV camera's RTSP URL from its settings" />
                  <Step n={2} text="Ensure the camera is on the same network" />
                  <Step n={3} text="Enter rtsp://user:pass@ip:port/stream" />
                  <Step n={4} text="Click Test Connection, then Connect" />
                </>
              )}
              {cameraType === "local" && (
                <>
                  <Step n={1} text="Enter the webcam index (usually 0)" />
                  <Step n={2} text="Use 1, 2, etc. for additional cameras" />
                  <Step n={3} text="Click Connect to start the feed" />
                </>
              )}
            </div>
          </GlassCard>

          {/* Error Log */}
          {status?.error && (
            <GlassCard delay={0.4} className="border-red-500/20">
              <div className="flex items-center gap-2 mb-2 text-red-400">
                <AlertCircle className="w-4 h-4" />
                <h3 className="text-xs font-mono tracking-[0.2em] uppercase">
                  Error
                </h3>
              </div>
              <p className="text-xs text-red-400/80 font-mono break-all">
                {status.error}
              </p>
            </GlassCard>
          )}
        </div>
      </div>
    </div>
  );
}

// ==================== Step Sub-component ====================

function Step({ n, text }: { n: number; text: string }) {
  return (
    <div className="flex items-start gap-3">
      <div className="w-5 h-5 rounded-full bg-cyber-cyan/10 border border-cyber-cyan/30 flex items-center justify-center shrink-0 mt-0.5">
        <span className="text-[10px] font-mono font-bold text-cyber-cyan">{n}</span>
      </div>
      <p className="text-xs text-cyber-muted leading-relaxed">{text}</p>
    </div>
  );
}
