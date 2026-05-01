import React from 'react';
import { Activity, Coins, CreditCard, Loader2, ReceiptText, Trophy, Utensils } from 'lucide-react';
import { EmptyState } from '../../components/console/EmptyState';
import { MetricCard } from '../../components/console/MetricCard';
import { StatusChip } from '../../components/console/StatusChip';
import { useVenue } from '../../hooks/useVenueContext';
import { useVenueStats } from '../../hooks/useVenueStats';

export const DashboardPage: React.FC = () => {
  const { venue } = useVenue();
  const { stats, loading, error } = useVenueStats(venue?.id || '');

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
                  <p className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Staked</p>
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
