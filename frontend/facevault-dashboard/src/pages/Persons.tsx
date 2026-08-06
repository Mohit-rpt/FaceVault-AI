import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { motion } from "framer-motion";
import { Search, UserPlus, ChevronRight, Users, AlertCircle } from "lucide-react";
import GlassCard from "../components/ui/GlassCard";
import NeonBadge from "../components/ui/NeonBadge";
import { getPersons, getApiErrorMessage } from "../lib/api";
import type { Person } from "../types";

export default function Persons() {
  const [persons, setPersons] = useState<Person[]>([]);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [page] = useState(1);

  useEffect(() => {
    setLoading(true);
    setError(null);
    getPersons(page, 20, search || undefined)
      .then((data) => {
        setPersons(data.items ?? []);
      })
      .catch((err) => {
        setError(getApiErrorMessage(err, "Failed to load persons"));
        setPersons([]);
      })
      .finally(() => setLoading(false));
  }, [search, page]);

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div className="relative w-full md:w-96">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-cyber-muted" />
          <input
            type="text"
            placeholder="Search identity by name..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full bg-white/5 border border-white/10 rounded-lg pl-10 pr-4 py-2.5 text-sm text-white placeholder:text-cyber-muted focus:outline-none focus:border-cyber-cyan/50 transition-colors"
          />
        </div>
        <Link
          to="/register-face"
          className="flex items-center gap-2 px-4 py-2.5 bg-cyber-cyan/10 border border-cyber-cyan/50 text-cyber-cyan rounded-lg hover:bg-cyber-cyan/20 transition-all duration-200 text-sm font-medium whitespace-nowrap"
        >
          <UserPlus className="w-4 h-4" />
          NEW IDENTITY
        </Link>
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
      ) : persons.length === 0 ? (
        <GlassCard>
          <div className="text-center py-12">
            <Users className="w-12 h-12 text-cyber-muted mx-auto mb-3" />
            <p className="text-cyber-muted font-mono text-sm">NO IDENTITIES FOUND</p>
            <p className="text-cyber-muted/60 text-xs mt-1">Register a new person to begin</p>
          </div>
        </GlassCard>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {persons.map((person, i) => (
            <motion.div
              key={person.person_id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.05 }}
            >
              <Link to={`/persons/${person.person_id}`}>
                <GlassCard hover className="group cursor-pointer h-full">
                  <div className="flex items-start justify-between mb-4">
                    <div className="w-12 h-12 rounded-full bg-gradient-to-br from-cyber-cyan to-cyber-blue flex items-center justify-center text-white font-bold text-lg shadow-[0_0_15px_rgba(0,240,255,0.2)]">
                      {person.name.charAt(0).toUpperCase()}
                    </div>
                    <ChevronRight className="w-5 h-5 text-cyber-muted group-hover:text-cyber-cyan transition-colors transform group-hover:translate-x-1" />
                  </div>
                  <h3 className="text-lg font-semibold text-white mb-1 group-hover:text-cyber-cyan transition-colors">
                    {person.name}
                  </h3>
                  <p className="text-sm text-cyber-muted mb-3">
                    {person.relationship || "No relationship tag"}
                  </p>
                  <div className="flex items-center gap-2 flex-wrap">
                    <NeonBadge text={`ID: ${person.person_id}`} color="blue" />
                    {person.details?.company && (
                      <NeonBadge text={person.details.company} color="cyan" />
                    )}
                  </div>
                  <div className="mt-3 pt-3 border-t border-white/5 flex items-center justify-between text-xs text-cyber-muted font-mono">
                    <span>{person.images?.length || 0} FACES</span>
                    <span>{person.timelines?.length || 0} LOGS</span>
                  </div>
                </GlassCard>
              </Link>
            </motion.div>
          ))}
        </div>
      )}
    </div>
  );
}