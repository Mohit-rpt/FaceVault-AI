import { useEffect, useState } from "react";
import { useParams, Link } from "react-router-dom";
import { motion } from "framer-motion";
import { ArrowLeft, User, Mail, Phone, Building2, GraduationCap, MapPin, Calendar, Clock, AlertCircle } from "lucide-react";
import GlassCard from "../components/ui/GlassCard";
import NeonBadge from "../components/ui/NeonBadge";
import { getPerson, getApiErrorMessage } from "../lib/api";
import type { Person } from "../types";

export default function PersonProfile() {
  const { id } = useParams();
  const [person, setPerson] = useState<Person | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (id) {
      setLoading(true);
      setError(null);
      getPerson(Number(id))
        .then((data) => {
          setPerson(data);
          setLoading(false);
        })
        .catch((err) => {
          setError(getApiErrorMessage(err, "Failed to load person"));
          setLoading(false);
        });
    }
  }, [id]);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-2 border-cyber-cyan border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="space-y-6">
        <Link to="/persons" className="inline-flex items-center gap-2 text-sm text-cyber-muted hover:text-cyber-cyan transition-colors">
          <ArrowLeft className="w-4 h-4" />
          Back to Database
        </Link>
        <GlassCard>
          <div className="text-center py-12">
            <AlertCircle className="w-12 h-12 text-red-400 mx-auto mb-3" />
            <p className="text-red-400 font-mono text-sm">{error}</p>
            <p className="text-cyber-muted/60 text-xs mt-1">Check if the backend server is running</p>
          </div>
        </GlassCard>
      </div>
    );
  }

  if (!person) {
    return (
      <div className="space-y-6">
        <Link to="/persons" className="inline-flex items-center gap-2 text-sm text-cyber-muted hover:text-cyber-cyan transition-colors">
          <ArrowLeft className="w-4 h-4" />
          Back to Database
        </Link>
        <GlassCard>
          <p className="text-center text-cyber-muted py-8">Person not found</p>
        </GlassCard>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <Link to="/persons" className="inline-flex items-center gap-2 text-sm text-cyber-muted hover:text-cyber-cyan transition-colors">
        <ArrowLeft className="w-4 h-4" />
        Back to Database
      </Link>

      <GlassCard>
        <div className="flex flex-col md:flex-row items-start gap-6">
          <motion.div
            initial={{ scale: 0.8, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            className="w-24 h-24 md:w-32 md:h-32 rounded-2xl bg-gradient-to-br from-cyber-cyan to-cyber-blue flex items-center justify-center text-4xl font-bold text-white shadow-[0_0_30px_rgba(0,240,255,0.3)]"
          >
            {person.name.charAt(0)}
          </motion.div>
          <div className="flex-1">
            <div className="flex items-center gap-3 mb-1">
              <h2 className="text-2xl md:text-3xl font-bold text-white">{person.name}</h2>
              <NeonBadge text={`ID: ${person.person_id}`} color="blue" />
            </div>
            <p className="text-cyber-muted mb-3">{person.nickname || "No nickname"} // {person.relationship || "No relationship"}</p>
            <div className="flex flex-wrap gap-2">
              {person.details?.company && <NeonBadge text={person.details.company} color="cyan" />}
              {person.details?.designation && <NeonBadge text={person.details.designation} color="purple" />}
            </div>
          </div>
        </div>
      </GlassCard>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }}>
          <GlassCard>
            <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
              <User className="w-5 h-5 text-cyber-cyan" />
              IDENTITY DETAILS
            </h3>
            <div className="space-y-3">
              {[
                { icon: Phone, label: "Phone", value: person.details?.phone || "—" },
                { icon: Mail, label: "Email", value: person.details?.email || "—" },
                { icon: Building2, label: "Company", value: person.details?.company || "—" },
                { icon: GraduationCap, label: "College", value: person.details?.college || "—" },
                { icon: MapPin, label: "Address", value: person.details?.address || "—" },
                { icon: Calendar, label: "Birthday", value: person.details?.birthday || "—" },
              ].map((item) => (
                <div key={item.label} className="flex items-center justify-between p-3 rounded-lg bg-white/5 border border-white/5">
                  <div className="flex items-center gap-3 text-cyber-muted">
                    <item.icon className="w-4 h-4" />
                    <span className="text-sm">{item.label}</span>
                  </div>
                  <span className="text-sm text-white font-mono">{item.value}</span>
                </div>
              ))}
            </div>
          </GlassCard>
        </motion.div>

        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }}>
          <GlassCard>
            <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
              <Clock className="w-5 h-5 text-cyber-cyan" />
              REGISTERED FACES
            </h3>
            {person.images && person.images.length > 0 ? (
              <div className="grid grid-cols-2 gap-3">
                {person.images.map((img) => (
                  <div key={img.image_id} className="aspect-square rounded-lg bg-black/50 border border-white/10 overflow-hidden">
                    <img src={img.image_path} alt="Face" className="w-full h-full object-cover" />
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-sm text-cyber-muted text-center py-8">No face images registered</p>
            )}
          </GlassCard>
        </motion.div>
      </div>
    </div>
  );
}