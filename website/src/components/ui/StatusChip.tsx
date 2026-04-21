import { motion } from 'motion/react';

interface StatusChipProps {
  label: string;
  variant?: 'success' | 'warning' | 'danger' | 'info';
}

export function StatusChip({ label, variant = 'info' }: StatusChipProps) {
  const variants = {
    success: 'bg-accent/10 text-accent border-accent/20',
    warning: 'bg-yellow-500/10 text-yellow-500 border-yellow-500/20',
    danger: 'bg-accent2/10 text-accent2 border-accent2/20',
    info: 'bg-surface-bright text-text border-outline-variant/20',
  };

  return (
    <span className={`inline-flex items-center px-3 py-1 rounded-full text-[10px] font-bold border ${variants[variant]}`}>
      {label}
    </span>
  );
}
