import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Coins, Receipt, Save, ShieldCheck, Timer } from 'lucide-react';
import { MetricCard } from '../../components/console/MetricCard';
import { StatusChip } from '../../components/console/StatusChip';
import { useVenue } from '../../hooks/useVenueContext';
import { useOrders } from '../../hooks/useOrders';
import { useVenueStats } from '../../hooks/useVenueStats';
import {
  fetchRewardConfig,
  fetchRewardSummary,
  type RewardConfig,
  type RewardSummary,
  saveRewardConfig,
} from '../../services/venueOperations';

const defaultConfig: RewardConfig = {
  reward_percent: 10,
  reward_trigger: 'paid',
  accepts_fet_spend: false,
  redemption_fet_per_currency: null,
  max_fet_spend_per_order: null,
  reward_campaign_active: true,
};

const defaultSummary: RewardSummary = {
  order_earned_today_fet: 0,
  order_spent_today_fet: 0,
  pending_settlements_fet: 0,
};

export const FETRewardsPage: React.FC = () => {
  const { venue, member } = useVenue();
  const venueId = venue?.id;
  const { stats } = useVenueStats(venueId || '');
  const { orders } = useOrders(venueId || '');
  const [config, setConfig] = useState<RewardConfig>(defaultConfig);
  const [summary, setSummary] = useState<RewardSummary>(defaultSummary);
  const [previewSpend, setPreviewSpend] = useState(100);
  const [saving, setSaving] = useState(false);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);

  const canManageRewards = member?.role === 'owner' || member?.role === 'manager';

  const loadConfig = useCallback(async () => {
    if (!venueId) return;

    try {
      const [nextConfig, nextSummary] = await Promise.all([
        fetchRewardConfig(venueId),
        fetchRewardSummary(venueId),
      ]);
      setConfig(nextConfig);
      setSummary(nextSummary);
    } catch (err) {
      setStatusMessage(err instanceof Error ? err.message : 'Failed to load FET rewards.');
    }
  }, [venueId]);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      void loadConfig();
    }, 0);

    return () => window.clearTimeout(timer);
  }, [loadConfig]);

  const previewEarn = useMemo(
    () => Math.floor(Math.max(0, previewSpend) * Math.max(0, config.reward_percent) / 100),
    [config.reward_percent, previewSpend],
  );

  const ordersAwaitingPayment = orders.filter((order) =>
    ['unpaid', 'pending', 'partially_paid', 'disputed'].includes(order.paymentStatus),
  );

  const saveConfig = async () => {
    if (!venue?.id || !canManageRewards) return;
    setSaving(true);
    setStatusMessage(null);
    try {
      setConfig(await saveRewardConfig(venue.id, config));
      setStatusMessage('Reward rules saved.');
      await loadConfig();
    } catch (err) {
      setStatusMessage(err instanceof Error ? err.message : 'Failed to save reward rules.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-8 max-w-7xl mx-auto">
      <div className="flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
        <div>
          <h1 className="text-4xl font-black tracking-tighter">FET Rewards</h1>
          <p className="text-textSecondary font-medium mt-1">
            Venue-level earn and spend settings for bar orders.
          </p>
        </div>
        <div className="px-4 py-2 bg-white border border-border rounded-xl flex items-center gap-2 text-sm font-bold w-fit">
          <ShieldCheck size={16} />
          Role checked and audited
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <MetricCard label="FET issued today" value={`${summary.order_earned_today_fet.toLocaleString()} FET`} icon={<Coins size={22} />} />
        <MetricCard label="FET redeemed today" value={`${summary.order_spent_today_fet.toLocaleString()} FET`} icon={<Receipt size={22} />} />
        <MetricCard label="Pending payments" value={stats.pending_payment_count.toLocaleString()} icon={<Timer size={22} />} />
      </div>

      <div className="bg-white border border-border rounded-[28px] shadow-sm p-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between mb-6">
          <div>
            <div className="flex items-center gap-3 flex-wrap">
              <h2 className="font-black text-xl">Reward Rules</h2>
              <StatusChip status={config.reward_campaign_active ? 'active' : 'inactive'} />
            </div>
            <p className="text-sm text-textSecondary font-medium mt-1">
              Admin platform constraints still apply; venue changes are written through Supabase RPC.
            </p>
          </div>
          <button className="btn btn-primary" onClick={saveConfig} disabled={saving || !canManageRewards}>
            <Save size={16} />
            {saving ? 'Saving...' : 'Save'}
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-6 gap-4">
          <label className="space-y-2">
            <span className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Earn percent</span>
            <input
              className="input"
              type="number"
              min={0}
              max={100}
              step={0.5}
              disabled={!canManageRewards}
              value={config.reward_percent}
              onChange={(event) => setConfig((current) => ({
                ...current,
                reward_percent: Number(event.target.value),
              }))}
            />
          </label>
          <label className="space-y-2">
            <span className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Credit when</span>
            <select
              className="input"
              disabled={!canManageRewards}
              value={config.reward_trigger}
              onChange={(event) => setConfig((current) => ({
                ...current,
                reward_trigger: event.target.value === 'served' ? 'served' : 'paid',
              }))}
            >
              <option value="paid">Marked paid</option>
              <option value="served">Marked served</option>
            </select>
          </label>
          <label className="space-y-2">
            <span className="text-[10px] font-black text-textSecondary uppercase tracking-widest">FET spend</span>
            <select
              className="input"
              disabled={!canManageRewards}
              value={config.accepts_fet_spend ? 'yes' : 'no'}
              onChange={(event) => setConfig((current) => ({
                ...current,
                accepts_fet_spend: event.target.value === 'yes',
              }))}
            >
              <option value="no">Disabled</option>
              <option value="yes">Allowed</option>
            </select>
          </label>
          <label className="space-y-2">
            <span className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Max spend</span>
            <input
              className="input"
              type="number"
              min={0}
              step={1}
              disabled={!canManageRewards || !config.accepts_fet_spend}
              placeholder="No cap"
              value={config.max_fet_spend_per_order ?? ''}
              onChange={(event) => setConfig((current) => ({
                ...current,
                max_fet_spend_per_order: event.target.value === '' ? null : Number(event.target.value),
              }))}
            />
          </label>
          <label className="space-y-2">
            <span className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Rate</span>
            <input
              className="input"
              type="number"
              min={0}
              step={0.01}
              disabled={!canManageRewards || !config.accepts_fet_spend}
              placeholder="Default"
              value={config.redemption_fet_per_currency ?? ''}
              onChange={(event) => setConfig((current) => ({
                ...current,
                redemption_fet_per_currency: event.target.value === '' ? null : Number(event.target.value),
              }))}
            />
          </label>
          <label className="space-y-2">
            <span className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Campaign</span>
            <select
              className="input"
              disabled={!canManageRewards}
              value={config.reward_campaign_active ? 'active' : 'inactive'}
              onChange={(event) => setConfig((current) => ({
                ...current,
                reward_campaign_active: event.target.value === 'active',
              }))}
            >
              <option value="active">Active</option>
              <option value="inactive">Inactive</option>
            </select>
          </label>
        </div>

        <div className="mt-6 rounded-[24px] bg-surface2 border border-border p-5 flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div>
            <p className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Preview</p>
            <p className="text-2xl font-black text-text mt-1">
              If customer spends {previewSpend.toLocaleString()}, they earn {previewEarn.toLocaleString()} FET.
            </p>
          </div>
          <input
            className="input md:w-44"
            type="number"
            min={0}
            value={previewSpend}
            onChange={(event) => setPreviewSpend(Number(event.target.value))}
          />
        </div>

        {statusMessage && (
          <p className="text-sm font-bold text-textSecondary mt-4">{statusMessage}</p>
        )}
      </div>

      <div className="bg-white border border-border rounded-[28px] shadow-sm overflow-hidden">
        <div className="p-6 border-b border-border">
          <h2 className="font-black text-xl">Orders Awaiting Payment</h2>
          <p className="text-sm text-textSecondary font-medium mt-1">
            Confirm payment in Orders before FET is issued.
          </p>
        </div>
        {ordersAwaitingPayment.length === 0 ? (
          <div className="p-10 text-center text-textSecondary font-bold">
            No orders are waiting for manual payment confirmation.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left">
              <thead>
                <tr className="bg-surface2/50 border-b border-border">
                  <th className="px-6 py-4 text-[10px] font-black text-textSecondary uppercase tracking-widest">Order</th>
                  <th className="px-6 py-4 text-[10px] font-black text-textSecondary uppercase tracking-widest">Payment</th>
                  <th className="px-6 py-4 text-[10px] font-black text-textSecondary uppercase tracking-widest text-right">Total</th>
                  <th className="px-6 py-4 text-[10px] font-black text-textSecondary uppercase tracking-widest text-right">Preview earn</th>
                </tr>
              </thead>
              <tbody>
                {ordersAwaitingPayment.map((order) => (
                  <tr key={order.id} className="border-b border-border last:border-0">
                    <td className="px-6 py-4">
                      <p className="font-black">#{order.orderCode}</p>
                      <p className="text-xs text-textSecondary">Table {order.tableNumber || order.tableId.slice(0, 6)}</p>
                    </td>
                    <td className="px-6 py-4">
                      <StatusChip status={order.paymentStatus} />
                    </td>
                    <td className="px-6 py-4 text-right font-black">
                      {order.currencyCode} {order.totalAmount.toFixed(2)}
                    </td>
                    <td className="px-6 py-4 text-right font-black text-success">
                      {Math.floor(order.totalAmount * config.reward_percent / 100).toLocaleString()} FET
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};
