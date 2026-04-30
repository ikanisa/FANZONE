// FANZONE Admin — Toast Container
import { useToast } from '../../hooks/useToast';
import { CheckCircle, AlertTriangle, Info, XCircle, X } from 'lucide-react';

const ICONS = {
  success: <CheckCircle size={18} style={{ color: 'var(--fz-success)' }} />,
  error: <XCircle size={18} style={{ color: 'var(--fz-error)' }} />,
  warning: <AlertTriangle size={18} style={{ color: 'var(--fz-warning)' }} />,
  info: <Info size={18} style={{ color: 'var(--fz-info)' }} />,
};

export function ToastContainer() {
  const { toasts, removeToast } = useToast();

  if (toasts.length === 0) return null;

  return (
    <div className="toast-container">
      {toasts.map(toast => (
        <div key={toast.id} className="toast">
          {ICONS[toast.type]}
          <span className="flex-1">{toast.message}</span>
          <button className="btn btn-ghost btn-icon btn-sm" onClick={() => removeToast(toast.id)}>
            <X size={14} />
          </button>
        </div>
      ))}
    </div>
  );
}
