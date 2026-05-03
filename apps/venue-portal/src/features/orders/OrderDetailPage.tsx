import { useCallback, useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import type { Order, OrderStatus, PaymentMethod } from '@fanzone/core';
import {
  AlertCircle,
  ArrowLeft,
  CheckCircle2,
  Clock3,
  ClipboardList,
  Coins,
  Loader2,
  ReceiptText,
  ShieldCheck,
  XCircle,
} from 'lucide-react';
import { EmptyState } from '../../components/console/EmptyState';
import { EligibilityBadge } from '../../components/console/EligibilityBadge';
import { StatusChip } from '../../components/console/StatusChip';
import { readableStatus } from '../../components/console/status';
import { useVenue } from '../../hooks/useVenueContext';
import {
  fetchVenueOrderDetail,
  setOrderPaymentStatus,
  setOrderServiceStatus,
  type OrderDetail,
} from '../../services/venueOperations';
import { ManualMarkPaidModal } from './ManualMarkPaidModal';

function formatMoney(order: Order, amount = order.totalAmount) {
  return `${order.currencyCode} ${amount.toLocaleString(undefined, {
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

function dateTimeLabel(value: string | null | undefined) {
  if (!value) return 'Not recorded';
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}

export function OrderDetailPage() {
  const { orderId } = useParams();
  const { venue } = useVenue();
  const venueId = venue?.id ?? '';
  const [detail, setDetail] = useState<OrderDetail | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [markPaidOpen, setMarkPaidOpen] = useState(false);
  const [markPaidError, setMarkPaidError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!venueId || !orderId) return;
    setLoading(true);
    setError(null);
    try {
      setDetail(await fetchVenueOrderDetail(venueId, orderId));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load order.');
    } finally {
      setLoading(false);
    }
  }, [orderId, venueId]);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      void load();
    }, 0);

    return () => window.clearTimeout(timer);
  }, [load]);

  async function runServiceAction(status: OrderStatus) {
    if (!detail) return;
    setBusy(true);
    setError(null);
    try {
      await setOrderServiceStatus(detail.order.id, status);
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Action failed.');
    } finally {
      setBusy(false);
    }
  }

  async function confirmPaid(details: {
    amountReceived: number;
    method: PaymentMethod;
    reference: string;
    note: string;
  }) {
    if (!detail) return;
    setBusy(true);
    setMarkPaidError(null);
    try {
      await setOrderPaymentStatus(detail.order.id, 'paid', details.method, details.note, {
        amountReceived: details.amountReceived,
        externalReference: details.reference,
      });
      setMarkPaidOpen(false);
      await load();
    } catch (err) {
      setMarkPaidError(err instanceof Error ? err.message : 'Could not mark order paid.');
    } finally {
      setBusy(false);
    }
  }

  if (loading && !detail) {
    return (
      <div className="h-full flex items-center justify-center">
        <Loader2 className="animate-spin text-primary" size={48} />
      </div>
    );
  }

  if (error && !detail) {
    return (
      <div className="h-full flex flex-col items-center justify-center text-danger">
        <AlertCircle size={48} />
        <p className="mt-4 font-bold">{error}</p>
        <Link className="btn btn-secondary mt-5" to="/orders">
          Back to Orders
        </Link>
      </div>
    );
  }

  if (!detail) return null;

  const order = detail.order;
  const canCancel = order.status !== 'cancelled' && order.status !== 'served';
  const canReceive = order.status === 'placed';
  const canPrepare = order.status === 'received';
  const canServe = order.status === 'received' || order.status === 'preparing';
  const canMarkPaid = order.status !== 'cancelled' && order.paymentStatus !== 'paid';

  return (
    <div className="max-w-[1500px] mx-auto space-y-6">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
        <div>
          <Link to="/orders" className="inline-flex items-center gap-2 text-sm font-black text-textSecondary hover:text-text">
            <ArrowLeft size={16} />
            Orders
          </Link>
          <h1 className="mt-3 text-4xl md:text-5xl font-black tracking-tight">Order #{order.orderCode}</h1>
          <p className="mt-2 text-lg font-semibold text-textSecondary">
            User {userCode(order)} | Table {tableLabel(order)} | {dateTimeLabel(order.createdAt)}
          </p>
        </div>
        <div className="flex flex-wrap gap-3">
          <StatusChip status={order.status} />
          <StatusChip status={order.paymentStatus} />
        </div>
      </div>

      {error && (
        <div className="rounded-2xl border border-danger/20 bg-danger/10 px-5 py-4 text-danger font-bold">
          {error}
        </div>
      )}

      <section className="grid grid-cols-1 xl:grid-cols-[1fr_380px] gap-6">
        <div className="space-y-6">
          <article className="ops-card overflow-hidden">
            <div className="p-6 border-b border-border flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
              <div>
                <p className="text-sm font-black uppercase tracking-wide text-textSecondary">Order total</p>
                <p className="mt-2 text-5xl font-black tracking-tight">{formatMoney(order)}</p>
                <p className="mt-3 text-base font-bold text-textSecondary">
                  {formatMoney(order, order.subtotalAmount)} subtotal | {formatMoney(order, order.taxAmount ?? 0)} tax | {formatMoney(order, order.tipAmount ?? 0)} tip
                </p>
              </div>
              <div className="rounded-2xl border border-primary/20 bg-primary/10 p-4 text-primary">
                <div className="flex items-center gap-2 font-black">
                  <Coins size={18} />
                  FET impact
                </div>
                <p className="mt-2 text-2xl font-black text-text">+{order.fetEarned.toLocaleString()} FET</p>
                <p className="text-sm font-bold text-textSecondary">{order.fetSpent.toLocaleString()} FET spent</p>
              </div>
            </div>

            <div className="p-6">
              <p className="text-sm font-black uppercase tracking-wide text-textSecondary mb-4">Items</p>
              {order.items?.length ? (
                <div className="space-y-3">
                  {order.items.map((item) => (
                    <div key={item.id} className="flex items-center justify-between gap-4 rounded-2xl bg-surface2 px-5 py-4">
                      <div>
                        <p className="text-lg font-black">{item.quantity}x {item.itemNameSnapshot}</p>
                        <p className="text-sm font-bold text-textSecondary">{formatMoney(order, item.unitPrice)} each</p>
                      </div>
                      <p className="text-lg font-black">{formatMoney(order, item.lineTotal)}</p>
                    </div>
                  ))}
                </div>
              ) : (
                <EmptyState
                  icon={<ClipboardList size={32} />}
                  title="No items attached"
                  message="This order record does not have item rows attached."
                />
              )}

              {order.specialInstructions && (
                <div className="mt-5 rounded-2xl border border-warning/20 bg-warning/10 px-5 py-4">
                  <p className="text-sm font-black uppercase tracking-wide text-warning">Special instructions</p>
                  <p className="mt-2 font-bold">{order.specialInstructions}</p>
                </div>
              )}
            </div>
          </article>

          <article className="ops-card overflow-hidden">
            <div className="p-6 border-b border-border">
              <h2 className="text-2xl font-black tracking-tight">Manual payment audit trail</h2>
              <p className="mt-2 text-base font-semibold text-textSecondary">
                Payment changes are logged with staff actor, amount, method, reference, and before/after status.
              </p>
            </div>
            {detail.paymentEvents.length === 0 ? (
              <div className="p-6">
                <EmptyState
                  icon={<ReceiptText size={32} />}
                  title="No payment audit events yet"
                  message="Manual payment confirmations and payment status changes will appear here."
                />
              </div>
            ) : (
              <div className="divide-y divide-border">
                {detail.paymentEvents.map((event) => (
                  <div key={event.id} className="p-5">
                    <div className="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
                      <div>
                        <div className="flex flex-wrap items-center gap-2">
                          <StatusChip status={event.status} />
                          <span className="text-sm font-black uppercase tracking-wide text-textSecondary">
                            {readableStatus(event.provider)}
                          </span>
                        </div>
                        <p className="mt-3 text-lg font-black">
                          {event.amountReceived == null ? 'Amount not recorded' : `${order.currencyCode} ${event.amountReceived.toFixed(2)}`}
                        </p>
                        <p className="mt-1 text-sm font-bold text-textSecondary">
                          {event.beforeStatus ?? 'unknown'}{' -> '}{event.afterStatus ?? event.status}
                          {event.externalReference ? ` | Ref ${event.externalReference}` : ''}
                        </p>
                        {event.note && <p className="mt-2 text-sm font-bold text-text">{event.note}</p>}
                      </div>
                      <div className="md:text-right">
                        <p className="text-sm font-bold text-textSecondary">{dateTimeLabel(event.createdAt)}</p>
                        <p className="mt-1 text-xs font-black uppercase tracking-wide text-textSecondary">
                          Actor {event.actorUserId?.slice(0, 8) ?? 'recorded'}
                        </p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </article>
        </div>

        <aside className="space-y-6">
          <article className="ops-card p-6">
            <h2 className="text-2xl font-black tracking-tight">Staff actions</h2>
            <div className="mt-5 grid grid-cols-1 gap-3">
              {canReceive && (
                <button className="btn btn-secondary justify-start" disabled={busy} onClick={() => runServiceAction('received')}>
                  <Clock3 size={17} /> Mark received
                </button>
              )}
              {canPrepare && (
                <button className="btn btn-secondary justify-start" disabled={busy} onClick={() => runServiceAction('preparing')}>
                  <Clock3 size={17} /> Preparing
                </button>
              )}
              {canServe && (
                <button className="btn btn-secondary justify-start" disabled={busy} onClick={() => runServiceAction('served')}>
                  <CheckCircle2 size={17} /> Mark served
                </button>
              )}
              <button className="btn btn-primary justify-start" disabled={busy || !canMarkPaid} onClick={() => setMarkPaidOpen(true)}>
                <ReceiptText size={17} /> Mark paid
              </button>
              {canCancel && (
                <button className="btn justify-start border border-danger/20 bg-danger/10 text-danger" disabled={busy} onClick={() => runServiceAction('cancelled')}>
                  <XCircle size={17} /> Cancel order
                </button>
              )}
            </div>
          </article>

          <article className="ops-card p-6">
            <h2 className="text-2xl font-black tracking-tight">Eligibility impact</h2>
            <div className="mt-5 rounded-2xl border border-warning/20 bg-warning/10 p-4">
              <EligibilityBadge state={order.paymentStatus === 'paid' ? 'eligible' : 'order_required'} />
              <p className="mt-4 text-base font-bold leading-7">
                To receive FET winnings, the user must place at least one order from this bar within 2 hours before the linked game/pool start time.
              </p>
            </div>
          </article>

          <article className="ops-card p-6">
            <h2 className="text-2xl font-black tracking-tight">Service timeline</h2>
            <div className="mt-5 space-y-3">
              <TimelineRow label="Created" value={dateTimeLabel(order.createdAt)} active />
              <TimelineRow label="Accepted" value={dateTimeLabel(order.acceptedAt)} active={['received', 'preparing', 'served'].includes(order.status)} />
              <TimelineRow label="Served" value={dateTimeLabel(order.servedAt)} active={order.status === 'served'} />
            </div>
          </article>

          <article className="ops-card p-6">
            <div className="flex items-center gap-2 text-success">
              <ShieldCheck size={20} />
              <h2 className="text-xl font-black tracking-tight text-text">Audit warning</h2>
            </div>
            <p className="mt-3 text-base font-bold leading-7 text-textSecondary">
              High-impact order actions are recorded for venue accountability and settlement review.
            </p>
          </article>
        </aside>
      </section>

      <ManualMarkPaidModal
        order={markPaidOpen ? order : null}
        saving={busy}
        error={markPaidError}
        onClose={() => {
          if (busy) return;
          setMarkPaidOpen(false);
          setMarkPaidError(null);
        }}
        onConfirm={confirmPaid}
      />
    </div>
  );
}

function TimelineRow({ label, value, active }: { label: string; value: string; active: boolean }) {
  return (
    <div className="flex items-center gap-3 rounded-2xl bg-surface2 px-4 py-3">
      <div className={`h-3 w-3 rounded-full ${active ? 'bg-success' : 'bg-surface3'}`} />
      <div>
        <p className="font-black">{label}</p>
        <p className="text-sm font-bold text-textSecondary">{value}</p>
      </div>
    </div>
  );
}
