import { motion } from 'motion/react';
import { ReactNode } from 'react';

interface EmptyStateProps {
  icon?: ReactNode;
  title: string;
  desc: string;
  action?: string;
  onAction?: () => void;
}

export function EmptyState({ icon = <span className="text-2xl">📦</span>, title, desc, action, onAction }: EmptyStateProps) {
  return (
    <motion.div 
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      className="flex flex-col items-center justify-center p-8 lg:p-12 text-center bg-surface2 border border-dashed border-border rounded-3xl"
    >
      <div className="w-16 h-16 rounded-full bg-surface3 flex items-center justify-center mb-6 shadow-inner text-muted">
        {icon}
      </div>
      <h3 className="font-display text-2xl text-text tracking-widest mb-2">{title}</h3>
      <p className="text-muted text-sm max-w-sm mb-8">{desc}</p>
      {action && (
        <button onClick={onAction} className="bg-surface3 hover:bg-surface3/80 text-text font-bold px-6 py-3 rounded-xl transition-all border border-border">
          {action}
        </button>
      )}
    </motion.div>
  );
}
