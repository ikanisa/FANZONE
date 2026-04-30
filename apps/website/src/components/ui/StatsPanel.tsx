import { motion } from 'motion/react';

interface StatItem {
  label: string;
  left: string;
  right: string;
  leftValue: number;
  rightValue: number;
}

interface StatsPanelProps {
  title?: string;
  stats: StatItem[];
}

export function StatsPanel({ title = 'MATCH STATS', stats }: StatsPanelProps) {
  return (
    <div className="bg-surface2 p-6 rounded-2xl border border-border">
      <h3 className="font-display text-xl text-text tracking-widest mb-6">{title}</h3>
      <div className="space-y-4">
        {stats.map((stat, i) => (
          <StatRow key={i} {...stat} />
        ))}
      </div>
    </div>
  );
}

function StatRow({ label, left, right, leftValue, rightValue }: StatItem) {
  const total = leftValue + rightValue;
  const leftPercent = total > 0 ? (leftValue / total) * 100 : 50;
  const rightPercent = total > 0 ? (rightValue / total) * 100 : 50;

  return (
    <div>
      <div className="flex justify-between text-xs font-bold text-text mb-2">
        <span>{left}</span>
        <span className="text-muted">{label}</span>
        <span>{right}</span>
      </div>
      <div className="h-2 bg-surface3 rounded-full overflow-hidden flex">
        <div className="h-full bg-accent" style={{ width: `${leftPercent}%` }}></div>
        <div className="h-full bg-accent2" style={{ width: `${rightPercent}%` }}></div>
      </div>
    </div>
  );
}
