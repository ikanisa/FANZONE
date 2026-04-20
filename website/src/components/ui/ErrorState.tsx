import { motion } from 'motion/react';
import { AlertCircle } from 'lucide-react';

interface ErrorStateProps {
  title: string;
  desc: string;
  onRetry: () => void;
}

export function ErrorState({ title, desc, onRetry }: ErrorStateProps) {
  return (
    <div className="flex flex-col items-center justify-center p-12 text-center">
      <AlertCircle className="text-secondary mb-6" size={48} />
      <h3 className="font-display text-2xl text-text tracking-widest mb-2">{title}</h3>
      <p className="text-muted text-sm max-w-xs mb-8">{desc}</p>
      <button onClick={onRetry} className="bg-secondary/10 hover:bg-secondary/20 text-secondary font-bold px-6 py-3 rounded-xl transition-all border border-secondary/20">
        Retry
      </button>
    </div>
  );
}
