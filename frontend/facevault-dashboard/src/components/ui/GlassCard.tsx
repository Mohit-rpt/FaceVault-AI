import { motion } from "framer-motion";
import type { ReactNode } from "react";

interface Props {
  children: ReactNode;
  className?: string;
  delay?: number;
  hover?: boolean;
}

export default function GlassCard({ children, className = "", delay = 0, hover = true }: Props) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, delay }}
      className={`glass-panel p-6 ${hover ? "hover:border-cyber-cyan/40 transition-all duration-300" : ""} ${className}`}
    >
      {children}
    </motion.div>
  );
}