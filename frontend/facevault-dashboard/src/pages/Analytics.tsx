import { useEffect, useState } from "react";
import { Users, Eye, Activity, Brain, AlertCircle } from "lucide-react";
import GlassCard from "../components/ui/GlassCard";
import { getPersons, getRecognitionLogs } from "../lib/api";
import type { RecognitionLog } from "../types";

interface AnalyticsStats {
  totalPersons: number;
  totalLogs: number;
  knownCount: number;
  unknownCount: number;
  avgConfidence: number;
  avgLatencyMs: number;
}

export default function Analytics() {
  const [stats, setStats] = useState<AnalyticsStats | null>(null);
  const [topPersons, setTopPersons] = useState<{ name: string; count: number }[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      setLoading(true);
      setError(null);
      try {
        const [personsData, logsData] = await Promise.all([
          getPersons(1, 1),
          getRecognitionLogs({ limit: 100 }),
        ]);

        const logs: RecognitionLog[] = logsData.items;
        const known = logs.filter((l) => l.person_id !== null);
        const unknown = logs.filter((l) => l.person_id === null);

        const avgConf =
          known.length > 0
            ? known.reduce((sum, l) => sum + l.confidence_score, 0) / known.length
            : 0;

        const withLatency = logs.filter((l) => l.recognition_time_ms);
        const avgLatency =
          withLatency.length > 0
            ? withLatency.reduce((sum, l) => sum + (l.recognition_time_ms ?? 0), 0) /
              withLatency.length
            : 0;

        // Count detections per person
        const personCountMap: Record<string, number> = {};
        for (const log of known) {
          const name = log.person?.name ?? `Person #${log.person_id}`;
          personCountMap[name] = (personCountMap[name] ?? 0) + 1;
        }
        const sortedPersons = Object.entries(personCountMap)
          .sort((a, b) => b[1] - a[1])
          .slice(0, 5)
          .map(([name, count]) => ({ name, count }));

        setStats({
          totalPersons: personsData.total,
          totalLogs: logsData.total,
          knownCount: known.length,
          unknownCount: unknown.length,
          avgConfidence: avgConf,
          avgLatencyMs: avgLatency,
        });
        setTopPersons(sortedPersons);
      } catch (err: unknown) {
        setError(err instanceof Error ? err.message : "Failed to load analytics");
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-2 border-cyber-cyan border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (error || !stats) {
    return (
      <GlassCard>
        <div className="text-center py-12">
          <AlertCircle className="w-12 h-12 text-red-400 mx-auto mb-3" />
          <p className="text-red-400 font-mono text-sm">{error ?? "No data available"}</p>
          <p className="text-cyber-muted/60 text-xs mt-1">Check if the backend server is running</p>
        </div>
      </GlassCard>
    );
  }

  const knownPct =
    stats.totalLogs > 0 ? Math.round((stats.knownCount / stats.totalLogs) * 100) : 0;
  const unknownPct = 100 - knownPct;
  const maxPersonCount = topPersons[0]?.count ?? 1;

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {[
          {
            label: "TOTAL SCANS",
            value: stats.totalLogs.toLocaleString(),
            icon: Eye,
            color: "text-cyber-cyan",
          },
          {
            label: "REGISTERED PERSONS",
            value: stats.totalPersons.toLocaleString(),
            icon: Users,
            color: "text-blue-400",
          },
          {
            label: "AVG CONFIDENCE",
            value: `${stats.avgConfidence.toFixed(1)}%`,
            icon: Brain,
            color: "text-emerald-400",
          },
          {
            label: "AVG LATENCY",
            value: stats.avgLatencyMs > 0 ? `${Math.round(stats.avgLatencyMs)}ms` : "N/A",
            icon: Activity,
            color: "text-purple-400",
          },
        ].map((stat, i) => (
          <GlassCard key={stat.label} delay={i * 0.1}>
            <div className="flex items-center justify-between mb-2">
              <stat.icon className="w-6 h-6 text-cyber-muted/50" />
            </div>
            <p className="text-2xl font-bold text-white">{stat.value}</p>
            <p className="text-xs text-cyber-muted mt-1 font-mono tracking-wider">{stat.label}</p>
          </GlassCard>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <GlassCard delay={0.4}>
          <h3 className="text-sm font-mono text-cyber-muted tracking-wider mb-4 flex items-center gap-2">
            <Activity className="w-4 h-4" />
            RECOGNITION BREAKDOWN (LAST 100)
          </h3>
          <div className="space-y-3">
            {[
              { label: "Known Faces", value: stats.knownCount, pct: knownPct, color: "bg-gradient-to-r from-cyber-cyan to-cyber-blue" },
              { label: "Unknown Faces", value: stats.unknownCount, pct: unknownPct, color: "bg-red-400" },
            ].map((item) => (
              <div key={item.label} className="flex items-center gap-3">
                <span className="w-32 text-xs font-mono text-cyber-muted">{item.label}</span>
                <div className="flex-1 h-2 rounded-full bg-white/5 overflow-hidden">
                  <div
                    className={`h-full rounded-full ${item.color}`}
                    style={{ width: `${item.pct}%` }}
                  />
                </div>
                <span className="w-20 text-right text-xs text-cyber-muted font-mono">
                  {item.value} ({item.pct}%)
                </span>
              </div>
            ))}
          </div>
        </GlassCard>

        <GlassCard delay={0.5}>
          <h3 className="text-sm font-mono text-cyber-muted tracking-wider mb-4 flex items-center gap-2">
            <Brain className="w-4 h-4" />
            RECOGNITION DISTRIBUTION
          </h3>
          <div className="grid grid-cols-2 gap-4">
            <div className="rounded-2xl border border-cyber-cyan/20 bg-cyber-cyan/5 p-5 text-center">
              <p className="text-3xl font-bold text-cyber-cyan">{knownPct}%</p>
              <p className="mt-2 text-xs font-mono text-cyber-muted">KNOWN</p>
            </div>
            <div className="rounded-2xl border border-red-500/20 bg-red-500/5 p-5 text-center">
              <p className="text-3xl font-bold text-red-400">{unknownPct}%</p>
              <p className="mt-2 text-xs font-mono text-cyber-muted">UNKNOWN</p>
            </div>
          </div>
        </GlassCard>
      </div>

      <GlassCard delay={0.6}>
        <h3 className="text-sm font-mono text-cyber-muted tracking-wider mb-4 flex items-center gap-2">
          <Users className="w-4 h-4" />
          TOP DETECTED IDENTITIES
        </h3>
        {topPersons.length === 0 ? (
          <p className="text-cyber-muted text-sm font-mono text-center py-6">
            NO RECOGNITION DATA YET
          </p>
        ) : (
          <div className="space-y-3">
            {topPersons.map(({ name, count }) => (
              <div key={name} className="flex items-center gap-3">
                <span className="w-32 text-sm text-white truncate">{name}</span>
                <div className="flex-1 h-2 rounded-full bg-white/5 overflow-hidden">
                  <div
                    className="h-full rounded-full bg-gradient-to-r from-cyber-cyan to-cyber-blue"
                    style={{ width: `${(count / maxPersonCount) * 100}%` }}
                  />
                </div>
                <span className="w-10 text-right text-xs font-mono text-cyber-muted">{count}</span>
              </div>
            ))}
          </div>
        )}
      </GlassCard>
    </div>
  );
}