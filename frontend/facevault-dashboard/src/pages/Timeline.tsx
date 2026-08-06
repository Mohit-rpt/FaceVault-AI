import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { motion } from "framer-motion";
import { Clock, MapPin, Tag, CalendarDays, AlertCircle } from "lucide-react";
import GlassCard from "../components/ui/GlassCard";
import { getPersonTimeline, getApiErrorMessage } from "../lib/api";
import type { TimelineEvent } from "../types";

export default function Timeline() {
  const { id } = useParams();
  const [events, setEvents] = useState<TimelineEvent[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const personId = Number(id) || 1;
    setLoading(true);
    setError(null);
    getPersonTimeline(personId)
      .then((data) => {
        setEvents(Array.isArray(data) ? data : []);
      })
      .catch((err) => {
        setError(getApiErrorMessage(err, "Failed to load timeline"));
        setEvents([]);
      })
      .finally(() => setLoading(false));
  }, [id]);

  return (
    <div className="max-w-3xl mx-auto">
      <div className="flex items-center gap-3 mb-8">
        <CalendarDays className="w-6 h-6 text-cyber-cyan" />
        <div>
          <h2 className="text-xl font-semibold text-white">INTERACTION TIMELINE</h2>
          <p className="text-xs text-cyber-muted font-mono">CHRONOLOGICAL MEMORY LOG</p>
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
        <div className="relative space-y-8 before:absolute before:left-4 before:top-2 before:bottom-2 before:w-px before:bg-gradient-to-b from-cyber-cyan via-cyber-blue to-transparent">
          {events.length === 0 && (
            <GlassCard>
              <p className="text-center text-cyber-muted py-8 font-mono text-sm">NO TIMELINE EVENTS</p>
            </GlassCard>
          )}

          {events.map((event, i) => (
            <motion.div
              key={event.timeline_id}
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: i * 0.1 }}
              className="relative pl-12"
            >
              <div className="absolute left-0 top-0 w-8 h-8 rounded-full bg-cyber-dark border border-cyber-cyan/50 flex items-center justify-center shadow-[0_0_10px_rgba(0,240,255,0.2)]">
                <Clock className="w-3.5 h-3.5 text-cyber-cyan" />
              </div>

              <GlassCard className="group hover:border-cyber-cyan/30 transition-colors">
                <div className="flex items-start justify-between mb-2">
                  <h3 className="text-lg font-semibold text-white group-hover:text-cyber-cyan transition-colors">
                    {event.title}
                  </h3>
                  <span className="text-xs font-mono text-cyber-cyan bg-cyber-cyan/10 px-2 py-1 rounded">
                    {new Date(event.interaction_date).toLocaleDateString()}
                  </span>
                </div>

                {event.description && (
                  <p className="text-sm text-cyber-muted mb-3 leading-relaxed">{event.description}</p>
                )}

                <div className="flex flex-wrap items-center gap-4 text-xs text-cyber-muted">
                  {event.location && (
                    <span className="flex items-center gap-1">
                      <MapPin className="w-3 h-3" />
                      {event.location}
                    </span>
                  )}
                  {event.tags && (
                    <span className="flex items-center gap-1">
                      <Tag className="w-3 h-3" />
                      {event.tags}
                    </span>
                  )}
                </div>
              </GlassCard>
            </motion.div>
          ))}
        </div>
      )}
    </div>
  );
}