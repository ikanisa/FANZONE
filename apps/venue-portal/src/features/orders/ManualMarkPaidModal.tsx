import { useMemo, useState } from 'react';
import type { Order, PaymentMethod } from '@fanzone/core';
import { AlertTriangle, CheckCircle2, X } from 'lucide-react';

const paymentMethods: Array<{ value: PaymentMethod; label: string; detail: string }> = [
  { value: 'momo', label: 'MoMo USSD', detail: 'External mobile-money confirmation' },
  { value: 'revolut', label: 'Revolut link', detail: 'External Revolut payment link' },
  { value: 'cash', label: 'Cash', detail: 'Cash collected by staff' },
  { value: 'card', label: 'Card', detail: 'Card payment confirmed manually' },
  { value: 'other', label: 'Other', detail: 'Other externally verified payment' },
];

function formatMoney(order: Order) {
  return `${order.currencyCode} ${order.totalAmount.toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

function userCode(order: Order) {
  return (order.userId ?? order.id).replace(/-/g, '').slice(-6).toUpperCase();
}

export function ManualMarkPaidModal({
  order,
  saving,
  error,
  onClose,
  onConfirm,
}: {
  order: Order | null;
  saving: boolean;
  error: string | null;
  onClose: () => void;
  onConfirm: (details: {
    amountReceived: number;
    method: PaymentMethod;
    reference: string;
    note: string;
  }) => Promise<void>;
}) {
  if (!order) return null;

  return (
    <ManualMarkPaidModalContent
      key={order.id}
      order={order}
      saving={saving}
      error={error}
      onClose={onClose}
      onConfirm={onConfirm}
    />
  );
}

function ManualMarkPaidModalContent({
  order,
  saving,
  error,
  onClose,
  onConfirm,
}: {
  order: Order;
  saving: boolean;
  error: string | null;
  onClose: () => void;
  onConfirm: (details: {
    amountReceived: number;
    method: PaymentMethod;
    reference: string;
    note: string;
  }) => Promise<void>;
}) {
  const [amountReceived, setAmountReceived] = useState(order.totalAmount.toFixed(2));
  const [method, setMethod] = useState<PaymentMethod>(order.paymentMethod);
  const [reference, setReference] = useState('');
  const [note, setNote] = useState('');
  const [staffConfirmed, setStaffConfirmed] = useState(false);

  const parsedAmount = useMemo(() => Number(amountReceived), [amountReceived]);
  const canConfirm = Number.isFinite(parsedAmount) && parsedAmount >= 0 && staffConfirmed && !saving;

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/70 p-0 md:items-center md:p-6">
      <section className="w-full max-w-3xl rounded-t-[28px] border border-border bg-surface shadow-2xl shadow-black/50 md:rounded-[28px]">
        <div className="flex items-start justify-between gap-5 border-b border-border p-6">
          <div>
            <p className="text-sm font-black uppercase tracking-wide text-primary">Manual payment confirmation</p>
            <h2 className="mt-2 text-3xl font-black tracking-tight">Mark order #{order.orderCode} paid</h2>
            <p className="mt-2 text-base font-semibold text-textSecondary">
              User {userCode(order)} | Total due {formatMoney(order)}
            </p>
          </div>
          <button
            type="button"
            className="h-11 w-11 rounded-2xl bg-surface2 text-textSecondary hover:bg-surface3 hover:text-text flex items-center justify-center"
            onClick={onClose}
            aria-label="Close payment confirmation"
          >
            <X size={20} />
          </button>
        </div>

        <div className="grid grid-cols-1 gap-6 p-6 lg:grid-cols-[1fr_260px]">
          <div className="space-y-5">
            <label className="block space-y-2">
              <span className="text-sm font-black uppercase tracking-wide text-textSecondary">Amount received</span>
              <input
                className="input text-lg"
                type="number"
                min={0}
                step={0.01}
                value={amountReceived}
                onChange={(event) => setAmountReceived(event.target.value)}
              />
            </label>

            <fieldset className="space-y-3">
              <legend className="text-sm font-black uppercase tracking-wide text-textSecondary">Payment method</legend>
              <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
                {paymentMethods.map((item) => (
                  <label
                    key={item.value}
                    className={`cursor-pointer rounded-2xl border p-4 transition-colors ${
                      method === item.value
                        ? 'border-primary bg-primary/10'
                        : 'border-border bg-surface2 hover:bg-surface3'
                    }`}
                  >
                    <input
                      className="sr-only"
                      type="radio"
                      name="payment-method"
                      value={item.value}
                      checked={method === item.value}
                      onChange={() => setMethod(item.value)}
                    />
                    <span className="block text-base font-black">{item.label}</span>
                    <span className="mt-1 block text-sm font-bold text-textSecondary">{item.detail}</span>
                  </label>
                ))}
              </div>
            </fieldset>

            <label className="block space-y-2">
              <span className="text-sm font-black uppercase tracking-wide text-textSecondary">Reference</span>
              <input
                className="input"
                value={reference}
                maxLength={120}
                placeholder="USSD ref, Revolut note, till receipt, or staff reference"
                onChange={(event) => setReference(event.target.value)}
              />
            </label>

            <label className="block space-y-2">
              <span className="text-sm font-black uppercase tracking-wide text-textSecondary">Staff note</span>
              <textarea
                className="input min-h-24 resize-none"
                value={note}
                maxLength={240}
                placeholder="Optional operational note"
                onChange={(event) => setNote(event.target.value)}
              />
            </label>
          </div>

          <aside className="space-y-4">
            <div className="rounded-2xl border border-warning/20 bg-warning/10 p-4">
              <div className="flex items-center gap-2 text-warning">
                <AlertTriangle size={18} />
                <p className="font-black">This action will be logged.</p>
              </div>
              <p className="mt-3 text-sm font-bold leading-6 text-text">
                Confirmation writes a payment event, updates order payment status, and may unlock linked FET eligibility.
              </p>
            </div>

            <div className="rounded-2xl border border-border bg-surface2 p-4">
              <p className="text-sm font-black uppercase tracking-wide text-textSecondary">Eligibility update</p>
              <p className="mt-2 text-base font-black">
                Paid orders can make this user eligible for linked FET settlement.
              </p>
            </div>

            <label className="flex items-start gap-3 rounded-2xl border border-border bg-surface2 p-4">
              <input
                className="mt-1 h-5 w-5 accent-primary"
                type="checkbox"
                checked={staffConfirmed}
                onChange={(event) => setStaffConfirmed(event.target.checked)}
              />
              <span className="text-sm font-bold leading-6 text-text">
                I confirm the external payment was received and this manual action is accurate.
              </span>
            </label>
          </aside>
        </div>

        {error && (
          <div className="mx-6 mb-4 rounded-2xl border border-danger/20 bg-danger/10 px-4 py-3 text-sm font-bold text-danger">
            {error}
          </div>
        )}

        <div className="flex flex-col-reverse gap-3 border-t border-border p-6 md:flex-row md:justify-end">
          <button type="button" className="btn btn-secondary" onClick={onClose} disabled={saving}>
            Cancel
          </button>
          <button
            type="button"
            className="btn btn-primary"
            disabled={!canConfirm}
            onClick={() =>
              onConfirm({
                amountReceived: parsedAmount,
                method,
                reference,
                note,
              })
            }
          >
            <CheckCircle2 size={17} />
            {saving ? 'Confirming...' : 'Confirm paid'}
          </button>
        </div>
      </section>
    </div>
  );
}
