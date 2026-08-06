import { Bell, Search } from "lucide-react";

export default function Header({ title }: { title: string }) {
  return (
    <header className="h-16 glass-panel border-b border-white/5 flex items-center justify-between px-8 sticky top-0 z-40">
      <div>
        <h1 className="text-xl font-semibold tracking-wide text-white">{title}</h1>
        <p className="text-xs text-cyber-muted font-mono mt-0.5">FACEVAULT AI // SECURE CONNECTION</p>
      </div>
      
      <div className="flex items-center gap-4">
        <div className="relative hidden md:block">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-cyber-muted" />
          <input
            type="text"
            placeholder="Global search..."
            className="bg-white/5 border border-white/10 rounded-lg pl-10 pr-4 py-2 text-sm text-white placeholder:text-cyber-muted focus:outline-none focus:border-cyber-cyan/50 w-64"
          />
        </div>
        <button className="relative p-2 rounded-lg hover:bg-white/5 transition-colors">
          <Bell className="w-5 h-5 text-cyber-muted" />
          <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-cyber-cyan rounded-full animate-pulse" />
        </button>
      </div>
    </header>
  );
}