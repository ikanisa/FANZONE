import React from 'react';
import { Link } from 'react-router-dom';
import {
  BellRing,
  ClipboardList,
  Coins,
  Gamepad2,
  MonitorPlay,
  Plus,
  ReceiptText,
  ShieldAlert,
  Trophy,
  Users,
  Utensils,
} from 'lucide-react';
import { EmptyState } from '../../components/console/EmptyState';
import { EligibilityBadge } from '../../components/console/EligibilityBadge';
import { MetricCard } from '../../components/console/MetricCard';
import { StatusChip } from '../../components/console/StatusChip';
import { useOrders } from '../../hooks/useOrders';
import { useVenue } from '../../hooks/useVenueContext';
import { useVenueStats } from '../../hooks/useVenueStats';

const eligibilityRule =
  'To receive FET winnings, the user must place at least one order from this bar within 2 hours before the linked game/pool start time.';
const activeServiceStatuses = ['submitted', 'accepted', 'preparing', 'ready', 'served'];

function moneyLabel(amount: number) {
  return amount.toLocaleString(undefined, {
    maximumFractionDigits: 0,
  });
}

function orderAge(value: string) {
  const minutes = Math.max(0, Math.round((Date.now() - new Date(value).getTime()) / 60000));
  if (minutes < 1) return 'now';
  if (minutes < 60) return `${minutes}m ago`;
  return `${Math.floor(minutes / 60)}h ${minutes % 60}m ago`;
}

