import type { ReactNode } from 'react';

export function MetricCard({
  label,
  value,
  icon,
  detail,
}: {
  label: string;
  value: string;
  icon: ReactNode;
  detail?: string;
}) {
  return (
    <div className="bg-white border border-border rounded-[24px] p-6 shadow-sm">
      <div className="w-11 h-11 bg-primary/5 text-primary rounded-2xl flex items-center justify-center mb-4">
        {icon}
      </div>
      <p className="text-xs font-bold text-textSecondary uppercase tracking-widest">{label}</p>
      <h3 className="text-3xl font-black text-text mt-1">{value}</h3>
      {detail && <p className="text-sm text-textSecondary font-medium mt-2">{detail}</p>}
    </div>
  );
}
