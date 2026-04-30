// FANZONE Admin — Status Badge
import { statusColor } from '../../lib/formatters';

interface StatusBadgeProps {
  status: string;
  className?: string;
}

export function StatusBadge({ status, className = '' }: StatusBadgeProps) {
  const color = statusColor(status);
  return (
    <span className={`badge badge-${color} ${className}`}>
      {status.replace(/_/g, ' ')}
    </span>
  );
}
