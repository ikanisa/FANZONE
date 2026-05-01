import { useState, type FormEvent } from "react";
import { Coins, Gift, Save, Trophy, Users } from "lucide-react";

import { PageHeader } from "../../components/layout/PageHeader";
import { KpiCard } from "../../components/ui/KpiCard";
import { EmptyState, ErrorState, LoadingState } from "../../components/ui/StateViews";
import { StatusBadge } from "../../components/ui/StatusBadge";
import { useRpcMutation, useSupabaseList } from "../../hooks/useSupabaseQuery";
import { formatDateTime, formatFET } from "../../lib/formatters";
import {
  buildRewardRuleRpcArgs,
  type RewardRuleFormInput,
} from "../platform-control/controlCenter";

interface RewardRuleRow {
  id: string;
  scope: "platform" | "country" | "venue";
  country_id: string | null;
  venue_id: string | null;
  welcome_fet_amount: number;
  order_fet_default_percent: number;
  pool_creator_reward_per_member: number;
  min_qualified_stake: number;
  min_qualified_members: number;
  is_active: boolean;
  starts_at: string | null;
  ends_at: string | null;
  created_at: string;
  updated_at: string;
}

const initialForm: RewardRuleFormInput = {
  id: null,
  scope: "platform",
  countryId: "",
  venueId: "",
  welcomeFetAmount: 0,
  orderFetDefaultPercent: 0,
  poolCreatorRewardPerMember: 0,
  minQualifiedStake: 0,
  minQualifiedMembers: 0,
  isActive: true,
  startsAt: "",
  endsAt: "",
  reason: "",
};

function fromRule(rule: RewardRuleRow): RewardRuleFormInput {
  return {
    id: rule.id,
    scope: rule.scope,
    countryId: rule.country_id ?? "",
    venueId: rule.venue_id ?? "",
    welcomeFetAmount: rule.welcome_fet_amount,
    orderFetDefaultPercent: rule.order_fet_default_percent,
    poolCreatorRewardPerMember: rule.pool_creator_reward_per_member,
    minQualifiedStake: rule.min_qualified_stake,
    minQualifiedMembers: rule.min_qualified_members,
    isActive: rule.is_active,
    startsAt: rule.starts_at ?? "",
    endsAt: rule.ends_at ?? "",
    reason: "",
  };
}

