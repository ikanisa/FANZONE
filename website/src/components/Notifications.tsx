import React, { useEffect } from 'react';
import { motion } from 'motion/react';
import { Bell, Trophy, Zap, AlertCircle, Swords, CheckCircle2 } from 'lucide-react';
import { useAppStore } from '../store/useAppStore';
import { Badge } from './ui/Badge';

export default function Notifications() {
  const { notifications, markAllAsRead, markAsRead } = useAppStore();

  useEffect(() => {
    // Mark all as read when the component unmounts
    return () => {
      markAllAsRead();
    };
  }, [markAllAsRead]);

  const getIconForType = (type: string) => {
    switch (type) {
      case 'pool_received':
        return <Swords className="text-accent" size={16} />;
      case 'pool_settled':
        return <Trophy className="text-accent3" size={16} />;
      case 'system':
      default:
        return <Zap className="text-[var(--accent2)]" size={16} />;
    }
  };

  const formatTime = (timestamp: number) => {
    const diff = Date.now() - timestamp;
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (days > 0) return `${days}d`;
    if (hours > 0) return `${hours}h`;
    if (minutes > 0) return `${minutes}m`;
    return 'Now';
  };

  return (
    <div className="min-h-screen bg-bg p-5 lg:p-12 pb-24">
      <header className="mb-6 flex items-center justify-between">
        <h1 className="font-display text-4xl text-text tracking-tight flex items-center gap-2">
          Inbox
        </h1>
        <button 
          onClick={markAllAsRead}
          className="w-10 h-10 rounded-full bg-surface2 border border-border text-muted hover:text-text flex items-center justify-center transition-colors"
        >
          <CheckCircle2 size={18} />
        </button>
      </header>

      <div className="space-y-2">
        {notifications.length === 0 ? (
          <div className="text-center py-12 text-muted">
            <Bell className="mx-auto mb-4 opacity-50" size={32} />
            <p className="text-sm font-bold">Nothing here</p>
          </div>
        ) : (
          notifications.map((notification) => (
            <NotificationItem 
              key={notification.id}
              icon={getIconForType(notification.type)} 
              title={notification.title} 
              desc={notification.message} 
              time={formatTime(notification.timestamp)} 
              unread={!notification.read} 
              onClick={() => markAsRead(notification.id)}
            />
          ))
        )}
      </div>
    </div>
  );
}

function NotificationItem({ icon, title, desc, time, unread = false, onClick }: { icon: React.ReactNode; title: string; desc: string; time: string; unread?: boolean; onClick?: () => void }) {
  return (
    <div 
      onClick={onClick}
      className={`bg-surface p-3 rounded-2xl border flex items-center gap-3 transition-colors cursor-pointer group hover:bg-surface2 ${unread ? 'border-accent/40 bg-accent/5' : 'border-border'}`}
    >
      <div className={`w-10 h-10 rounded-full flex justify-center items-center shrink-0 border ${unread ? 'bg-accent/10 border-accent/20' : 'bg-surface2 border-border'}`}>
        {icon}
      </div>
      <div className="flex-1 min-w-0">
        <div className="flex justify-between items-center mb-0.5">
          <span className="text-sm font-bold text-text truncate pr-2 group-hover:text-accent transition-colors">{title}</span>
          <span className="text-[10px] font-bold text-muted uppercase shrink-0">{time}</span>
        </div>
        <p className="text-xs text-muted truncate">{desc}</p>
      </div>
      {unread && <div className="w-2 h-2 rounded-full bg-accent shrink-0"></div>}
    </div>
  );
}
