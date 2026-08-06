import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { AlertTriangle, ShieldAlert, Eye, Trash2, Save, Loader2, AlertCircle } from "lucide-react";
import GlassCard from "../components/ui/GlassCard";
import NeonBadge from "../components/ui/NeonBadge";
import { getRecognitionLogs, getApiErrorMessage } from "../lib/api";
import type { RecognitionLog } from "../types";

export default function UnknownFaces() {
  const [unknownLogs, setUnknownLogs] = useState<RecognitionLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    setError(null);
    // Fetch recognition logs where person is not identified (unknown faces appear in logs with low confidence)
    getRecognitionLogs({ limit: 50 })
      .then((data) => {
        // Filter logs where person_id has no associated name (unknown detections)
        const unknowns = data.items.filter((l) => !l.person?.name);
        setUnknownLogs(unknowns);
      })
      .catch((err) => {
        setError(getApiErrorMessage(err, "Failed to load unknown faces"));
      })
      .finally(() => setLoading(false));
  }, []);

  const handleDismiss = (logId: number) => {
    setUnknownLogs((prev) => prev.filter((u) => u.log_id !== logId));
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3 text-red-400 mb-2">
        <ShieldAlert className="w-6 h-6" />
        <div>
          <h2 className="text-xl font-semibold">UNIDENTIFIED SUBJECTS</h2>
          <p className="text-xs text-cyber-muted font-mono">
            {loading ? "LOADING..." : `${unknownLogs.length} PENDING INVESTIGATION`}
          </p>
        </div>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="w-8 h-8 border-2 border-cyber-cyan border-t-transparent rounded-full animate-spin" />
        </div>
      ) : error ? (
        <GlassCard>
          <div className="text-center py-12">
            <AlertCircle className="w-12 h-12 text-red-400 mx-auto mb-3" />
            <p className="text-red-400 font-mono text-sm">{error}</p>
            <p className="text-cyber-muted/60 text-xs mt-1">Check if the backend server is running</p>
          </div>
        </GlassCard>
      ) : unknownLogs.length === 0 ? (
        <GlassCard>
          <div className="text-center py-12">
            <AlertTriangle className="w-12 h-12 text-emerald-500/20 mx-auto mb-3" />
            <p className="text-cyber-muted font-mono text-sm">ALL CLEAR — NO UNKNOWN FACES</p>
            <p className="text-cyber-muted/50 text-xs mt-2">
              Unknown detections will appear here after running live recognition
            </p>
          </div>
        </GlassCard>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {unknownLogs.map((log, i) => (
            <motion.div
              key={log.log_id}
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.8 }}
              transition={{ delay: i * 0.1 }}
            >
              <GlassCard className="border-red-500/10 group overflow-hidden">
                {/* Placeholder image area — no saved_path available from API */}
                <div className="aspect-video bg-black/50 rounded-lg mb-4 flex items-center justify-center border border-white/5 overflow-hidden relative">
                  <div className="absolute inset-0 flex items-center justify-center">
                    <AlertTriangle className="w-12 h-12 text-red-500/20" />
                  </div>
                  <div className="absolute top-2 right-2">
                    <NeonBadge text="UNIDENTIFIED" color="red" />
                  </div>
                  <div className="absolute bottom-2 left-2">
                    <span className="text-[10px] font-mono text-cyber-muted bg-black/60 px-2 py-1 rounded">
                      LOG #{log.log_id}
                    </span>
                  </div>
                </div>

                <div className="flex items-center justify-between mb-3">
                  <div>
                    <p className="text-xs text-cyber-muted font-mono">
                      {log.recognized_at
                        ? new Date(log.recognized_at).toLocaleString()
                        : "—"}
                    </p>
                    <p className="text-xs text-cyber-muted">
                      {log.camera_source ?? "Unknown source"}
                    </p>
                  </div>
                  <NeonBadge text={`${log.confidence_score?.toFixed(1) ?? 0}% MATCH`} color="red" />
                </div>

                <div className="flex items-center gap-2">
                  <button className="flex-1 py-2 bg-cyber-cyan/10 border border-cyber-cyan/30 text-cyber-cyan rounded-lg text-xs font-mono hover:bg-cyber-cyan/20 transition-colors flex items-center justify-center gap-1">
                    <Eye className="w-3 h-3" />
                    REVIEW
                  </button>
                  <button className="flex-1 py-2 bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 rounded-lg text-xs font-mono hover:bg-emerald-500/20 transition-colors flex items-center justify-center gap-1">
                    <Save className="w-3 h-3" />
                    REGISTER
                  </button>
                  <button
                    onClick={() => handleDismiss(log.log_id)}
                    className="p-2 bg-red-500/10 border border-red-500/30 text-red-400 rounded-lg hover:bg-red-500/20 transition-colors"
                    title="Dismiss"
                  >
                    <Trash2 className="w-3 h-3" />
                  </button>
                </div>
              </GlassCard>
            </motion.div>
          ))}
        </div>
      )}

      {/* Info note */}
      {!loading && !error && (
        <GlassCard className="border-yellow-500/10">
          <div className="flex items-start gap-3">
            <Loader2 className="w-4 h-4 text-yellow-400 mt-0.5 shrink-0" />
            <div>
              <p className="text-xs text-yellow-400 font-mono font-semibold">NOTE</p>
              <p className="text-xs text-cyber-muted mt-1">
                Unknown faces are captured during live recognition sessions. Face images are saved to storage on the backend server.
                This view shows recent unidentified recognition log entries.
              </p>
            </div>
          </div>
        </GlassCard>
      )}
    </div>
  );
}