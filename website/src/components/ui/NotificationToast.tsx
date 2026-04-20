import { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Bell, Trophy, Swords } from 'lucide-react';
import { useAppStore, type AppNotification } from '../../store/useAppStore';

export function NotificationToast() {
  const { notifications } = useAppStore();
  const [activeToast, setActiveToast] = useState<AppNotification | null>(null);

  useEffect(() => {
    // Find the newest unread notification
    const newestUnread = notifications.find(n => !n.read);
    
    if (newestUnread && (!activeToast || newestUnread.id !== activeToast.id)) {
      // Only show toast if it's less than 5 seconds old
      if (Date.now() - newestUnread.timestamp < 5000) {
        setActiveToast(newestUnread);
        
        // Auto-hide after 4 seconds
        const timer = setTimeout(() => {
          setActiveToast(null);
        }, 4000);
        
        return () => clearTimeout(timer);
      }
    }
  }, [notifications, activeToast]);

  const getIcon = (type: string) => {
    switch (type) {
      case 'pool_received':
        return <Swords className="text-primary" size={20} />;
      case 'pool_settled':
        return <Trophy className="text-secondary" size={20} />;
      case 'system':
      default:
        return <Bell className="text-muted" size={20} />;
    }
  };

  return (
    <AnimatePresence>
      {activeToast && (
        <motion.div
          initial={{ opacity: 0, y: -50, scale: 0.9 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: -20, scale: 0.9 }}
          className="fixed top-4 left-4 right-4 md:left-auto md:right-4 md:w-96 z-[100] bg-surface2 border border-primary/30 rounded-2xl p-4 shadow-2xl flex gap-4 cursor-pointer"
          onClick={() => setActiveToast(null)}
        >
          <div className="mt-1 bg-surface3 p-2 rounded-full shrink-0">
            {getIcon(activeToast.type)}
          </div>
          <div className="flex-1">
            <h4 className="text-sm font-bold text-text mb-1">{activeToast.title}</h4>
            <p className="text-xs text-muted line-clamp-2">{activeToast.message}</p>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
