import React, { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  AlertCircle,
  BellRing,
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
import { useBellRequests } from '../../hooks/useBellRequests';
import { useOrders } from '../../hooks/useOrders';
import { ManualMarkPaidModal } from './ManualMarkPaidModal';
import type { BellRequest } from '../../services/venueOperations';

const activeServiceStatuses: OrderStatus[] = ['placed', 'received', 'preparing'];
const serviceStatuses: OrderStatus[] = ['placed', 'received', 'preparing', 'served', 'cancelled'];
const paymentStatuses: PaymentStatus[] = [
  'unpaid',
  'payment_submitted',
  'paid',
  'partially_paid',
  'refunded',
  'disputed',
];
const paymentMethods: PaymentMethod[] = ['momo', 'revolut', 'cash', 'card', 'other'];

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

function userCode(order: Order) {
  return (order.userId ?? order.id).replace(/-/g, '').slice(-6).toUpperCase();
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
  onMarkPaid,
}: {
  order: Order;
  draft: PaymentDraft;
  busy: boolean;
  onDraftChange: (next: PaymentDraft) => void;
  onServiceStatus: (status: OrderStatus) => Promise<void>;
  onPaymentStatus: (status: PaymentStatus) => Promise<void>;
  onMarkPaid: () => void;
}) {
  const canCancel = order.status !== 'cancelled' && order.status !== 'served';
  const canPrepare = order.status === 'received';
  const canServe = order.status === 'received' || order.status === 'preparing';
  const canReceive = order.status === 'placed';
  const canMarkPaid = order.status !== 'cancelled' && draft.status !== 'paid';

  return (
    <article className="ops-card overflow-hidden">
      <div className="p-5 border-b border-border flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div className="flex items-start gap-4 min-w-0">
          <div className="w-16 h-16 bg-primary text-primaryText rounded-2xl flex items-center justify-center font-black text-xl shrink-0">
            {tableLabel(order)}
          </div>
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="text-3xl font-black tracking-tight">#{order.orderCode}</h2>
              <StatusChip status={order.status} />
              <StatusChip status={draft.status} />
            </div>
            <div className="flex flex-wrap gap-x-4 gap-y-1 text-sm text-textSecondary font-bold mt-2">
              <span>User {userCode(order)}</span>
              <span>Table {tableLabel(order)}</span>
              <span>{new Date(order.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
              <span>{ageLabel(order.createdAt)}</span>
            </div>
          </div>
        </div>

        <div className="lg:text-right">
          <p className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Total</p>
          <p className="text-3xl font-black text-text">{formatMoney(order)}</p>
          <p className="text-xs font-bold text-textSecondary mt-1">
            +{order.fetEarned.toLocaleString()} FET earned | {order.fetSpent.toLocaleString()} FET spent
          </p>
        </div>
      </div>

      <div className="p-5 grid grid-cols-1 xl:grid-cols-[1fr_360px] gap-6">
        <div>
          <p className="text-[10px] font-black text-textSecondary uppercase tracking-widest mb-3">Items</p>
          <div className="space-y-2">
            {order.items?.length ? (
              order.items.map((item) => (
                <div key={item.id} className="flex justify-between gap-4 rounded-xl bg-surface2 px-4 py-3">
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
                <Clock3 size={16} /> Mark received
              </button>
            )}
            {canPrepare && (
              <button className="btn btn-secondary" disabled={busy} onClick={() => onServiceStatus('preparing')}>
                <Clock3 size={16} /> Preparing
              </button>
            )}
            {canServe && (
              <button className="btn btn-secondary" disabled={busy} onClick={() => onServiceStatus('served')}>
                <CheckCircle2 size={16} /> Serve order
              </button>
            )}
            {canCancel && (
              <button className="btn bg-danger/10 text-danger border border-danger/20" disabled={busy} onClick={() => onServiceStatus('cancelled')}>
                <XCircle size={16} /> Cancel
              </button>
            )}
            <button className="btn btn-primary" disabled={busy || !canMarkPaid} onClick={onMarkPaid}>
              <ReceiptText size={16} /> Mark paid
            </button>
            <Link className="btn btn-secondary" to={`/orders/${order.id}`}>
              View Details
            </Link>
            <button className="btn btn-secondary col-span-2" disabled={busy} onClick={() => onPaymentStatus(draft.status)}>
              Save payment status
            </button>
          </div>
        </div>
      </div>
    </article>
  );
}

function BellRequestPanel({
  bells,
  busyId,
  onAcknowledge,
}: {
  bells: BellRequest[];
  busyId: string | null;
  onAcknowledge: (bellId: string) => Promise<void>;
}) {
  if (bells.length === 0) return null;

  return (
    <section className="ops-card border-warning/30 bg-warning/10 p-5">
      <div className="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
        <div className="flex items-center gap-3">
          <div className="h-12 w-12 rounded-2xl bg-warning/20 text-warning flex items-center justify-center">
            <BellRing size={24} />
          </div>
          <div>
            <p className="text-[10px] font-black text-warning uppercase tracking-widest">Staff requests</p>
            <h2 className="text-2xl font-black text-text">{bells.length} active bell{bells.length === 1 ? '' : 's'}</h2>
          </div>
        </div>
        <p className="text-sm font-bold text-textSecondary">Acknowledge requests once staff has responded.</p>
      </div>

      <div className="mt-4 grid gap-3 xl:grid-cols-2">
        {bells.map((bell) => (
          <article key={bell.id} className="rounded-2xl border border-border bg-surface/80 p-4 flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
            <div>
              <p className="text-lg font-black text-text">
                Table {bell.tableNumber ?? bell.tableId.slice(0, 6).toUpperCase()}
              </p>
              <p className="text-sm font-bold text-textSecondary">
                {ageLabel(bell.createdAt)} ago · User {bell.userId.replace(/-/g, '').slice(-6).toUpperCase()}
              </p>
              {bell.message && <p className="mt-2 text-sm font-bold text-text">{bell.message}</p>}
            </div>
            <button
              type="button"
              className="btn btn-primary"
              disabled={busyId === bell.id}
              onClick={() => onAcknowledge(bell.id)}
            >
              {busyId === bell.id ? <Loader2 size={16} className="animate-spin" /> : <CheckCircle2 size={16} />}
              Acknowledge
            </button>
          </article>
        ))}
      </div>
    </section>
  );
}

export const LiveOrderQueuePage: React.FC = () => {
  const { venue } = useVenue();
  const { orders, loading, error, refresh, updateOrderStatus, updatePaymentStatus } = useOrders(venue?.id || '');
  const {
    bells,
    loading: bellsLoading,
    error: bellsError,
    refresh: refreshBells,
    acknowledge,
  } = useBellRequests(venue?.id || '');
  const [drafts, setDrafts] = useState<Record<string, PaymentDraft>>({});
  const [busyId, setBusyId] = useState<string | null>(null);
  const [busyBellId, setBusyBellId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [markPaidOrder, setMarkPaidOrder] = useState<Order | null>(null);
  const [markPaidError, setMarkPaidError] = useState<string | null>(null);

  const orderDrafts = useMemo(() => {
    const next = { ...drafts };
    for (const order of orders) {
      if (!next[order.id]) next[order.id] = initialDraft(order);
    }
    return next;
  }, [drafts, orders]);

  const activeOrders = orders.filter((order) => activeServiceStatuses.includes(order.status));
  const visibleOrders = useMemo(
    () =>
      [...orders].sort((a, b) => {
        const aActive = activeServiceStatuses.includes(a.status);
        const bActive = activeServiceStatuses.includes(b.status);
        if (aActive !== bActive) return aActive ? -1 : 1;
        return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
      }),
    [orders],
  );
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

  async function runBellAction(bellId: string) {
    setBusyBellId(bellId);
    setActionError(null);
    try {
      await acknowledge(bellId);
    } catch (err) {
      setActionError(err instanceof Error ? err.message : 'Could not acknowledge bell request.');
    } finally {
      setBusyBellId(null);
    }
  }

  async function confirmPaid(details: {
    amountReceived: number;
    method: PaymentMethod;
    reference: string;
    note: string;
  }) {
    if (!markPaidOrder) return;
    setBusyId(markPaidOrder.id);
    setMarkPaidError(null);
    setActionError(null);
    try {
      await updatePaymentStatus(markPaidOrder.id, 'paid', details.method, details.note, {
        amountReceived: details.amountReceived,
        externalReference: details.reference,
      });
      setMarkPaidOrder(null);
    } catch (err) {
      setMarkPaidError(err instanceof Error ? err.message : 'Could not mark order paid.');
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
            Handle live service and manual payment confirmation in seconds.
          </p>
        </div>
        <button
          type="button"
          className="btn btn-secondary w-fit"
          onClick={() => {
            void refresh();
            void refreshBells();
          }}
          disabled={loading || bellsLoading}
        >
          <RefreshCcw size={16} className={loading || bellsLoading ? 'animate-spin' : ''} />
          Refresh
        </button>
      </div>

      <BellRequestPanel bells={bells} busyId={busyBellId} onAcknowledge={runBellAction} />

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {counts.map(({ status, count }) => (
          <div key={status} className="ops-panel p-4">
            <p className="text-[10px] font-black text-textSecondary uppercase tracking-widest">{readableStatus(status)}</p>
            <p className="text-3xl font-black mt-1">{count}</p>
          </div>
        ))}
      </div>

      <div className="ops-card px-5 py-4 flex flex-col gap-2 md:flex-row md:items-center md:justify-between border-accent/25 bg-accent/10">
        <div>
          <p className="text-[10px] font-black text-accent uppercase tracking-widest">Priority queue</p>
          <p className="text-2xl font-black text-text">{activeOrders.length} active orders</p>
        </div>
        <p className="text-sm font-bold text-textSecondary">
          New and received orders stay at the top until served or cancelled.
        </p>
      </div>

      {actionError && (
        <div className="bg-danger/10 border border-danger/20 text-danger rounded-2xl px-5 py-4 font-bold">
          {actionError}
        </div>
      )}
      {bellsError && (
        <div className="bg-warning/10 border border-warning/20 text-warning rounded-2xl px-5 py-4 font-bold">
          Failed to load bell requests: {bellsError}
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
          {visibleOrders.map((order) => {
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
                onMarkPaid={() => {
                  setMarkPaidError(null);
                  setMarkPaidOrder(order);
                }}
              />
            );
          })}
        </div>
      )}
      <ManualMarkPaidModal
        order={markPaidOrder}
        saving={!!markPaidOrder && busyId === markPaidOrder.id}
        error={markPaidError}
        onClose={() => {
          if (busyId) return;
          setMarkPaidOrder(null);
          setMarkPaidError(null);
        }}
        onConfirm={confirmPaid}
      />
    </div>
  );
};
