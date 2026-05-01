import type { ReactNode } from 'react';

export function EmptyState({
  icon,
  title,
  message,
}: {
  icon: ReactNode;
  title: string;
  message: string;
}) {
  return (
    <div className="bg-white border-2 border-dashed border-border rounded-[28px] p-12 text-center">
      <div className="w-16 h-16 bg-surface2 rounded-2xl flex items-center justify-center text-textSecondary mx-auto mb-5">
        {icon}
      </div>
      <h3 className="text-xl font-black text-text">{title}</h3>
      <p className="text-sm text-textSecondary font-medium mt-2 max-w-md mx-auto">{message}</p>
    </div>
  );
}
