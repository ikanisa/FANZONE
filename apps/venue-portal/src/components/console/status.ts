const toneClass = {
  neutral: 'bg-surface3 text-text border-border',
  success: 'bg-success/10 text-success border-success/20',
  warning: 'bg-warning/10 text-warning border-warning/20',
  danger: 'bg-danger/10 text-danger border-danger/20',
  primary: 'bg-primary/10 text-primary border-primary/20',
} as const;

export type StatusTone = keyof typeof toneClass;

export function statusTone(status: string): StatusTone {
  if ([
    'paid',
    'served',
    'completed',
    'active',
    'endorsed',
    'settled',
    'eligible',
    'open',
    'connected',
  ].includes(status)) return 'success';
  if ([
    'received',
    'accepted',
    'preparing',
    'ready',
    'partially_paid',
    'partial',
    'pending',
    'payment_submitted',
    'submitted',
    'settling',
    'settlement_pending',
    'order_required',
    'needs_order',
  ].includes(status)) return 'warning';
  if ([
    'cancelled',
    'refunded',
    'disputed',
    'rejected',
    'ineligible',
    'disconnected',
  ].includes(status)) return 'danger';
  if (['placed', 'submitted', 'unpaid', 'draft', 'scheduled', 'live'].includes(status)) return 'primary';
  return 'neutral';
}

export function readableStatus(status: string): string {
  return status.replace(/_/g, ' ');
}

export { toneClass };
