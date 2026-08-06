import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { History, Brain, Calendar, Camera, AlertCircle } from "lucide-react";
import GlassCard from "../components/ui/GlassCard";
import NeonBadge from "../components/ui/NeonBadge";
import { getRecognitionLogs, getApiErrorMessage } from "../lib/api";
import type { RecognitionLog } from "../types";

export default function RecognitionLogs() {
  const [logs, setLogs] = useState<RecognitionLog[]>([]);
  const [filter, setFilter] = useState("all");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    setError(null);
    getRecognitionLogs({ limit: 50 })
      .then((data) => {
        setLogs(data.items ?? []);
      })
      .catch((err) => {
        setError(getApiErrorMessage(err, "Failed to load recognition logs"));
        setLogs([]);
      })
      .finally(() => setLoading(false));
  }, []);

  const filtered = logs.filter((l) => {
    if (filter === "known") return l.person_id !== null;
    if (filter === "unknown") return l.person_id === null;
    return true;
  });

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <h2 className="text-lg font-semibold flex items-center gap-2">
          <History className="w-5 h-5 text-cyber-cyan" />
          RECOGNITION HISTORY
        </h2>
        <div className="flex items-center gap-2">
          {[
            { key: "all", label: "ALL" },
            { key: "known", label: "KNOWN" },
            { key: "unknown", label: "UNKNOWN" },
          ].map((f) => (
            <button
              key={f.key}
              onClick={() => setFilter(f.key)}
              className={`px-3 py-1.5 rounded-lg text-xs font-mono border transition-all ${
                filter === f.key
                  ? "bg-cyber-cyan/10 border-cyber-cyan text-cyber-cyan"
                  : "border-white/10 text-cyber-muted hover:text-white"
              }`}
            >
              {f.label}
            </button>
          ))}
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
      ) : (
        <div className="space-y-3">
          {filtered.length === 0 && (
            <GlassCard>
              <p className="text-center text-cyber-muted py-8 font-mono text-sm">NO LOGS FOUND</p>
            </GlassCard>
          )}

          {filtered.map((log, i) => (
            <motion.div
              key={log.log_id}
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: i * 0.05 }}
            >
              <GlassCard className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div className="flex items-center gap-4">
                  <div
                    className={`w-10 h-10 rounded-lg flex items-center justify-center ${
                      log.person_id ? "bg-emerald-500/10" : "bg-red-500/10"
                    }`}
                  >
                    <Brain
                      className={`w-5 h-5 ${
                        log.person_id ? "text-emerald-400" : "text-red-400"
                      }`}
                    />
                  </div>
                  <div>
                    <p className="text-white font-medium">
                      {log.person?.name || `Person #${log.person_id}` || "Unknown Subject"}
                    </p>
                    <div className="flex items-center gap-3 mt-1 text-xs text-cyber-muted">
                      <span className="flex items-center gap-1">
                        <Calendar className="w-3 h-3" />
                        {log.recognized_at ? new Date(log.recognized_at).toLocaleString() : "—"}
                      </span>
                      {log.camera_source && (
                        <span className="flex items-center gap-1">
                          <Camera className="w-3 h-3" />
                          {log.camera_source}
                        </span>
                      )}
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  {log.recognition_time_ms && (
                    <span className="text-xs font-mono text-cyber-muted">
                      {log.recognition_time_ms}ms
                    </span>
                  )}
                  <NeonBadge
                    text={`${log.confidence_score?.toFixed(1) || 0}%`}
                    color={log.person_id ? "green" : "red"}
                  />
                  <NeonBadge
                    text={log.person_id ? "VERIFIED" : "UNKNOWN"}
                    color={log.person_id ? "green" : "red"}
                  />
                </div>
              </GlassCard>
            </motion.div>
          ))}
        </div>
      )}
    </div>
  );
}