export function RewardRulesPage() {
  const [form, setForm] = useState<RewardRuleFormInput>(initialForm);
  const [formError, setFormError] = useState<string | null>(null);

  const {
    data: rules = [],
    isLoading,
    error,
    refetch,
  } = useSupabaseList<RewardRuleRow>(["reward-rules"], "reward_rules", {
    order: { column: "updated_at", ascending: false },
  });

  const upsertRewardRule = useRpcMutation<ReturnType<typeof buildRewardRuleRpcArgs>>({
    fnName: "admin_upsert_reward_rule",
    invalidateKeys: [["reward-rules"], ["dashboard-kpis"]],
    successMessage: "Reward rule saved.",
  });

  const activeCount = rules.filter((rule) => rule.is_active).length;
  const welcomeTotal = rules
    .filter((rule) => rule.is_active)
    .reduce((sum, rule) => sum + Number(rule.welcome_fet_amount ?? 0), 0);
  const creatorRewardTotal = rules
    .filter((rule) => rule.is_active)
    .reduce((sum, rule) => sum + Number(rule.pool_creator_reward_per_member ?? 0), 0);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setFormError(null);

    try {
      await upsertRewardRule.mutateAsync(buildRewardRuleRpcArgs(form));
      setForm(initialForm);
    } catch (err) {
      setFormError(err instanceof Error ? err.message : "Could not save reward rule.");
    }
  }

  return (
    <div>
      <PageHeader
        title="Reward Rules"
        subtitle="Configure welcome FET, order earning, creator rewards, qualified stakes, and country or venue overrides."
      />

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard label="Rule Sets" value={rules.length} icon={<Trophy size={18} />} />
        <KpiCard label="Active Rules" value={activeCount} icon={<Gift size={18} />} />
        <KpiCard label="Welcome FET" value={welcomeTotal} format="fet" icon={<Coins size={18} />} />
        <KpiCard label="Creator Reward" value={creatorRewardTotal} format="fet" icon={<Users size={18} />} />
      </div>

      <form className="data-table-container mb-4" style={{ padding: 16 }} onSubmit={handleSubmit}>
        <div className="flex items-start justify-between gap-3 mb-4">
          <div>
            <h2 className="font-semibold">{form.id ? "Edit Reward Rule" : "Create Reward Rule"}</h2>
            <p className="text-sm text-muted">All values are data-driven and audited. FET spending itself is controlled by feature flags and venue constraints.</p>
          </div>
          <button className="btn btn-primary" disabled={upsertRewardRule.isPending} type="submit">
            <Save size={16} /> Save Rule
          </button>
        </div>

        {formError && <div className="alert alert-error mb-4">{formError}</div>}

        <div className="filter-bar">
          <select
            className="input select"
            value={form.scope}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                scope: event.target.value as RewardRuleFormInput["scope"],
              }))
            }
            style={{ maxWidth: 180 }}
          >
            <option value="platform">Platform</option>
            <option value="country">Country</option>
            <option value="venue">Venue</option>
          </select>
          <input
            className="input"
            placeholder="Country id"
            value={form.countryId ?? ""}
            disabled={form.scope !== "country"}
            onChange={(event) => setForm((current) => ({ ...current, countryId: event.target.value }))}
          />
          <input
            className="input"
            placeholder="Venue id"
            value={form.venueId ?? ""}
            disabled={form.scope !== "venue"}
            onChange={(event) => setForm((current) => ({ ...current, venueId: event.target.value }))}
          />
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={form.isActive}
              onChange={(event) => setForm((current) => ({ ...current, isActive: event.target.checked }))}
            />
            Active
          </label>
          {form.id && (
            <button className="btn btn-secondary" type="button" onClick={() => setForm(initialForm)}>
              Clear
            </button>
          )}
        </div>

        <div className="filter-bar">
          <input className="input" type="number" min={0} placeholder="Welcome FET" value={form.welcomeFetAmount} onChange={(event) => setForm((current) => ({ ...current, welcomeFetAmount: Number(event.target.value) }))} />
          <input className="input" type="number" min={0} max={100} step="0.01" placeholder="Order earn %" value={form.orderFetDefaultPercent} onChange={(event) => setForm((current) => ({ ...current, orderFetDefaultPercent: Number(event.target.value) }))} />
          <input className="input" type="number" min={0} placeholder="Creator reward/member" value={form.poolCreatorRewardPerMember} onChange={(event) => setForm((current) => ({ ...current, poolCreatorRewardPerMember: Number(event.target.value) }))} />
          <input className="input" type="number" min={0} placeholder="Min qualified stake" value={form.minQualifiedStake} onChange={(event) => setForm((current) => ({ ...current, minQualifiedStake: Number(event.target.value) }))} />
          <input className="input" type="number" min={0} placeholder="Min members" value={form.minQualifiedMembers} onChange={(event) => setForm((current) => ({ ...current, minQualifiedMembers: Number(event.target.value) }))} />
        </div>

        <div className="filter-bar">
          <label className="text-xs text-muted">
            Starts
            <input className="input" type="datetime-local" value={form.startsAt ?? ""} onChange={(event) => setForm((current) => ({ ...current, startsAt: event.target.value }))} />
          </label>
          <label className="text-xs text-muted">
            Ends
            <input className="input" type="datetime-local" value={form.endsAt ?? ""} onChange={(event) => setForm((current) => ({ ...current, endsAt: event.target.value }))} />
          </label>
          <input
            className="input"
            placeholder="Audit reason, required"
            value={form.reason}
            onChange={(event) => setForm((current) => ({ ...current, reason: event.target.value }))}
            style={{ minWidth: 280, flex: 1 }}
          />
        </div>
      </form>

      {isLoading ? (
        <LoadingState lines={6} />
      ) : error ? (
        <ErrorState onRetry={() => refetch()} />
      ) : rules.length === 0 ? (
        <EmptyState
          title="No reward rules found"
          description="Create platform defaults before enabling welcome FET or order earning."
        />
      ) : (
        <div className="data-table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Scope</th>
                <th>Target</th>
                <th>Welcome</th>
                <th>Order Earn</th>
                <th>Creator Reward</th>
                <th>Qualified Entry</th>
                <th>Status</th>
                <th>Window</th>
                <th className="cell-actions">Actions</th>
              </tr>
            </thead>
            <tbody>
              {rules.map((rule) => (
                <tr key={rule.id}>
                  <td>
                    <div className="font-medium">{rule.scope}</div>
                    <div className="text-xs text-muted mono">{rule.id}</div>
                  </td>
                  <td className="mono text-xs">{rule.country_id ?? rule.venue_id ?? "platform"}</td>
                  <td>{formatFET(rule.welcome_fet_amount)}</td>
                  <td>{Number(rule.order_fet_default_percent ?? 0).toFixed(2)}%</td>
                  <td>{formatFET(rule.pool_creator_reward_per_member)}</td>
                  <td>
                    {formatFET(rule.min_qualified_stake)} / {rule.min_qualified_members} members
                  </td>
                  <td><StatusBadge status={rule.is_active ? "active" : "inactive"} /></td>
                  <td className="text-xs text-muted">
                    {rule.starts_at ? formatDateTime(rule.starts_at) : "Now"} - {rule.ends_at ? formatDateTime(rule.ends_at) : "No expiry"}
                  </td>
                  <td className="cell-actions">
                    <button className="btn btn-ghost btn-sm" type="button" onClick={() => setForm(fromRule(rule))}>
                      Edit
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