export const OverviewPage: React.FC = () => {
  const { venue } = useVenue();
  const venueId = venue?.id || '';
  const { stats, loading, error } = useVenueStats(venueId);
  const { orders } = useOrders(venueId);

  const activeOrders = orders.filter((order) => activeServiceStatuses.includes(order.status));
  const servedOrders = orders.filter((order) => ['served', 'completed'].includes(order.status));
  const pendingPayments = orders.filter((order) =>
    ['unpaid', 'payment_submitted', 'pending', 'partially_paid', 'disputed'].includes(order.paymentStatus),
  );
  const latestOrders = orders.slice(0, 5);

  return (
    <div className="max-w-[1500px] mx-auto space-y-8">
      <section className="flex flex-col gap-5 xl:flex-row xl:items-end xl:justify-between">
        <div>
          <p className="text-sm font-black uppercase tracking-wide text-textSecondary">Selected venue</p>
          <h1 className="mt-2 text-4xl md:text-5xl font-black tracking-tight">Live command center</h1>
          <p className="mt-3 text-lg font-semibold text-textSecondary">
            Orders, payments, pools, FET, and live-screen decisions for {venue?.name ?? 'this venue'}.
          </p>
        </div>
        <div className="flex flex-wrap gap-3">
          <Link className="btn btn-primary" to="/pools/new">
            <Plus size={17} /> Create Pool
          </Link>
          <Link className="btn btn-secondary" to="/games/new">
            <Gamepad2 size={17} /> Start Game
          </Link>
          <Link className="btn btn-secondary" to="/screen">
            <MonitorPlay size={17} /> Open TV Screen
          </Link>
        </div>
      </section>

      {error && (
        <div className="rounded-2xl border border-danger/20 bg-danger/10 px-5 py-4 text-danger font-bold">
          {error}
        </div>
      )}

      <section className="grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-4 gap-5">
        <MetricCard
          label="Today's orders"
          value={loading ? '...' : stats.today_orders.toLocaleString()}
          detail={`${activeOrders.length.toLocaleString()} active right now`}
          icon={<ReceiptText size={24} />}
          tone="primary"
        />
        <MetricCard
          label="Pending payments"
          value={pendingPayments.length.toLocaleString()}
          detail="Manual confirmation required"
          icon={<ClipboardList size={24} />}
          tone={pendingPayments.length ? 'warning' : 'success'}
        />
        <MetricCard
          label="Served orders"
          value={servedOrders.length.toLocaleString()}
          detail="Completed in the current order window"
          icon={<Utensils size={24} />}
          tone="success"
        />
        <MetricCard
          label="Active pools"
          value={stats.active_pools.toLocaleString()}
          detail="Venue-linked prediction pools"
          icon={<Trophy size={24} />}
          tone="primary"
        />
        <MetricCard
          label="FET issued"
          value={`${moneyLabel(stats.fet_issued)} FET`}
          detail="Order rewards issued today"
          icon={<Coins size={24} />}
          tone="neutral"
        />
        <MetricCard
          label="FET redeemed"
          value={`${moneyLabel(stats.fet_redeemed)} FET`}
          detail="FET used on venue orders"
          icon={<Coins size={24} />}
          tone="neutral"
        />
        <MetricCard
          label="Players joined"
          value={stats.matchGuests.toLocaleString()}
          detail="From the most active venue pool"
          icon={<Users size={24} />}
          tone="primary"
        />
        <MetricCard
          label="Live screen"
          value="Setup"
          detail="Open Screen to pair or push display modes"
          icon={<MonitorPlay size={24} />}
          tone="warning"
        />
      </section>

      <section className="grid grid-cols-1 xl:grid-cols-[1fr_420px] gap-6">
        <div className="space-y-6">
          <div className="ops-card p-6 md:p-7">
            <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
              <div>
                <p className="text-sm font-black uppercase tracking-wide text-warning">Eligibility alerts</p>
                <h2 className="mt-2 text-2xl font-black tracking-tight">Protect FET settlement decisions</h2>
                <p className="mt-2 text-base font-semibold leading-7 text-textSecondary">{eligibilityRule}</p>
              </div>
              <ShieldAlert className="text-warning shrink-0" size={32} />
            </div>
            <div className="mt-6 grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="ops-panel p-4">
                <EligibilityBadge state={pendingPayments.length ? 'order_required' : 'eligible'} />
                <p className="mt-4 text-3xl font-black">{pendingPayments.length.toLocaleString()}</p>
                <p className="text-sm font-bold text-textSecondary">orders still need payment review</p>
              </div>
              <div className="ops-panel p-4">
                <EligibilityBadge state="settlement_pending" />
                <p className="mt-4 text-3xl font-black">{stats.active_pools.toLocaleString()}</p>
                <p className="text-sm font-bold text-textSecondary">active pools to monitor</p>
              </div>
              <div className="ops-panel p-4">
                <EligibilityBadge state="eligible" />
                <p className="mt-4 text-3xl font-black">{servedOrders.length.toLocaleString()}</p>
                <p className="text-sm font-bold text-textSecondary">served orders in this queue</p>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
            <QuickAction title="Start Bar Trivia" detail="Launch centralized game control." to="/games/new" icon={<Gamepad2 size={22} />} />
            <QuickAction title="Add Menu Item" detail="Create an orderable item." to="/menu/items/new" icon={<Utensils size={22} />} />
            <QuickAction title="Open Orders" detail="Review live service and payments." to="/orders" icon={<ClipboardList size={22} />} />
          </div>
        </div>

        <aside className="ops-card overflow-hidden">
          <div className="p-6 border-b border-border flex items-center justify-between gap-4">
            <div>
              <p className="text-sm font-black uppercase tracking-wide text-textSecondary">Live activity</p>
              <h2 className="text-2xl font-black tracking-tight mt-1">Latest order events</h2>
            </div>
            <BellRing size={24} className="text-primary" />
          </div>
          {latestOrders.length === 0 ? (
            <div className="p-6">
              <EmptyState
                icon={<ReceiptText size={32} />}
                title="No active venue activity yet"
                message="Orders, payments, pool actions, and game events will appear here as the venue starts operating."
              />
            </div>
          ) : (
            <div className="divide-y divide-border">
              {latestOrders.map((order) => (
                <Link
                  key={order.id}
                  to={`/orders/${order.id}`}
                  className="block p-5 hover:bg-surface2 transition-colors"
                >
                  <div className="flex items-start justify-between gap-4">
                    <div>
                      <p className="text-lg font-black">Order #{order.orderCode}</p>
                      <p className="mt-1 text-sm font-bold text-textSecondary">
                        {order.currencyCode} {order.totalAmount.toFixed(2)} · {orderAge(order.createdAt)}
                      </p>
                    </div>
                    <div className="flex flex-col items-end gap-2">
                      <StatusChip status={order.status} />
                      <StatusChip status={order.paymentStatus} />
                    </div>
                  </div>
                </Link>
              ))}
            </div>
          )}
        </aside>
      </section>
    </div>
  );
};

function QuickAction({
  title,
  detail,
  to,
  icon,
}: {
  title: string;
  detail: string;
  to: string;
  icon: React.ReactNode;
}) {
  return (
    <Link to={to} className="ops-card p-5 hover:bg-surface2 transition-colors">
      <div className="w-12 h-12 rounded-2xl bg-primary text-primaryText flex items-center justify-center">
        {icon}
      </div>
      <h3 className="mt-5 text-xl font-black tracking-tight">{title}</h3>
      <p className="mt-2 text-sm font-bold text-textSecondary">{detail}</p>
    </Link>
  );
}
