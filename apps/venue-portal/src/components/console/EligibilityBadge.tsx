import type { ReactNode } from 'react';
import { CheckCircle2, Clock3, HelpCircle, ShieldCheck, XCircle } from 'lucide-react';
import { StatusChip } from './StatusChip';

export type EligibilityState =
  | 'eligible'
  | 'order_required'
  | 'ineligible'
  | 'settlement_pending'
  | 'settled';

const eligibilityLabel: Record<EligibilityState, string> = {
  eligible: 'Eligible',
  order_required: 'Order Required',
  ineligible: 'Ineligible',
  settlement_pending: 'Settlement Pending',
  settled: 'Settled',
};

const eligibilityIcon: Record<EligibilityState, ReactNode> = {
  eligible: <CheckCircle2 size={14} />,
  order_required: <Clock3 size={14} />,
  ineligible: <XCircle size={14} />,
  settlement_pending: <HelpCircle size={14} />,
  settled: <ShieldCheck size={14} />,
};

export function EligibilityBadge({
  state,
  detail,
}: {
  state: EligibilityState;
  detail?: string;
}) {
  return (
    <span className="inline-flex flex-col gap-1">
      <span className="inline-flex items-center gap-2">
        {eligibilityIcon[state]}
        <StatusChip status={state} label={eligibilityLabel[state]} />
      </span>
      {detail && <span className="text-xs font-bold text-textSecondary">{detail}</span>}
    </span>
  );
}
