import React from 'react';
import { Activity, Coins, CreditCard, Loader2, ReceiptText, RefreshCw, Trophy, Utensils } from 'lucide-react';
import { EmptyState } from '../../components/console/EmptyState';
import { MetricCard } from '../../components/console/MetricCard';
import { StatusChip } from '../../components/console/StatusChip';
import { usePaymentReconciliation } from '../../hooks/usePaymentReconciliation';
import { useVenue } from '../../hooks/useVenueContext';
import { useVenueStats } from '../../hooks/useVenueStats';

function moneyLabel(amount: number) {
  return amount.toLocaleString(undefined, {
    maximumFractionDigits: 2,
  });
}

export const DashboardPage: React.FC = () => {
  const { venue } = useVenue();
  const venueId = venue?.id || '';
  const { stats, loading, error } = useVenueStats(venueId);
  const reconciliation = usePaymentReconciliation(venueId);
  const reconciliationTotals = reconciliation.rows.reduce(
    (totals, row) => ({
      events: totals.events + row.eventCount,
      amountReceived: totals.amountReceived + row.amountReceived,
      orderTotalAmount: totals.orderTotalAmount + row.orderTotalAmount,
      externalReferences:
        totals.externalReferences + row.externalReferenceCount,
      providerApiRows: totals.providerApiRows + (row.providerApiUsed ? 1 : 0),
    }),
    {
      events: 0,
      amountReceived: 0,
      orderTotalAmount: 0,
      externalReferences: 0,
      providerApiRows: 0,
    },
  );

  return (
    <div className="space-y-8 max-w-7xl mx-auto">
      <div className="flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
        <div>
          <h1 className="text-4xl font-black tracking-tighter">Insights</h1>
          <p className="text-textSecondary font-medium mt-1">
            Simple operational signals for today.
          </p>
        </div>
        <div className="px-4 py-2 bg-white border border-border rounded-xl flex items-center gap-2 text-sm font-bold w-fit">
          {loading ? <Loader2 size={16} className="animate-spin" /> : <Activity size={16} />}
          Live venue data
        </div>
      </div>

      {error && (
        <div className="bg-danger/10 border border-danger/20 text-danger rounded-2xl px-5 py-4 font-bold">
          {error}
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">
        <MetricCard label="Today's orders" value={stats.today_orders.toLocaleString()} icon={<ReceiptText size={22} />} />
        <MetricCard label="FET issued" value={`${stats.fet_issued.toLocaleString()} FET`} icon={<Coins size={22} />} />
        <MetricCard label="FET redeemed" value={`${stats.fet_redeemed.toLocaleString()} FET`} icon={<CreditCard size={22} />} />
        <MetricCard label="Active pools" value={stats.active_pools.toLocaleString()} icon={<Trophy size={22} />} />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="bg-white border border-border rounded-[28px] shadow-sm p-6">
          <p className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Most active match</p>
          {stats.most_active_match ? (
            <div className="mt-4 space-y-4">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <h2 className="text-2xl font-black tracking-tight">{stats.most_active_match.match_label}</h2>
                  <p className="text-sm text-textSecondary font-bold mt-1">
                    {stats.most_active_match.competition_name || stats.most_active_match.title}
                  </p>
                </div>
                <StatusChip status={stats.most_active_match.status} />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div className="rounded-2xl bg-surface2 p-4">
                  <p className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Members</p>
                  <p className="text-2xl font-black mt-1">{stats.most_active_match.total_members.toLocaleString()}</p>
                </div>
                <div className="rounded-2xl bg-surface2 p-4">
                  <p className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Reserved</p>
                  <p className="text-2xl font-black mt-1">{stats.most_active_match.total_staked_fet.toLocaleString()} FET</p>
                </div>
              </div>
            </div>
          ) : (
            <div className="mt-4 rounded-2xl bg-surface2 p-8 text-center text-sm font-bold text-textSecondary">
              No active venue-linked pool today.
            </div>
          )}
        </div>

        <div className="bg-white border border-border rounded-[28px] shadow-sm p-6">
          <p className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Top menu items</p>
          {stats.top_menu_items.length ? (
            <div className="mt-4 space-y-3">
              {stats.top_menu_items.map((item) => (
                <div key={item.name} className="flex items-center justify-between gap-4 rounded-2xl bg-surface2 px-4 py-3">
                  <div className="min-w-0">
                    <p className="font-black truncate">{item.name}</p>
                    <p className="text-xs text-textSecondary font-bold">{item.quantity.toLocaleString()} sold</p>
                  </div>
                  <p className="font-black text-textSecondary">{item.revenue.toLocaleString()}</p>
                </div>
              ))}
            </div>
          ) : (
            <div className="mt-4 rounded-2xl bg-surface2 p-8 text-center text-sm font-bold text-textSecondary">
              No menu item sales yet today.
            </div>
          )}
        </div>

        <div className="bg-white border border-border rounded-[28px] shadow-sm p-6">
          <p className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Payment queue</p>
          <div className="mt-4 rounded-[24px] bg-surface2 p-6">
            <div className="w-12 h-12 bg-warning/10 text-warning rounded-2xl flex items-center justify-center mb-4">
              <CreditCard size={24} />
            </div>
            <p className="text-5xl font-black">{stats.pending_payment_count.toLocaleString()}</p>
            <p className="text-sm text-textSecondary font-bold mt-2">Orders need manual payment attention.</p>
          </div>
        </div>
      </div>

      <div className="bg-white border border-border rounded-[28px] shadow-sm overflow-hidden">
        <div className="p-6 border-b border-border flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <p className="text-[10px] font-black text-textSecondary uppercase tracking-widest">
              Daily close
            </p>
            <h2 className="text-2xl font-black tracking-tight mt-1">
              Manual payment reconciliation
            </h2>
          </div>
          <div className="flex flex-wrap items-center gap-3">
            <input
              type="date"
              value={reconciliation.businessDate}
              onChange={(event) =>
                reconciliation.setBusinessDate(event.target.value)
              }
              className="h-11 rounded-xl border border-border bg-surface2 px-3 text-sm font-black"
              aria-label="Business date"
            />
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => void reconciliation.refresh()}
              disabled={reconciliation.loading}
            >
              {reconciliation.loading ? (
                <Loader2 size={16} className="animate-spin" />
              ) : (
                <RefreshCw size={16} />
              )}
              Refresh
            </button>
          </div>
        </div>

        {reconciliation.error ? (
          <div className="m-6 rounded-2xl border border-danger/20 bg-danger/10 px-5 py-4 text-danger font-bold">
            {reconciliation.error}
          </div>
        ) : (
          <div className="p-6 space-y-5">
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div className="rounded-2xl bg-surface2 p-4">
                <p className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Events</p>
                <p className="text-2xl font-black mt-1">{reconciliationTotals.events.toLocaleString()}</p>
              </div>
              <div className="rounded-2xl bg-surface2 p-4">
                <p className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Received</p>
                <p className="text-2xl font-black mt-1">{moneyLabel(reconciliationTotals.amountReceived)}</p>
              </div>
              <div className="rounded-2xl bg-surface2 p-4">
                <p className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Order total</p>
                <p className="text-2xl font-black mt-1">{moneyLabel(reconciliationTotals.orderTotalAmount)}</p>
              </div>
              <div className="rounded-2xl bg-surface2 p-4">
                <p className="text-[10px] font-black text-textSecondary uppercase tracking-widest">References</p>
                <p className="text-2xl font-black mt-1">{reconciliationTotals.externalReferences.toLocaleString()}</p>
              </div>
            </div>

            {reconciliationTotals.providerApiRows > 0 && (
              <div className="rounded-2xl border border-danger/20 bg-danger/10 px-5 py-4 text-sm font-black text-danger">
                Provider API execution appeared in payment event evidence.
              </div>
            )}

            {reconciliation.rows.length === 0 && !reconciliation.loading ? (
              <EmptyState
                icon={<ReceiptText size={34} />}
                title="No manual payment events for this date"
                message="Manual payment confirmations will appear after staff record external payment evidence."
              />
            ) : (
              <div className="overflow-x-auto">
                <table className="min-w-full text-left">
                  <thead>
                    <tr className="text-[10px] font-black uppercase tracking-widest text-textSecondary">
                      <th className="py-3 pr-4">Method</th>
                      <th className="py-3 pr-4">Status</th>
                      <th className="py-3 pr-4 text-right">Events</th>
                      <th className="py-3 pr-4 text-right">Received</th>
                      <th className="py-3 pr-4 text-right">Order total</th>
                      <th className="py-3 text-right">Provider API</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border">
                    {reconciliation.rows.map((row) => (
                      <tr
                        key={`${row.paymentMethod}-${row.paymentStatus}-${row.providerApiUsed}`}
                        className="text-sm font-bold"
                      >
                        <td className="py-4 pr-4 capitalize">{row.paymentMethod}</td>
                        <td className="py-4 pr-4">
                          <StatusChip status={row.paymentStatus} />
                        </td>
                        <td className="py-4 pr-4 text-right">{row.eventCount.toLocaleString()}</td>
                        <td className="py-4 pr-4 text-right">{moneyLabel(row.amountReceived)}</td>
                        <td className="py-4 pr-4 text-right">{moneyLabel(row.orderTotalAmount)}</td>
                        <td className="py-4 text-right">
                          <StatusChip
                            status={row.providerApiUsed ? 'disputed' : 'paid'}
                            label={row.providerApiUsed ? 'Yes' : 'No'}
                            tone={row.providerApiUsed ? 'danger' : 'success'}
                          />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}
      </div>

      {!loading && stats.today_orders === 0 && stats.active_pools === 0 && (
        <EmptyState
          icon={<Utensils size={34} />}
          title="No venue activity yet today"
          message="Orders, FET movement, and pool activity will populate these cards as staff operate the venue."
        />
      )}
    </div>
  );
};
