// FANZONE Admin — Credit / Debit FET Modal
import { useState } from 'react';
import { ArrowDownLeft, ArrowUpRight } from 'lucide-react';

interface CreditDebitModalProps {
  open: boolean;
  mode: 'credit' | 'debit';
  userId: string;
  userName: string;
  onConfirm: (amount: number, reason: string) => void;
  onCancel: () => void;
  isPending: boolean;
}

export function CreditDebitModal({ open, mode, userId, userName, onConfirm, onCancel, isPending }: CreditDebitModalProps) {
  const [amount, setAmount] = useState('');
  const [reason, setReason] = useState('');

  if (!open) return null;

  const isCredit = mode === 'credit';
  const isValid = amount !== '' && Number(amount) > 0 && reason.trim().length >= 3;

  return (
    <div className="modal-overlay" onClick={onCancel}>
      <div className="modal-panel" onClick={e => e.stopPropagation()} style={{ maxWidth: 420 }}>
        <div className="flex items-center gap-3 mb-5">
          <div style={{ color: isCredit ? 'var(--fz-success)' : 'var(--fz-error)', flexShrink: 0 }}>
            {isCredit ? <ArrowDownLeft size={24} /> : <ArrowUpRight size={24} />}
          </div>
          <div>
            <h3 className="text-md font-semibold">{isCredit ? 'Credit' : 'Debit'} FET</h3>
            <p className="text-xs text-muted mt-1">{userName} ({userId})</p>
          </div>
        </div>

        <div className="field-group mb-4">
          <label className="label">Amount (FET)</label>
          <input
            type="number"
            className="input"
            placeholder="Enter amount..."
            min={1}
            value={amount}
            onChange={e => setAmount(e.target.value)}
            autoFocus
          />
        </div>

        <div className="field-group mb-6">
          <label className="label">Reason</label>
          <textarea
            className="input"
            placeholder="Explain why this adjustment is being made..."
            rows={3}
            value={reason}
            onChange={e => setReason(e.target.value)}
            style={{ resize: 'vertical', minHeight: 80 }}
          />
          <span className="text-xs text-muted">Minimum 3 characters. This will be recorded in the audit log.</span>
        </div>

        <div className="flex justify-end gap-3">
          <button className="btn btn-secondary" onClick={onCancel} disabled={isPending}>Cancel</button>
          <button
            className={`btn ${isCredit ? 'btn-primary' : 'btn-danger'}`}
            onClick={() => onConfirm(Number(amount), reason.trim())}
            disabled={!isValid || isPending}
          >
            {isPending ? 'Processing...' : `${isCredit ? 'Credit' : 'Debit'} ${amount ? Number(amount).toLocaleString() : '0'} FET`}
          </button>
        </div>
      </div>
    </div>
  );
}
