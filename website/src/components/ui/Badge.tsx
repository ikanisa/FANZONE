import React from 'react';

type BadgeVariant =
  | 'default'
  | 'primary'
  | 'secondary'
  | 'success'
  | 'danger'
  | 'outline'
  | 'ghost';

interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  variant?: BadgeVariant;
  pulse?: boolean;
}

export function Badge({ children, variant = 'default', pulse = false, className = '', ...props }: BadgeProps) {
  let variantClasses = '';
  switch (variant) {
    case 'primary': variantClasses = 'bg-primary/10 text-primary border border-primary/20 [text-shadow:0_0_10px_rgba(152,255,152,0.2)]'; break;
    case 'secondary': variantClasses = 'bg-secondary/10 text-secondary border border-secondary/20'; break;
    case 'success': variantClasses = 'bg-success/10 text-success border border-success/20 [text-shadow:0_0_10px_rgba(152,255,152,0.2)]'; break;
    case 'danger': variantClasses = 'bg-danger/10 text-danger border border-danger/20'; break;
    case 'outline': variantClasses = 'bg-transparent text-text border border-border'; break;
    case 'ghost': variantClasses = 'bg-surface3 text-muted border border-transparent'; break;
    default: variantClasses = 'bg-surface2 text-text border border-border bg-opacity-50'; break;
  }

  let pulseColor = 'bg-current';
  if (variant === 'primary') pulseColor = 'bg-primary shadow-[0_0_8px_rgba(152,255,152,0.6)]';
  if (variant === 'secondary') pulseColor = 'bg-secondary shadow-[0_0_8px_rgba(255,127,80,0.6)]';
  if (variant === 'success') pulseColor = 'bg-success shadow-[0_0_8px_rgba(152,255,152,0.6)]';
  if (variant === 'danger') pulseColor = 'bg-danger shadow-[0_0_8px_rgba(239,68,68,0.6)]';

  return (
    <span 
      className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-widest ${variantClasses} ${className}`}
      {...props}
    >
      {pulse && <span className={`w-1.5 h-1.5 rounded-full animate-pulse ${pulseColor}`}></span>}
      {children}
    </span>
  );
}
