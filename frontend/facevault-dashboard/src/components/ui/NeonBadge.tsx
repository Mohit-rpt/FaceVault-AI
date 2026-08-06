interface Props {
  text: string;
  color?: "cyan" | "blue" | "green" | "red" | "purple";
}

const colors = {
  cyan: "bg-cyber-cyan/10 text-cyber-cyan border-cyber-cyan/30",
  blue: "bg-blue-500/10 text-blue-400 border-blue-500/30",
  green: "bg-emerald-500/10 text-emerald-400 border-emerald-500/30",
  red: "bg-red-500/10 text-red-400 border-red-500/30",
  purple: "bg-purple-500/10 text-purple-400 border-purple-500/30",
};

export default function NeonBadge({ text, color = "cyan" }: Props) {
  return (
    <span className={`px-2.5 py-0.5 rounded-full text-xs font-mono font-medium border ${colors[color]}`}>
      {text}
    </span>
  );
}