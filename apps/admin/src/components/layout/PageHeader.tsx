import type { ReactNode } from "react";

// FANZONE Admin — Page Header
interface PageHeaderProps {
  title: string;
  subtitle?: ReactNode;
  actions?: ReactNode;
}

export function PageHeader({ title, subtitle, actions }: PageHeaderProps) {
  return (
    <div className="page-header">
      <div>
        <h1 className="page-title">{title}</h1>
        {subtitle && <p className="page-subtitle">{subtitle}</p>}
      </div>
      {actions && <div className="page-actions">{actions}</div>}

      <style>{`
        .page-header {
          display: flex;
          align-items: flex-start;
          justify-content: space-between;
          gap: var(--fz-sp-4);
          margin-bottom: var(--fz-sp-6);
        }
        .page-title {
          font-size: var(--fz-text-2xl);
          font-weight: 700;
          color: var(--fz-text);
          line-height: 1.2;
        }
        .page-subtitle {
          font-size: var(--fz-text-sm);
          color: var(--fz-muted);
          margin-top: var(--fz-sp-1);
        }
        .page-actions {
          display: flex;
          align-items: center;
          gap: var(--fz-sp-3);
          flex-shrink: 0;
        }
      `}</style>
    </div>
  );
}
