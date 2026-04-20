import { motion } from 'motion/react';

interface Activity {
  timestamp: string;
  action: string;
  actor: string;
}

interface ActivityTimelineProps {
  activities: Activity[];
}

export function ActivityTimeline({ activities }: ActivityTimelineProps) {
  return (
    <div className="space-y-6">
      {activities.map((activity, i) => (
        <div key={i} className="relative pl-8 border-l border-outline-variant/15">
          <div className="absolute -left-1.5 top-1.5 w-3 h-3 rounded-full bg-primary" />
          <div className="text-[10px] text-muted font-mono">{activity.timestamp}</div>
          <div className="text-sm font-bold text-text">{activity.action}</div>
          <div className="text-xs text-muted">by {activity.actor}</div>
        </div>
      ))}
    </div>
  );
}
