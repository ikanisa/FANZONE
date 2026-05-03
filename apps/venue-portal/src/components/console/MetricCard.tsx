import type { ReactNode } from 'react';
import { clsx } from 'clsx';

type MetricTone = 'neutral' | 'primary' | 'success' | 'warning' | 'danger';

const toneClass: Record<MetricTone, string> = {
  neutral: 'bg-accent/10 text-accent',
  primary: 'bg-primary/10 text-primary',
  success: 'bg-success/10 text-success',
  warning: 'bg-warning/10 text-warning',
  danger: 'bg-danger/10 text-danger',
};

export function MetricCard({
  label,
  value,
  icon,
  detail,
  tone = 'neutral',
  action,
}: {
  label: string;
  value: string;
  icon: ReactNode;
  detail?: string;
  tone?: MetricTone;
  action?: ReactNode;
}) {
  return (
    <div className="bg-surface border border-border rounded-[24px] p-6 shadow-sm">
      <div className="flex items-start justify-between gap-4">
        <div className={clsx('w-12 h-12 rounded-2xl flex items-center justify-center mb-5', toneClass[tone])}>
          {icon}
        </div>
        {action}
      </div>
      <p className="text-sm font-black text-textSecondary uppercase tracking-wide">{label}</p>
      <h3 className="text-4xl font-black text-text mt-2 tracking-tight">{value}</h3>
      {detail && <p className="text-base text-textSecondary font-semibold mt-3">{detail}</p>}
    </div>
  );
}
