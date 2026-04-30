import React from 'react';

// To be safe, I'll write standard class merging
export function Card({ children, className = '', ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div 
      className={`bg-surface border border-border rounded-3xl p-5 overflow-hidden transition-all duration-200 ${className}`}
      {...props}
    >
      {children}
    </div>
  );
}
