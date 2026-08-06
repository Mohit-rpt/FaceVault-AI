import { useEffect, useRef, useState, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Radio, Scan, UserCheck, UserX, Zap, Eye, ShieldAlert, Camera, AlertCircle, Monitor, Smartphone } from "lucide-react";
import GlassCard from "../components/ui/GlassCard";
import NeonBadge from "../components/ui/NeonBadge";
import CameraLiveFeed from "../components/ui/CameraLiveFeed";
import { recognizeFace, getSettings, getApiErrorMessage, getCameraStatus, getCameraFrameBlob } from "../lib/api";

type CameraSource = "browser" | "external";

interface Detection {
  id: number;
  name: string;
  confidence: number;
  x: number;
  y: number;
  w: number;
  h: number;
  known: boolean;
}

export default function LiveRecognition() {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const [cameraSource, setCameraSource] = useState<CameraSource>("browser");
  const [isStreaming, setIsStreaming] = useState(false);
  const [detections, setDetections] = useState<Detection[]>([]);
  const [fps, setFps] = useState(0);
  const [scanning, setScanning] = useState(false);
  const [videoDims, setVideoDims] = useState({ width: 1280, height: 720 });
  const [frameSkip, setFrameSkip] = useState(3);
  const [threshold, setThreshold] = useState(60);
  const [apiError, setApiError] = useState<string | null>(null);
  const [frameCounter, setFrameCounter] = useState(0);
  const [extCameraConnected, setExtCameraConnected] = useState(false);

  // Load settings
  useEffect(() => {
    getSettings()
      .then((settings) => {
        const skipSetting = settings.find((s) => s.setting_key === "frame_skip");
        const thresholdSetting = settings.find((s) => s.setting_key === "recognition_threshold");
        if (skipSetting?.setting_value) setFrameSkip(Number(skipSetting.setting_value));
        if (thresholdSetting?.setting_value) setThreshold(Number(thresholdSetting.setting_value));
      })
      .catch(() => {
        // Use defaults if settings unavailable
      });
  }, []);

  // ====== CHECK EXTERNAL CAMERA STATUS ======
  useEffect(() => {
    getCameraStatus()
      .then((s) => setExtCameraConnected(s.connected))
      .catch(() => setExtCameraConnected(false));
  }, []);

  // ====== START CAMERA ======
  const startCamera = useCallback(async () => {
    if (cameraSource === "external") {
      // External camera — use MJPEG stream from backend
      try {
        const s = await getCameraStatus();
        if (!s.connected) {
          alert("External camera not connected. Go to Camera Settings to connect first.");
          return;
        }
        setExtCameraConnected(true);
        if (s.resolution) {
          setVideoDims({ width: s.resolution.width, height: s.resolution.height });
        }
        setIsStreaming(true);
        setScanning(true);
        setApiError(null);
      } catch (err) {
        console.error("External camera status error:", err);
        alert("Cannot reach backend camera. Check if camera is connected.");
      }
      return;
    }

    // Browser webcam (existing flow)
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          width: { ideal: 1280 },
          height: { ideal: 720 },
          facingMode: "user",
        },
        audio: false,
      });

      streamRef.current = stream;

      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        videoRef.current.onloadedmetadata = () => {
          videoRef.current?.play();
          setVideoDims({
            width: videoRef.current!.videoWidth,
            height: videoRef.current!.videoHeight,
          });
          setIsStreaming(true);
          setScanning(true);
          setApiError(null);
        };
      }
    } catch (err) {
      console.error("Camera error:", err);
      alert("Camera access denied or not available. Please allow camera permissions.");
    }
  }, [cameraSource]);

  // ====== STOP CAMERA ======
  const stopCamera = useCallback(() => {
    if (intervalRef.current) clearInterval(intervalRef.current);
    intervalRef.current = null;
    streamRef.current?.getTracks().forEach((t) => t.stop());
    streamRef.current = null;
    if (videoRef.current) {
      videoRef.current.srcObject = null;
      videoRef.current.onloadedmetadata = null;
    }
    setIsStreaming(false);
    setScanning(false);
    setDetections([]);
    setFps(0);
    setApiError(null);
    setFrameCounter(0);
  }, []);

  // Re-check external camera status when switching source
  useEffect(() => {
    if (cameraSource === "external") {
      getCameraStatus()
        .then((s) => setExtCameraConnected(s.connected))
        .catch(() => setExtCameraConnected(false));
    }
  }, [cameraSource]);

  // Cleanup on unmount
  useEffect(() => {
    return () => stopCamera();
  }, [stopCamera]);

  // ====== FPS COUNTER ======
  useEffect(() => {
    if (!isStreaming) { setFps(0); return; }
    let frameCount = 0;
    let lastTime = performance.now();
    let rafId: number;

    const loop = () => {
      const now = performance.now();
      frameCount++;
      if (now - lastTime >= 1000) {
        setFps(frameCount);
        frameCount = 0;
        lastTime = now;
      }
      rafId = requestAnimationFrame(loop);
    };
    rafId = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(rafId);
  }, [isStreaming]);

  // ====== REAL RECOGNITION LOOP ======
  useEffect(() => {
    if (!isStreaming) return;

    let localFrame = 0;

    intervalRef.current = setInterval(async () => {
      localFrame++;
      setFrameCounter(localFrame);

      // Only call API every N frames (frame skip)
      if (localFrame % frameSkip !== 0) return;

      let frameBlob: Blob | null = null;
      let frameW = videoDims.width;
      let frameH = videoDims.height;

      if (cameraSource === "external") {
        try {
          frameBlob = await getCameraFrameBlob();
        } catch {
          return;
        }
      } else {
        const video = videoRef.current;
        const canvas = canvasRef.current;
        if (!video || !canvas || video.readyState < 2) return;

        frameW = video.videoWidth;
        frameH = video.videoHeight;
        canvas.width = frameW;
        canvas.height = frameH;

        const ctx = canvas.getContext("2d");
        if (!ctx) return;
        ctx.drawImage(video, 0, 0);

        frameBlob = await new Promise<Blob | null>((resolve) =>
          canvas.toBlob(resolve, "image/jpeg", 0.8)
        );
      }

      if (!frameBlob) return;

      try {
        const result = recognizeFace(
          frameBlob,
          cameraSource === "external" ? "external_camera" : "live_webcam"
        );
        const data = (await result) as {
          recognized_faces?: {
            person_id: number;
            person_name: string;
            confidence: number;
            similarity: number;
            bounding_box: number[];
          }[];
          unknown_faces?: { confidence: number; bounding_box: number[] }[];
        };

        const newDetections: Detection[] = [];

        // Known faces
        for (const face of data.recognized_faces ?? []) {
          const [x1, y1, x2, y2] = face.bounding_box;
          const wPct = ((x2 - x1) / frameW) * 100;
          const hPct = ((y2 - y1) / frameH) * 100;
          const xPct = (x1 / frameW) * 100;
          const yPct = (y1 / frameH) * 100;

          if (face.confidence * 100 >= threshold) {
            newDetections.push({
              id: face.person_id * 1000 + (Date.now() % 1000),
              name: face.person_name,
              confidence: face.confidence * 100,
              x: xPct,
              y: yPct,
              w: wPct,
              h: hPct,
              known: true,
            });
          }
        }

        // Unknown faces
        for (const face of data.unknown_faces ?? []) {
          const [x1, y1, x2, y2] = face.bounding_box;
          const wPct = ((x2 - x1) / frameW) * 100;
          const hPct = ((y2 - y1) / frameH) * 100;
          const xPct = (x1 / frameW) * 100;
          const yPct = (y1 / frameH) * 100;

          newDetections.push({
            id: Date.now() + Math.random() * 1000,
            name: "Unknown Subject",
            confidence: face.confidence * 100,
            x: xPct,
            y: yPct,
            w: wPct,
            h: hPct,
            known: false,
          });
        }

        setDetections(newDetections);
        setApiError(null);
      } catch (err) {
        // Don't spam errors — just clear detections if API is down
        const msg = getApiErrorMessage(err, "Recognition API error");
        setApiError(msg);
        setDetections([]);
      }
    }, 200);

    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [isStreaming, frameSkip, threshold, cameraSource, videoDims]);

  // Canvas sync
  useEffect(() => {
    if (!isStreaming) return;
    const canvas = canvasRef.current;
    const video = videoRef.current;
    if (!canvas || !video) return;

    const syncCanvas = () => {
      if (video.videoWidth && video.videoHeight) {
        canvas.width = video.videoWidth;
        canvas.height = video.videoHeight;
      }
    };

    const observer = new ResizeObserver(syncCanvas);
    observer.observe(video);
    syncCanvas();
    return () => observer.disconnect();
  }, [isStreaming]);

  return (
    <div className="space-y-4">
      {/* Camera Source Selector */}
      <GlassCard delay={0}>
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <h3 className="text-xs font-mono text-cyber-muted tracking-[0.2em] uppercase flex items-center gap-2">
            <Camera className="w-4 h-4" />
            Camera Source
          </h3>
          <div className="flex gap-2">
            <button
              onClick={() => { if (isStreaming) stopCamera(); setCameraSource("browser"); }}
              className={`flex items-center gap-2 px-4 py-2 rounded-lg border text-xs font-mono transition-all ${
                cameraSource === "browser"
                  ? "bg-cyber-cyan/10 border-cyber-cyan/50 text-cyber-cyan"
                  : "bg-white/5 border-white/10 text-cyber-muted hover:text-white hover:border-white/20"
              }`}
            >
              <Monitor className="w-3.5 h-3.5" />
              BROWSER WEBCAM
            </button>
            <button
              onClick={() => { if (isStreaming) stopCamera(); setCameraSource("external"); }}
              className={`flex items-center gap-2 px-4 py-2 rounded-lg border text-xs font-mono transition-all ${
                cameraSource === "external"
                  ? "bg-cyber-cyan/10 border-cyber-cyan/50 text-cyber-cyan"
                  : "bg-white/5 border-white/10 text-cyber-muted hover:text-white hover:border-white/20"
              }`}
            >
              <Smartphone className="w-3.5 h-3.5" />
              EXTERNAL CAMERA
              {extCameraConnected && (
                <span className="relative flex h-2 w-2 ml-1">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
                  <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500" />
                </span>
              )}
            </button>
          </div>
        </div>
        {cameraSource === "external" && !extCameraConnected && (
          <p className="text-xs text-yellow-400/70 font-mono mt-3">
            ⚠ No external camera connected. Go to Camera Settings to connect first.
          </p>
        )}
      </GlassCard>
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 h-[calc(100vh-14rem)]">
      {/* ========== MAIN CAMERA FEED ========== */}
      <div className="lg:col-span-2 flex flex-col gap-4">
        <GlassCard className="flex-1 relative overflow-hidden p-0">
          {/* Holographic Overlay Frame */}
          <div className="absolute inset-0 pointer-events-none z-10">
            <div
              className={`absolute inset-0 rounded-xl border-2 transition-colors duration-300 ${
                scanning ? "border-cyber-cyan/30" : "border-white/5"
              }`}
              style={{
                boxShadow: scanning
                  ? "inset 0 0 40px rgba(0,240,255,0.05), 0 0 40px rgba(0,240,255,0.1)"
                  : "none",
              }}
            />

            {/* Scan lines */}
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-2/3 h-px bg-gradient-to-r from-transparent via-cyber-cyan to-transparent opacity-60" />
            <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-2/3 h-px bg-gradient-to-r from-transparent via-cyber-cyan to-transparent opacity-60" />
            <div className="absolute left-0 top-1/2 -translate-y-1/2 w-px h-2/3 bg-gradient-to-b from-transparent via-cyber-cyan to-transparent opacity-60" />
            <div className="absolute right-0 top-1/2 -translate-y-1/2 w-px h-2/3 bg-gradient-to-b from-transparent via-cyber-cyan to-transparent opacity-60" />

            {/* Corner brackets */}
            {[
              "top-2 left-2 border-t-2 border-l-2",
              "top-2 right-2 border-t-2 border-r-2",
              "bottom-2 left-2 border-b-2 border-l-2",
              "bottom-2 right-2 border-b-2 border-r-2",
            ].map((cls, i) => (
              <div key={i} className={`absolute w-6 h-6 ${cls} border-cyber-cyan rounded-sm`} />
            ))}

            {/* Animated scanning line */}
            {scanning && (
              <motion.div
                animate={{ top: ["0%", "100%"] }}
                transition={{ duration: 2.5, repeat: Infinity, ease: "linear" }}
                className="absolute left-0 right-0 h-0.5 bg-gradient-to-r from-transparent via-cyber-cyan to-transparent shadow-[0_0_15px_rgba(0,240,255,0.6)] z-20"
              />
            )}

            {/* Grid overlay */}
            <div
              className="absolute inset-0 opacity-[0.03]"
              style={{
                backgroundImage:
                  "linear-gradient(rgba(0,240,255,1) 1px, transparent 1px), linear-gradient(90deg, rgba(0,240,255,1) 1px, transparent 1px)",
                backgroundSize: "40px 40px",
              }}
            />

            {scanning && (
              <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-16 h-16 border border-cyber-cyan/20 rounded-full">
                <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-1 h-1 bg-cyber-cyan rounded-full animate-pulse" />
              </div>
            )}
          </div>

          {/* Video Feed */}
          <div
            ref={containerRef}
            className="relative w-full bg-black flex items-center justify-center overflow-hidden"
            style={{ aspectRatio: isStreaming ? `${videoDims.width}/${videoDims.height}` : "16/9" }}
          >
            {/* Browser webcam video element */}
            <video
              ref={videoRef}
              autoPlay
              playsInline
              muted
              className={`w-full h-full object-cover opacity-90 ${isStreaming && cameraSource === "browser" ? "block" : "hidden"}`}
            />

            {/* External camera live feed */}
            {isStreaming && cameraSource === "external" && (
              <div className="absolute inset-0 z-0">
                <CameraLiveFeed alt="External Camera Feed" aspectRatio="full" className="h-full" />
              </div>
            )}

            <canvas ref={canvasRef} className="hidden" />

            {/* Detection bounding boxes — only shown while streaming */}
            {isStreaming && (
              <>
                <AnimatePresence>
                  {detections.map((det) => (
                    <motion.div
                      key={det.id}
                      initial={{ opacity: 0, scale: 0.8 }}
                      animate={{ opacity: 1, scale: 1 }}
                      exit={{ opacity: 0, scale: 0.8 }}
                      transition={{ duration: 0.3 }}
                      className="absolute border-2 rounded-sm pointer-events-none z-20"
                      style={{
                        left: `${det.x}%`,
                        top: `${det.y}%`,
                        width: `${det.w}%`,
                        height: `${det.h}%`,
                        borderColor: det.known ? "#00f0ff" : "#ef4444",
                        boxShadow: `0 0 20px ${
                          det.known ? "rgba(0,240,255,0.4)" : "rgba(239,68,68,0.4)"
                        }, inset 0 0 20px ${
                          det.known ? "rgba(0,240,255,0.05)" : "rgba(239,68,68,0.05)"
                        }`,
                      }}
                    >
                      <div
                        className={`absolute -top-7 left-0 px-2 py-0.5 text-[10px] font-mono font-bold rounded-sm whitespace-nowrap ${
                          det.known
                            ? "bg-cyber-cyan/20 text-cyber-cyan border border-cyber-cyan/40"
                            : "bg-red-500/20 text-red-400 border border-red-500/40"
                        }`}
                      >
                        {det.name} | {det.confidence.toFixed(1)}%
                      </div>
                      <div className="absolute -top-1 -left-1 w-2 h-2 border-t-2 border-l-2 border-current" />
                      <div className="absolute -top-1 -right-1 w-2 h-2 border-t-2 border-r-2 border-current" />
                      <div className="absolute -bottom-1 -left-1 w-2 h-2 border-b-2 border-l-2 border-current" />
                      <div className="absolute -bottom-1 -right-1 w-2 h-2 border-b-2 border-r-2 border-current" />
                    </motion.div>
                  ))}
                </AnimatePresence>

                {/* API Error overlay */}
                {apiError && (
                  <div className="absolute bottom-16 left-4 right-4 z-30">
                    <div className="flex items-center gap-2 px-3 py-2 bg-red-500/20 border border-red-500/40 rounded-lg text-xs text-red-400 font-mono">
                      <AlertCircle className="w-3 h-3 shrink-0" />
                      <span className="truncate">Recognition API: {apiError}</span>
                    </div>
                  </div>
                )}
              </>
            )}

            {/* Inactive placeholder — shown when camera is off */}
            {!isStreaming && (
              <div className="absolute inset-0 flex flex-col items-center justify-center z-20">
                <Scan className="w-16 h-16 text-cyber-muted mx-auto mb-4" />
                <p className="text-cyber-muted font-mono text-sm tracking-wider">
                  CAMERA FEED INACTIVE
                </p>
                <p className="text-cyber-muted/60 text-xs mt-1">
                  Initialize surveillance stream
                </p>
                <button
                  onClick={startCamera}
                  className="mt-6 px-6 py-2.5 bg-cyber-cyan/10 border border-cyber-cyan/50 text-cyber-cyan rounded-lg hover:bg-cyber-cyan/20 transition-all duration-200 font-mono text-sm tracking-wider flex items-center gap-2 mx-auto"
                >
                  <Radio className="w-4 h-4" />
                  INITIALIZE FEED
                </button>
              </div>
            )}
          </div>

          {/* HUD Bottom Bar */}
          {isStreaming && (
            <div className="absolute bottom-0 left-0 right-0 p-4 flex items-center justify-between z-20 bg-gradient-to-t from-black/80 to-transparent">
              <div className="flex items-center gap-3">
                <NeonBadge text={`FPS: ${fps}`} color="cyan" />
                <NeonBadge text={`FACES: ${detections.length}`} color="blue" />
                <span className="text-xs font-mono text-cyber-muted">
                  {detections.filter((d) => d.known).length} KNOWN /{" "}
                  {detections.filter((d) => !d.known).length} UNKNOWN
                </span>
              </div>
              <div className="flex items-center gap-3">
                <button
                  onClick={stopCamera}
                  className="flex items-center gap-1.5 px-3 py-1.5 bg-red-500/10 border border-red-500/40 text-red-400 rounded hover:bg-red-500/20 transition-all text-xs font-mono"
                >
                  <Camera className="w-3 h-3" />
                  STOP
                </button>
                <div className="flex items-center gap-2">
                  <span className="relative flex h-2.5 w-2.5">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75" />
                    <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-red-500" />
                  </span>
                  <span className="text-xs font-mono text-red-400 tracking-wider">LIVE</span>
                </div>
              </div>
            </div>
          )}
        </GlassCard>
      </div>

      {/* ========== SIDE PANEL ========== */}
      <div className="space-y-4 overflow-auto scrollbar-hide">
        {/* Detection Queue */}
        <GlassCard delay={0.1}>
          <h3 className="text-xs font-mono text-cyber-muted mb-4 tracking-[0.2em] uppercase flex items-center gap-2">
            <Eye className="w-4 h-4" />
            Detection Queue
          </h3>
          <div className="space-y-2">
            <AnimatePresence mode="popLayout">
              {detections.length === 0 && (
                <motion.p
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  className="text-xs text-cyber-muted text-center py-6 font-mono"
                >
                  {isStreaming ? "Scanning for faces..." : "No active detections"}
                </motion.p>
              )}
              {detections.map((det) => (
                <motion.div
                  key={det.id}
                  layout
                  initial={{ opacity: 0, x: 20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -20 }}
                  className={`flex items-center gap-3 p-3 rounded-lg border ${
                    det.known
                      ? "bg-emerald-500/5 border-emerald-500/20"
                      : "bg-red-500/5 border-red-500/20"
                  }`}
                >
                  <div
                    className={`w-9 h-9 rounded-lg flex items-center justify-center ${
                      det.known ? "bg-emerald-500/10" : "bg-red-500/10"
                    }`}
                  >
                    {det.known ? (
                      <UserCheck className="w-4 h-4 text-emerald-400" />
                    ) : (
                      <UserX className="w-4 h-4 text-red-400" />
                    )}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-white truncate">{det.name}</p>
                    <p className="text-[10px] text-cyber-muted font-mono">
                      {det.known ? "IDENTIFIED" : "UNKNOWN"}
                    </p>
                  </div>
                  <div className="text-right">
                    <p
                      className={`text-sm font-bold font-mono ${
                        det.known ? "text-emerald-400" : "text-red-400"
                      }`}
                    >
                      {det.confidence.toFixed(1)}%
                    </p>
                    <p className="text-[10px] text-cyber-muted">confidence</p>
                  </div>
                </motion.div>
              ))}
            </AnimatePresence>
          </div>
        </GlassCard>

        {/* System Metrics */}
        <GlassCard delay={0.2}>
          <h3 className="text-xs font-mono text-cyber-muted mb-4 tracking-[0.2em] uppercase flex items-center gap-2">
            <Zap className="w-4 h-4" />
            System Metrics
          </h3>
          <div className="space-y-3">
            {[
              { label: "Model", value: "Buffalo-L" },
              { label: "Threshold", value: `${threshold}%` },
              { label: "Frame Skip", value: `Every ${frameSkip}th` },
              { label: "Resolution", value: `${videoDims.width}x${videoDims.height}` },
              { label: "Frame #", value: frameCounter.toString() },
              { label: "API Status", value: apiError ? "ERROR" : isStreaming ? "ACTIVE" : "IDLE" },
            ].map((metric) => (
              <div
                key={metric.label}
                className="flex items-center justify-between py-1.5 border-b border-white/5 last:border-0"
              >
                <span className="text-xs text-cyber-muted">{metric.label}</span>
                <span
                  className={`text-xs font-mono font-medium ${
                    metric.label === "API Status" && apiError
                      ? "text-red-400"
                      : "text-cyber-cyan"
                  }`}
                >
                  {metric.value}
                </span>
              </div>
            ))}
          </div>
        </GlassCard>

        {/* Unknown Alert Summary */}
        <GlassCard delay={0.3} className="border-red-500/10">
          <div className="flex items-center gap-2 mb-3 text-red-400">
            <ShieldAlert className="w-4 h-4" />
            <h3 className="text-xs font-mono tracking-[0.2em] uppercase">Alert Status</h3>
          </div>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-2xl font-bold text-white">
                {detections.filter((d) => !d.known).length}
              </p>
              <p className="text-[10px] text-cyber-muted">Unknown now</p>
            </div>
            <div className="w-12 h-12 rounded-full border-2 border-red-500/20 flex items-center justify-center">
              <span className="text-xs font-mono text-red-400">
                {detections.filter((d) => !d.known).length > 0 ? "ALERT" : "OK"}
              </span>
            </div>
          </div>
        </GlassCard>
      </div>
    </div>
    </div>
  );
}