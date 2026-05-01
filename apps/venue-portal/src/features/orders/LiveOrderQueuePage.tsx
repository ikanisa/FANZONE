import React, { useMemo, useState } from 'react';
import {
  AlertCircle,
  CheckCircle2,
  Clock3,
  Loader2,
  ReceiptText,
  RefreshCcw,
  XCircle,
} from 'lucide-react';
import type { Order, OrderStatus, PaymentMethod, PaymentStatus } from '@fanzone/core';
import { EmptyState } from '../../components/console/EmptyState';
import { StatusChip } from '../../components/console/StatusChip';
import { readableStatus } from '../../components/console/status';
import { useVenue } from '../../hooks/useVenueContext';
import { useOrders } from '../../hooks/useOrders';

const serviceStatuses: OrderStatus[] = ['placed', 'received', 'served', 'cancelled'];
const paymentStatuses: PaymentStatus[] = ['unpaid', 'paid', 'partially_paid', 'refunded', 'disputed'];
const paymentMethods: PaymentMethod[] = ['cash', 'momo', 'revolut'];

type PaymentDraft = {
  status: PaymentStatus;
  method: PaymentMethod;
  note: string;
};

function formatMoney(order: Order) {
  return `${order.currencyCode} ${order.totalAmount.toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

function tableLabel(order: Order) {
  return order.tableNumber || order.tableId.slice(0, 6).toUpperCase();
}

function ageLabel(date: string) {
  const minutes = Math.max(0, Math.round((Date.now() - new Date(date).getTime()) / 60000));
  if (minutes < 1) return 'now';
  if (minutes < 60) return `${minutes}m`;
  return `${Math.floor(minutes / 60)}h ${minutes % 60}m`;
}

function initialDraft(order: Order): PaymentDraft {
  const status = paymentStatuses.includes(order.paymentStatus)
    ? order.paymentStatus
    : order.paymentStatus === 'pending'
      ? 'unpaid'
      : 'disputed';

  return {
    status,
    method: order.paymentMethod,
    note: '',
  };
}

function OrderCard({
  order,
  draft,
  busy,
  onDraftChange,
  onServiceStatus,
  onPaymentStatus,
}: {
  order: Order;
  draft: PaymentDraft;
  busy: boolean;
  onDraftChange: (next: PaymentDraft) => void;
  onServiceStatus: (status: OrderStatus) => Promise<void>;
  onPaymentStatus: (status: PaymentStatus) => Promise<void>;
}) {
  const canCancel = order.status !== 'cancelled' && order.status !== 'served';
  const canServe = order.status === 'placed' || order.status === 'received';
  const canReceive = order.status === 'placed';

  return (
    <article className="bg-white border border-border rounded-[24px] shadow-sm overflow-hidden">
      <div className="p-5 border-b border-border flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div className="flex items-start gap-4 min-w-0">
          <div className="w-14 h-14 bg-primary text-primaryText rounded-2xl flex items-center justify-center font-black text-lg shrink-0">
            {tableLabel(order)}
          </div>
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="text-2xl font-black tracking-tight">#{order.orderCode}</h2>
              <StatusChip status={order.status} />
              <StatusChip status={draft.status} />
            </div>
            <div className="flex flex-wrap gap-x-4 gap-y-1 text-sm text-textSecondary font-bold mt-2">
              <span>Table {tableLabel(order)}</span>
              <span>{new Date(order.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
              <span>{ageLabel(order.createdAt)}</span>
            </div>
          </div>
        </div>

        <div className="lg:text-right">
          <p className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Total</p>
          <p className="text-2xl font-black text-text">{formatMoney(order)}</p>
          <p className="text-xs font-bold text-textSecondary mt-1">
            +{order.fetEarned.toLocaleString()} FET earned · {order.fetSpent.toLocaleString()} FET spent
          </p>
        </div>
      </div>

      <div className="p-5 grid grid-cols-1 xl:grid-cols-[1fr_360px] gap-6">
        <div>
          <p className="text-[10px] font-black text-textSecondary uppercase tracking-widest mb-3">Items</p>
          <div className="space-y-2">
            {order.items?.length ? (
              order.items.map((item) => (
                <div key={item.id} className="flex justify-between gap-4 rounded-2xl bg-surface2 px-4 py-3">
                  <span className="font-bold text-text">
                    {item.quantity}x {item.itemNameSnapshot}
                  </span>
                  <span className="font-black text-textSecondary">
                    {order.currencyCode} {item.lineTotal.toFixed(2)}
                  </span>
                </div>
              ))
            ) : (
              <div className="rounded-2xl bg-surface2 px-4 py-3 text-sm font-bold text-textSecondary">
                No items attached to this order record.
              </div>
            )}
          </div>
          {order.specialInstructions && (
            <p className="mt-4 rounded-2xl border border-warning/20 bg-warning/10 px-4 py-3 text-sm font-bold text-text">
              {order.specialInstructions}
            </p>
          )}
        </div>

        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-3">
            <label className="space-y-2">
              <span className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Payment</span>
              <select
                className="input"
                value={draft.status}
                onChange={(event) => onDraftChange({ ...draft, status: event.target.value as PaymentStatus })}
              >
                {paymentStatuses.map((status) => (
                  <option key={status} value={status}>{readableStatus(status)}</option>
                ))}
              </select>
            </label>
            <label className="space-y-2">
              <span className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Method</span>
              <select
                className="input"
                value={draft.method}
                onChange={(event) => onDraftChange({ ...draft, method: event.target.value as PaymentMethod })}
              >
                {paymentMethods.map((method) => (
                  <option key={method} value={method}>{readableStatus(method)}</option>
                ))}
              </select>
            </label>
          </div>
          <label className="space-y-2 block">
            <span className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Payment note</span>
            <input
              className="input"
              value={draft.note}
              maxLength={180}
              placeholder="Receipt, USSD ref, Revolut note"
              onChange={(event) => onDraftChange({ ...draft, note: event.target.value })}
            />
          </label>

          <div className="grid grid-cols-2 gap-3">
            {canReceive && (
              <button className="btn btn-secondary" disabled={busy} onClick={() => onServiceStatus('received')}>
                <Clock3 size={16} /> Received
              </button>
            )}
            {canServe && (
              <button className="btn btn-secondary" disabled={busy} onClick={() => onServiceStatus('served')}>
                <CheckCircle2 size={16} /> Served
              </button>
            )}
            {canCancel && (
              <button className="btn bg-danger/10 text-danger border border-danger/20" disabled={busy} onClick={() => onServiceStatus('cancelled')}>
                <XCircle size={16} /> Cancel
              </button>
            )}
            <button className="btn btn-primary" disabled={busy} onClick={() => onPaymentStatus('paid')}>
              <ReceiptText size={16} /> Mark Paid
            </button>
            <button className="btn btn-secondary col-span-2" disabled={busy} onClick={() => onPaymentStatus(draft.status)}>
              Apply Payment Status
            </button>
          </div>
        </div>
      </div>
    </article>
  );
}

export const LiveOrderQueuePage: React.FC = () => {
  const { venue } = useVenue();
  const { orders, loading, error, refresh, updateOrderStatus, updatePaymentStatus } = useOrders(venue?.id || '');
  const [drafts, setDrafts] = useState<Record<string, PaymentDraft>>({});
  const [busyId, setBusyId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const orderDrafts = useMemo(() => {
    const next = { ...drafts };
    for (const order of orders) {
      if (!next[order.id]) next[order.id] = initialDraft(order);
    }
    return next;
  }, [drafts, orders]);

  const activeOrders = orders.filter((order) => order.status === 'placed' || order.status === 'received');
  const counts = serviceStatuses.map((status) => ({
    status,
    count: orders.filter((order) => order.status === status).length,
  }));

  async function runAction(orderId: string, action: () => Promise<void>) {
    setBusyId(orderId);
    setActionError(null);
    try {
      await action();
    } catch (err) {
      setActionError(err instanceof Error ? err.message : 'Action failed.');
    } finally {
      setBusyId(null);
    }
  }

  if (loading && orders.length === 0) {
    return (
      <div className="h-full flex items-center justify-center">
        <Loader2 className="animate-spin text-primary" size={48} />
      </div>
    );
  }

  if (error) {
    return (
      <div className="h-full flex flex-col items-center justify-center text-danger">
        <AlertCircle size={48} />
        <p className="mt-4 font-bold">Failed to load orders: {error}</p>
      </div>
    );
  }

  return (
    <div className="space-y-6 max-w-[1500px] mx-auto">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
        <div>
          <h1 className="text-4xl font-black tracking-tighter">Orders</h1>
          <p className="text-textSecondary font-medium mt-1">
            Live queue with service status, manual payment state, and FET movement.
          </p>
        </div>
        <button type="button" className="btn btn-secondary w-fit" onClick={refresh} disabled={loading}>
          <RefreshCcw size={16} className={loading ? 'animate-spin' : ''} />
          Refresh
        </button>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {counts.map(({ status, count }) => (
          <div key={status} className="bg-white border border-border rounded-2xl p-4">
            <p className="text-[10px] font-black text-textSecondary uppercase tracking-widest">{readableStatus(status)}</p>
            <p className="text-3xl font-black mt-1">{count}</p>
          </div>
        ))}
      </div>

      {actionError && (
        <div className="bg-danger/10 border border-danger/20 text-danger rounded-2xl px-5 py-4 font-bold">
          {actionError}
        </div>
      )}

      {activeOrders.length === 0 && orders.length === 0 ? (
        <EmptyState
          icon={<ReceiptText size={34} />}
          title="No orders in the last 24 hours"
          message="New bar orders will appear here as soon as guests place them."
        />
      ) : (
        <div className="space-y-4">
          {orders.map((order) => {
            const draft = orderDrafts[order.id] ?? initialDraft(order);
            return (
              <OrderCard
                key={order.id}
                order={order}
                draft={draft}
                busy={busyId === order.id}
                onDraftChange={(next) => setDrafts((current) => ({ ...current, [order.id]: next }))}
                onServiceStatus={(status) => runAction(order.id, () => updateOrderStatus(order.id, status))}
                onPaymentStatus={(status) => runAction(
                  order.id,
                  () => updatePaymentStatus(order.id, status, draft.method, draft.note),
                )}
              />
            );
          })}
        </div>
      )}
    </div>
  );
};
