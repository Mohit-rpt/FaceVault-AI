import { Outlet } from "react-router-dom";
import { AnimatePresence, motion } from "framer-motion";
import Sidebar from "./Sidebar";
import Header from "./Header";
import CyberGrid from "../three/CyberGrid";
import { useLocation } from "react-router-dom";

export default function Layout() {
  const location = useLocation();
  
  const getTitle = (path: string) => {
    const titles: Record<string, string> = {
      "/": "COMMAND CENTER",
      "/persons": "IDENTITY DATABASE",
      "/register-face": "BIOMETRIC REGISTRATION",
      "/live": "LIVE SURVEILLANCE",
      "/logs": "RECOGNITION LOGS",
      "/timeline": "INTERACTION TIMELINE",
      "/unknown": "UNKNOWN FACES",
      "/analytics": "THREAT ANALYTICS",
      "/settings": "SYSTEM CONFIG",
    };
    return titles[path] || "FACEVAULT AI";
  };

  return (
    <div className="min-h-screen bg-cyber-black text-white grid-bg">
      <CyberGrid />
      <Sidebar />
      <div className="lg:ml-64 ml-20 min-h-screen flex flex-col">
        <Header title={getTitle(location.pathname)} />
        <main className="flex-1 p-6 lg:p-8 overflow-auto">
          <AnimatePresence mode="wait">
            <motion.div
              key={location.pathname}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              transition={{ duration: 0.3 }}
            >
              <Outlet />
            </motion.div>
          </AnimatePresence>
        </main>
      </div>
    </div>
  );
}