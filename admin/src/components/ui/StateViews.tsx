// FANZONE Admin — State Views (Empty, Error, Loading)
import { Inbox, AlertTriangle, Loader } from 'lucide-react';

interface EmptyStateProps {
  icon?: React.ReactNode;
  title?: string;
  description?: string;
  action?: React.ReactNode;
}

export function EmptyState({
  icon = <Inbox size={48} />,
  title = 'No data found',
  description = 'There are no items to display at this time.',
  action,
}: EmptyStateProps) {
  return (
    <div className="state-view">
      {icon}
      <h3>{title}</h3>
      <p>{description}</p>
      {action}
    </div>
  );
}

interface ErrorStateProps {
  title?: string;
  description?: string;
  onRetry?: () => void;
}

export function ErrorState({
  title = 'Something went wrong',
  description = 'An error occurred while loading data. Please try again.',
  onRetry,
}: ErrorStateProps) {
  return (
    <div className="state-view">
      <AlertTriangle size={48} />
      <h3>{title}</h3>
      <p>{description}</p>
      {onRetry && (
        <button className="btn btn-secondary" onClick={onRetry}>Try again</button>
      )}
    </div>
  );
}

interface LoadingStateProps {
  lines?: number;
  fullPage?: boolean;
}

export function LoadingState({ lines = 5, fullPage = false }: LoadingStateProps) {
  if (fullPage) {
    return (
      <div className="state-view">
        <Loader size={32} className="spin" />
        <p>Loading...</p>
        <style>{`
          .spin { animation: spin 1s linear infinite; }
          @keyframes spin { to { transform: rotate(360deg); } }
        `}</style>
      </div>
    );
  }

  const widths = [72, 88, 81, 95, 76, 90, 84, 68];

  return (
    <div className="flex flex-col gap-3 p-5">
      {Array.from({ length: lines }).map((_, i) => (
        <div
          key={i}
          className="skeleton"
          style={{ height: 16, width: `${widths[i % widths.length]}%` }}
        />
      ))}
    </div>
  );
}
