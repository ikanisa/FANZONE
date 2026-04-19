// FANZONE Admin — KPI Card
import { TrendingUp, TrendingDown, Minus } from 'lucide-react';
import { formatNumber } from '../../lib/formatters';

interface KpiCardProps {
  label: string;
  value: number | string;
  trend?: number;
  trendDirection?: 'up' | 'down' | 'neutral';
  icon?: React.ReactNode;
  format?: 'number' | 'fet' | 'raw';
}

export function KpiCard({ label, value, trend, trendDirection = 'neutral', icon, format = 'number' }: KpiCardProps) {
  const displayValue = typeof value === 'string' ? value :
    format === 'fet' ? `${formatNumber(value)} FET` :
    format === 'number' ? formatNumber(value) : value;

  return (
    <div className="kpi-card">
      <div className="flex items-center justify-between">
        <span className="kpi-label">{label}</span>
        {icon && <span className="text-muted">{icon}</span>}
      </div>
      <div className="kpi-value">{displayValue}</div>
      {trend !== undefined && (
        <div className={`kpi-trend ${trendDirection}`}>
          {trendDirection === 'up' && <TrendingUp size={14} />}
          {trendDirection === 'down' && <TrendingDown size={14} />}
          {trendDirection === 'neutral' && <Minus size={14} />}
          <span>{trend > 0 ? '+' : ''}{trend}%</span>
        </div>
      )}
    </div>
  );
}
