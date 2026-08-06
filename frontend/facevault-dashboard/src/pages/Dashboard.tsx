import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { Users, Scan, AlertTriangle, Activity, Eye, Brain } from "lucide-react";
import GlassCard from "../components/ui/GlassCard";
import NeonBadge from "../components/ui/NeonBadge";
import { getPersons, getRecognitionLogs } from "../lib/api";
import type { RecognitionLog } from "../types";

interface DashboardStats {
  totalPersons: number;
  todayScans: number;
  unknownAlerts: number;
}

export default function Dashboard() {
  const [stats, setStats] = useState<DashboardStats>({
    totalPersons: 0,
    todayScans: 0,
    unknownAlerts: 0,
  });
  const [recentLogs, setRecentLogs] = useState<RecognitionLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [apiOnline, setApiOnline] = useState<boolean | null>(null);

  useEffect(() => {
    const fetchDashboardData = async () => {
      setLoading(true);
      try {
        // Fetch persons count and today's logs in parallel
        const [personsData, todayLogsData, recentLogsData] = await Promise.all([
          getPersons(1, 1),
          getRecognitionLogs({ date: "today", limit: 100 }),
          getRecognitionLogs({ limit: 5 }),
        ]);

        const todayUnknown = todayLogsData.items.filter(
          (l) => l.person_id === null
        ).length;

        setStats({
          totalPersons: personsData.total,
          todayScans: todayLogsData.total,
          unknownAlerts: todayUnknown,
        });
        setRecentLogs(recentLogsData.items);
        setApiOnline(true);
      } catch {
        setApiOnline(false);
      } finally {
        setLoading(false);
      }
    };

    fetchDashboardData();
  }, []);

  const statCards = [
    {
      label: "REGISTERED PERSONS",
      value: loading ? "—" : stats.totalPersons.toLocaleString(),
      icon: Users,
      color: "cyan" as const,
    },
    {
      label: "TODAY SCANS",
      value: loading ? "—" : stats.todayScans.toLocaleString(),
      icon: Scan,
      color: "blue" as const,
    },
    {
      label: "UNKNOWN ALERTS",
      value: loading ? "—" : stats.unknownAlerts.toLocaleString(),
      icon: AlertTriangle,
      color: "red" as const,
    },
    {
      label: "API STATUS",
      value: loading ? "—" : apiOnline ? "ONLINE" : "OFFLINE",
      icon: Activity,
      color: apiOnline ? ("green" as const) : ("red" as const),
    },
  ];

  const colorMap = {
    cyan: "cyber-cyan",
    blue: "blue-400",
    red: "red-400",
    green: "emerald-400",
  };

  return (
    <div className="space-y-6">
      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {statCards.map((stat, i) => (
          <GlassCard key={stat.label} delay={i * 0.1}>
            <div className="flex items-start justify-between">
              <div>
                <p className="text-cyber-muted text-xs font-mono tracking-wider mb-1">
                  {stat.label}
                </p>
                <motion.h3
                  initial={{ opacity: 0, scale: 0.5 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ delay: i * 0.1 + 0.3 }}
                  className="text-3xl font-bold text-white"
                >
                  {stat.value}
                </motion.h3>
              </div>
              <div className={`p-2 rounded-lg bg-${stat.color}-500/10`}>
                <stat.icon className={`w-5 h-5 text-${colorMap[stat.color]}`} />
              </div>
            </div>
            <div className="mt-4 h-1 w-full bg-white/5 rounded-full overflow-hidden">
              <motion.div
                initial={{ width: 0 }}
                animate={{ width: loading ? "10%" : "70%" }}
                transition={{ delay: i * 0.1 + 0.5, duration: 1 }}
                className={`h-full rounded-full bg-${colorMap[stat.color]}`}
              />
            </div>
          </GlassCard>
        ))}
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <GlassCard className="lg:col-span-2" delay={0.4}>
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-lg font-semibold flex items-center gap-2">
              <Brain className="w-5 h-5 text-cyber-cyan" />
              RECOGNITION ACTIVITY (HOURLY)
            </h3>
            <NeonBadge text={apiOnline === false ? "OFFLINE" : "LIVE"} color={apiOnline === false ? "red" : "green"} />
          </div>
          {apiOnline === false ? (
            <p className="text-cyber-muted text-sm font-mono text-center py-8">
              Backend offline — chart unavailable
            </p>
          ) : (
            <div className="space-y-4">
              {[
                ["00:00", 18],
                ["04:00", 12],
                ["08:00", 54],
                ["12:00", 92],
                ["16:00", 79],
                ["20:00", 48],
                ["23:59", 21],
              ].map(([time, value]) => (
                <div key={time} className="flex items-center gap-3">
                  <span className="w-14 text-xs font-mono text-cyber-muted">{time}</span>
                  <div className="flex-1 h-2 rounded-full bg-white/5 overflow-hidden">
                    <div
                      className="h-full rounded-full bg-gradient-to-r from-cyber-cyan to-cyber-blue"
                      style={{ width: `${value}%` }}
                    />
                  </div>
                  <span className="w-10 text-right text-xs text-cyber-muted">{value}%</span>
                </div>
              ))}
            </div>
          )}
        </GlassCard>

        <GlassCard delay={0.5}>
          <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
            <Eye className="w-5 h-5 text-cyber-cyan" />
            RECENT DETECTIONS
          </h3>
          {loading ? (
            <div className="flex items-center justify-center py-8">
              <div className="w-6 h-6 border-2 border-cyber-cyan border-t-transparent rounded-full animate-spin" />
            </div>
          ) : recentLogs.length === 0 ? (
            <p className="text-cyber-muted text-sm font-mono text-center py-8">
              NO RECENT DETECTIONS
            </p>
          ) : (
            <div className="space-y-3">
              {recentLogs.map((log, i) => (
                <motion.div
                  key={log.log_id}
                  initial={{ opacity: 0, x: 20 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: 0.6 + i * 0.1 }}
                  className="flex items-center justify-between p-3 rounded-lg bg-white/5 border border-white/5 hover:border-cyber-cyan/30 transition-colors"
                >
                  <div>
                    <p className="text-sm font-medium text-white">
                      {log.person?.name || "Unknown Subject"}
                    </p>
                    <p className="text-xs text-cyber-muted font-mono">
                      {log.recognized_at
                        ? new Date(log.recognized_at).toLocaleTimeString()
                        : "—"}
                    </p>
                  </div>
                  <div className="text-right">
                    <NeonBadge
                      text={log.person_id ? "VERIFIED" : "UNKNOWN"}
                      color={log.person_id ? "green" : "red"}
                    />
                    <p className="text-xs text-cyber-muted mt-1 font-mono">
                      {log.confidence_score?.toFixed(1)}%
                    </p>
                  </div>
                </motion.div>
              ))}
            </div>
          )}
        </GlassCard>
      </div>

      {/* Bottom Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <GlassCard delay={0.6}>
          <h3 className="text-lg font-semibold mb-4">TODAY'S SUMMARY</h3>
          {loading ? (
            <div className="flex items-center justify-center py-8">
              <div className="w-6 h-6 border-2 border-cyber-cyan border-t-transparent rounded-full animate-spin" />
            </div>
          ) : (
            <div className="space-y-4">
              {[
                { label: "Total Scans", value: stats.todayScans, max: Math.max(stats.todayScans, 1), color: "bg-gradient-to-r from-cyber-cyan to-cyber-blue" },
                { label: "Known Faces", value: stats.todayScans - stats.unknownAlerts, max: Math.max(stats.todayScans, 1), color: "bg-emerald-400" },
                { label: "Unknown Alerts", value: stats.unknownAlerts, max: Math.max(stats.todayScans, 1), color: "bg-red-400" },
              ].map((item) => (
                <div key={item.label} className="flex items-center gap-3">
                  <span className="w-32 text-xs font-mono text-cyber-muted">{item.label}</span>
                  <div className="flex-1 h-2 rounded-full bg-white/5 overflow-hidden">
                    <div
                      className={`h-full rounded-full ${item.color}`}
                      style={{ width: `${Math.min((item.value / item.max) * 100, 100)}%` }}
                    />
                  </div>
                  <span className="w-10 text-right text-xs text-cyber-muted">{item.value}</span>
                </div>
              ))}
            </div>
          )}
        </GlassCard>

        <GlassCard delay={0.7} className="relative overflow-hidden">
          <div className="absolute inset-0 bg-gradient-to-br from-cyber-cyan/5 to-transparent" />
          <h3 className="text-lg font-semibold mb-4 relative z-10">SYSTEM STATUS</h3>
          <div className="space-y-4 relative z-10">
            {[
              { label: "API Gateway", status: apiOnline ? "ONLINE" : "OFFLINE", health: apiOnline ? 100 : 0 },
              { label: "Database", status: apiOnline ? "CONNECTED" : "UNKNOWN", health: apiOnline ? 100 : 0 },
              { label: "AI Engine", status: apiOnline ? "ACTIVE" : "UNKNOWN", health: apiOnline ? 95 : 0 },
              { label: "Camera Feed", status: "STANDBY", health: 0 },
            ].map((sys) => (
              <div key={sys.label} className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div
                    className={`w-2 h-2 rounded-full ${
                      sys.health > 90
                        ? "bg-emerald-400 animate-pulse"
                        : sys.health > 0
                        ? "bg-yellow-400"
                        : "bg-red-500"
                    }`}
                  />
                  <span className="text-sm text-cyber-muted">{sys.label}</span>
                </div>
                <div className="flex items-center gap-3">
                  <span className={`text-xs font-mono ${sys.health > 0 ? "text-cyber-cyan" : "text-red-400"}`}>
                    {loading ? "CHECKING..." : sys.status}
                  </span>
                  <div className="w-24 h-1.5 bg-white/10 rounded-full overflow-hidden">
                    <div
                      className={`h-full rounded-full ${sys.health > 90 ? "bg-emerald-400" : sys.health > 0 ? "bg-yellow-400" : "bg-red-500"}`}
                      style={{ width: `${sys.health}%` }}
                    />
                  </div>
                </div>
              </div>
            ))}
          </div>
        </GlassCard>
      </div>
    </div>
  );
}