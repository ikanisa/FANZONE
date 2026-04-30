// FANZONE Admin — Detail Drawer
import { X } from 'lucide-react';

interface DetailDrawerProps {
  open: boolean;
  title: string;
  subtitle?: string;
  onClose: () => void;
  actions?: React.ReactNode;
  children: React.ReactNode;
}

export function DetailDrawer({ open, title, subtitle, onClose, actions, children }: DetailDrawerProps) {
  if (!open) return null;

  return (
    <>
      <div className="drawer-overlay" onClick={onClose} />
      <div className="drawer-panel">
        <div className="drawer-header">
          <div>
            <h2 className="text-lg font-semibold">{title}</h2>
            {subtitle && <p className="text-sm text-muted mt-1">{subtitle}</p>}
          </div>
          <div className="flex items-center gap-2">
            {actions}
            <button className="btn btn-ghost btn-icon" onClick={onClose} aria-label="Close">
              <X size={18} />
            </button>
          </div>
        </div>
        <div className="drawer-body">
          {children}
        </div>
      </div>
    </>
  );
}

/* ── Drawer Section helper ── */
interface DrawerSectionProps {
  title: string;
  children: React.ReactNode;
}

export function DrawerSection({ title, children }: DrawerSectionProps) {
  return (
    <div style={{ marginBottom: 'var(--fz-sp-6)' }}>
      <h3 className="text-xs font-semibold text-muted uppercase mb-3" style={{ letterSpacing: '0.05em' }}>{title}</h3>
      {children}
    </div>
  );
}

/* ── Drawer Field ── */
interface DrawerFieldProps {
  label: string;
  value: React.ReactNode;
}

export function DrawerField({ label, value }: DrawerFieldProps) {
  return (
    <div className="flex justify-between items-start py-2 border-b" style={{ borderColor: 'var(--fz-border)' }}>
      <span className="text-sm text-muted">{label}</span>
      <span className="text-sm font-medium" style={{ textAlign: 'right', maxWidth: '60%' }}>{value}</span>
    </div>
  );
}
