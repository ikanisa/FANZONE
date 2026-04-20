import { useEffect } from 'react';
import { motion } from 'motion/react';
import { useAppStore } from '../store/useAppStore';

export function Splash() {
  const { setHasSeenSplash } = useAppStore();

  useEffect(() => {
    const timer = setTimeout(() => {
      setHasSeenSplash();
    }, 1500);

    return () => clearTimeout(timer);
  }, [setHasSeenSplash]);

  return (
    <div className="fixed inset-0 bg-bg z-[100] flex flex-col items-center justify-center overflow-hidden">
      {/* Background Glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[120vw] h-[120vw] bg-primary/10 rounded-full blur-[100px]" />
      
      <motion.div
        initial={{ scale: 0.8, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
        className="relative z-10 flex flex-col items-center"
      >
        <h1 className="font-display text-6xl text-text tracking-[0.2em] mb-4">
          FAN<span className="text-primary">ZONE</span>
        </h1>
        
        <motion.div 
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.5, duration: 0.5 }}
          className="bg-surface2 border border-border px-4 py-2 rounded-full flex items-center gap-2"
        >
          <div className="w-2 h-2 rounded-full bg-primary animate-pulse" />
          <span className="text-[10px] font-bold text-muted uppercase tracking-widest">
            Malta's Football Fan Network
          </span>
        </motion.div>
      </motion.div>
    </div>
  );
}
