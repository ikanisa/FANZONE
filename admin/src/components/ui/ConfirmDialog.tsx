// FANZONE Admin — Confirm Dialog
import { AlertTriangle } from 'lucide-react';

interface ConfirmDialogProps {
  open: boolean;
  title: string;
  description: string;
  confirmLabel?: string;
  danger?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

export function ConfirmDialog({
  open, title, description, confirmLabel = 'Confirm', danger = false, onConfirm, onCancel,
}: ConfirmDialogProps) {
  if (!open) return null;

  return (
    <div className="modal-overlay" onClick={onCancel}>
      <div className="modal-panel" onClick={e => e.stopPropagation()}>
        <div className="flex items-start gap-4 mb-4">
          {danger && (
            <div style={{ color: 'var(--fz-error)', flexShrink: 0 }}>
              <AlertTriangle size={24} />
            </div>
          )}
          <div>
            <h3 className="text-md font-semibold mb-1">{title}</h3>
            <p className="text-sm text-muted">{description}</p>
          </div>
        </div>
        <div className="flex justify-end gap-3">
          <button className="btn btn-secondary" onClick={onCancel}>Cancel</button>
          <button className={`btn ${danger ? 'btn-danger' : 'btn-primary'}`} onClick={onConfirm}>
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
