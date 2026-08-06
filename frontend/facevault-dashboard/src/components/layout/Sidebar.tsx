import { NavLink } from "react-router-dom";
import { motion } from "framer-motion";
import {
  LayoutDashboard,
  Users,
  ScanFace,
  Radio,
  History,
  Clock,
  AlertTriangle,
  BarChart3,
  Settings,
  Shield,
  Camera,
} from "lucide-react";

const navItems = [
  { to: "/", icon: LayoutDashboard, label: "Dashboard" },
  { to: "/persons", icon: Users, label: "Persons" },
  { to: "/register-face", icon: ScanFace, label: "Register" },
  { to: "/live", icon: Radio, label: "Live Recognition" },
  { to: "/camera", icon: Camera, label: "Camera" },
  { to: "/logs", icon: History, label: "Logs" },
  { to: "/timeline", icon: Clock, label: "Timeline" },
  { to: "/unknown", icon: AlertTriangle, label: "Unknown" },
  { to: "/analytics", icon: BarChart3, label: "Analytics" },
  { to: "/settings", icon: Settings, label: "Settings" },
];

export default function Sidebar() {
  return (
    <motion.aside
      initial={{ x: -100 }}
      animate={{ x: 0 }}
      className="fixed left-0 top-0 h-full w-20 lg:w-64 glass-panel-strong border-r border-white/5 z-50 flex flex-col"
    >
      <div className="h-16 flex items-center justify-center lg:justify-start lg:px-6 border-b border-white/5">
        <Shield className="w-8 h-8 text-cyber-cyan" />
        <span className="hidden lg:block ml-3 font-bold text-lg tracking-wider neon-text">
          FACEVAULT
        </span>
      </div>

      <nav className="flex-1 py-6 space-y-1 px-2">
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            className={({ isActive }) =>
              `relative flex items-center px-3 py-3 rounded-lg transition-all duration-200 group ${
                isActive
                  ? "bg-cyber-cyan/10 border border-cyber-cyan/30 text-cyber-cyan"
                  : "text-cyber-muted hover:text-white hover:bg-white/5"
              }`
            }
          >
            {({ isActive }) => (
              <>
                <item.icon className="w-5 h-5 lg:mr-3" />
                <span className="hidden lg:block text-sm font-medium">{item.label}</span>
                {isActive && (
                  <motion.div
                    layoutId="activeNav"
                    className="absolute left-0 w-0.5 h-8 bg-cyber-cyan rounded-r-full"
                  />
                )}
              </>
            )}
          </NavLink>
        ))}
      </nav>

      <div className="p-4 border-t border-white/5">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-full bg-gradient-to-br from-cyber-cyan to-cyber-blue" />
          <div className="hidden lg:block">
            <p className="text-sm font-medium text-white">Admin</p>
            <p className="text-xs text-cyber-muted">Online</p>
          </div>
        </div>
      </div>
    </motion.aside>
  );
}