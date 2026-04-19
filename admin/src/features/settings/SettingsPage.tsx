// FANZONE Admin — Settings / Feature Flags — Live Data
import { useState } from 'react';
import { PageHeader } from '../../components/layout/PageHeader';
import { KpiCard } from '../../components/ui/KpiCard';
import { LoadingState, ErrorState } from '../../components/ui/StateViews';
import { useFeatureFlags, useToggleFeatureFlag } from './useSettings';
import { useAuth } from '../../hooks/useAuth';
import { useAuditLog } from '../../hooks/useAuditLog';
import { formatDateTime } from '../../lib/formatters';
import { Globe, ToggleLeft, ToggleRight, Plus, Shield, Zap } from 'lucide-react';
import type { FeatureFlag } from '../../types';

export function SettingsPage() {
  const [page] = useState(0);
  const { data: result, isLoading, error, refetch } = useFeatureFlags({ page });
  const toggleMutation = useToggleFeatureFlag();
  const { admin } = useAuth();
  const { logAction } = useAuditLog();

  const flags = result?.data ?? [];
  const enabledCount = flags.filter(f => f.is_enabled).length;
  const disabledCount = flags.filter(f => !f.is_enabled).length;

  const handleToggle = async (flag: FeatureFlag) => {
    const newEnabled = !flag.is_enabled;
    await toggleMutation.mutateAsync({ flagId: flag.id, enabled: newEnabled, adminId: admin?.id ?? '' });
    await logAction({
      action: newEnabled ? 'enable_feature_flag' : 'disable_feature_flag',
      module: 'settings',
      targetType: 'feature_flag',
      targetId: flag.id,
      beforeState: { key: flag.key, is_enabled: flag.is_enabled },
      afterState: { key: flag.key, is_enabled: newEnabled },
    });
  };

  return (
    <div>
      <PageHeader title="Settings & Feature Flags" subtitle="Control feature visibility and market rollout" actions={<button className="btn btn-primary"><Plus size={16} /> Add Flag</button>} />

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard label="Total Flags" value={flags.length} icon={<Shield size={18} />} />
        <KpiCard label="Enabled" value={enabledCount} icon={<Zap size={18} />} />
        <KpiCard label="Disabled" value={disabledCount} icon={<ToggleLeft size={18} />} />
        <KpiCard label="Markets" value={[...new Set(flags.map(f => f.market))].length} icon={<Globe size={18} />} />
      </div>

      {/* Market Cards */}
      <div className="card mb-6">
        <h3 className="text-md font-semibold mb-4 flex items-center gap-2"><Globe size={18} className="text-accent" /> Market Configuration</h3>
        <div className="grid grid-2 gap-4">
          <div className="p-4" style={{ background: 'var(--fz-surface-2)', borderRadius: 'var(--fz-radius)' }}>
            <div className="flex items-center gap-2 mb-2">
              <span className="text-lg">🇲🇹</span>
              <span className="font-semibold">Malta (MT)</span>
              <span className="badge badge-success ml-auto">Active</span>
            </div>
            <p className="text-sm text-muted">Primary market. All features available.</p>
          </div>
          <div className="p-4" style={{ background: 'var(--fz-surface-2)', borderRadius: 'var(--fz-radius)' }}>
            <div className="flex items-center gap-2 mb-2">
              <span className="text-lg">🇪🇺</span>
              <span className="font-semibold">European Union (EU)</span>
              <span className="badge badge-warning ml-auto">Planned</span>
            </div>
            <p className="text-sm text-muted">Future expansion. Feature flags disabled.</p>
          </div>
        </div>
      </div>

      {/* Flags Table */}
      {isLoading ? <LoadingState lines={6} /> :
       error ? <ErrorState onRetry={() => refetch()} /> : (
        <div className="data-table-container">
          <table className="data-table">
            <thead><tr><th>Feature</th><th>Key</th><th>Module</th><th>Market</th><th>Updated</th><th>Status</th><th className="cell-actions">Toggle</th></tr></thead>
            <tbody>
              {flags.map(f => (
                <tr key={f.id}>
                  <td><div className="font-medium">{f.label}</div><div className="text-xs text-muted">{f.description}</div></td>
                  <td className="mono text-xs">{f.key}</td>
                  <td><span className="badge badge-neutral">{f.module || '—'}</span></td>
                  <td>{f.market}</td>
                  <td className="text-xs text-muted">{formatDateTime(f.updated_at)}</td>
                  <td><span className={`badge ${f.is_enabled ? 'badge-success' : 'badge-neutral'}`}>{f.is_enabled ? 'Enabled' : 'Disabled'}</span></td>
                  <td className="cell-actions">
                    <button className="btn btn-ghost btn-icon" onClick={() => handleToggle(f)} title={f.is_enabled ? 'Disable' : 'Enable'} disabled={toggleMutation.isPending}>
                      {f.is_enabled ? <ToggleRight size={24} className="text-success" /> : <ToggleLeft size={24} className="text-muted" />}
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
