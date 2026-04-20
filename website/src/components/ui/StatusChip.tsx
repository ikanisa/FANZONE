interface StatusChipProps {
  label: string;
  variant?: 'success' | 'warning' | 'danger' | 'info';
}

export function StatusChip({ label, variant = 'info' }: StatusChipProps) {
  const variants = {
    success: 'bg-primary/10 text-primary border-primary/20',
    warning: 'bg-secondary/10 text-secondary border-secondary/20',
    danger: 'bg-danger/10 text-danger border-danger/20',
    info: 'bg-primary/10 text-text border-primary/20',
  };

  return (
    <span className={`inline-flex items-center px-3 py-1 rounded-full text-[10px] font-bold border ${variants[variant]}`}>
      {label}
    </span>
  );
}
