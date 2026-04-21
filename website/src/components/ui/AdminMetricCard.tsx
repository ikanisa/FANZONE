import { motion } from 'motion/react';

interface AdminMetricCardProps {
  label: string;
  value: string;
  trend?: string;
  trendUp?: boolean;
}

export function AdminMetricCard({ label, value, trend, trendUp }: AdminMetricCardProps) {
  return (
    <motion.div 
      whileHover={{ scale: 1.02 }}
      className="bg-surface-container-highest p-6 rounded-3xl border border-outline-variant/15 shadow-lg"
    >
      <div className="text-xs font-bold text-muted uppercase tracking-widest mb-2">{label}</div>
      <div className="font-mono text-3xl font-bold text-text">{value}</div>
      {trend && (
        <div className={`text-xs font-bold mt-2 ${trendUp ? 'text-accent' : 'text-accent2'}`}>
          {trend}
        </div>
      )}
    </motion.div>
  );
}
