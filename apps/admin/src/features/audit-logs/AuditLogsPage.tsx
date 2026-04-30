// FANZONE Admin — Audit Logs Page — Live Data
import { useState } from 'react';
import { PageHeader } from '../../components/layout/PageHeader';
import { DetailDrawer, DrawerSection } from '../../components/ui/DetailDrawer';
import { LoadingState, ErrorState, EmptyState } from '../../components/ui/StateViews';
import { useAuditLogs, AUDIT_MODULES } from './useAuditLogs';
import { formatDateTime } from '../../lib/formatters';
import { Search, Download, Filter } from 'lucide-react';
import type { AuditLog } from '../../types';

function JsonDiff({ label, before, after }: { label: string; before: Record<string, unknown> | null; after: Record<string, unknown> | null }) {
  if (!before && !after) return null;

  return (
    <div style={{ marginBottom: 'var(--fz-sp-4)' }}>
      <h4 className="text-xs font-semibold text-muted uppercase mb-2" style={{ letterSpacing: '0.05em' }}>{label}</h4>
      <div className="flex gap-4">
        {before && (
          <div style={{ flex: 1 }}>
            <div className="text-xs text-error font-semibold mb-1">Before</div>
            <pre style={{
              background: 'var(--fz-error-bg)',
              padding: 'var(--fz-sp-3)',
              borderRadius: 'var(--fz-radius)',
              fontSize: 'var(--fz-text-xs)',
              overflow: 'auto',
              maxHeight: 200,
              whiteSpace: 'pre-wrap',
              wordBreak: 'break-all',
            }}>
              {JSON.stringify(before, null, 2)}
            </pre>
          </div>
        )}
        {after && (
          <div style={{ flex: 1 }}>
            <div className="text-xs text-success font-semibold mb-1">After</div>
            <pre style={{
              background: 'var(--fz-success-bg)',
              padding: 'var(--fz-sp-3)',
              borderRadius: 'var(--fz-radius)',
              fontSize: 'var(--fz-text-xs)',
              overflow: 'auto',
              maxHeight: 200,
              whiteSpace: 'pre-wrap',
              wordBreak: 'break-all',
            }}>
              {JSON.stringify(after, null, 2)}
            </pre>
          </div>
        )}
      </div>
    </div>
  );
}

export function AuditLogsPage() {
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState('');
  const [moduleFilter, setModuleFilter] = useState('all');
  const [selectedLog, setSelectedLog] = useState<AuditLog | null>(null);

  // Data
  const { data: result, isLoading, error, refetch } = useAuditLogs({ page }, { module: moduleFilter, search });
  const logs = result?.data ?? [];

  const handleExport = () => {
    const csv = [
      'Timestamp,Admin,Action,Module,Target Type,Target ID',
      ...logs.map(l => `"${l.created_at}","${l.admin_name || ''}","${l.action}","${l.module}","${l.target_type || ''}","${l.target_id || ''}"`)
    ].join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `audit-logs-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div>
      <PageHeader
        title="Audit Logs"
        subtitle="Who did what, when — full mutation trail"
        actions={<button className="btn btn-secondary" onClick={handleExport}><Download size={16} /> Export CSV</button>}
      />

      {/* Filters */}
      <div className="filter-bar mb-4">
        <div style={{ position: 'relative', maxWidth: 360 }}>
          <Search size={16} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--fz-muted-2)' }} />
          <input className="input" style={{ paddingLeft: 36 }} placeholder="Search by admin, action, or entity..." value={search} onChange={e => { setSearch(e.target.value); setPage(0); }} />
        </div>
        <div className="flex items-center gap-1">
          <Filter size={14} className="text-muted" />
          <select className="input select" style={{ maxWidth: 160 }} value={moduleFilter} onChange={e => { setModuleFilter(e.target.value); setPage(0); }}>
            <option value="all">All modules</option>
            {AUDIT_MODULES.map(m => <option key={m} value={m}>{m}</option>)}
          </select>
        </div>
      </div>

      {/* Content */}
      {isLoading ? <LoadingState lines={8} /> :
       error ? <ErrorState onRetry={() => refetch()} /> :
       logs.length === 0 ? <EmptyState title="No audit logs found" /> : (
        <div className="data-table-container">
          <table className="data-table">
            <thead><tr><th>Timestamp</th><th>Admin</th><th>Action</th><th>Module</th><th>Target</th><th>Entity ID</th><th>Diff</th></tr></thead>
            <tbody>
              {logs.map(l => (
                <tr key={l.id} className="cursor-pointer" onClick={() => setSelectedLog(l)}>
                  <td className="text-muted" style={{ whiteSpace: 'nowrap' }}>{formatDateTime(l.created_at)}</td>
                  <td className="font-medium">{l.admin_name || l.admin_user_id}</td>
                  <td><code className="mono text-xs" style={{ background: 'var(--fz-surface-2)', padding: '2px 6px', borderRadius: 4 }}>{l.action}</code></td>
                  <td><span className="badge badge-neutral">{l.module}</span></td>
                  <td className="text-muted">{l.target_type || '—'}</td>
                  <td className="mono text-xs">{l.target_id || '—'}</td>
                  <td>
                    {(l.before_state || l.after_state) ? (
                      <span className="badge badge-info" style={{ cursor: 'pointer' }}>diff</span>
                    ) : (
                      <span className="text-muted">—</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="pagination">
            <span>Showing {logs.length} of {result?.count ?? 0} entries</span>
            <div className="pagination-controls">
              <button className="pagination-btn" disabled={page === 0} onClick={() => setPage(p => p - 1)}>←</button>
              <button className="pagination-btn active">{page + 1}</button>
              <button className="pagination-btn" disabled={logs.length < (result?.pageSize ?? 25)} onClick={() => setPage(p => p + 1)}>→</button>
            </div>
          </div>
        </div>
      )}

      {/* Detail Drawer with Before/After Diff */}
      <DetailDrawer
        open={!!selectedLog}
        title={`Audit Log ${selectedLog?.id ?? ''}`}
        subtitle={selectedLog ? `${selectedLog.action} by ${selectedLog.admin_name || 'Unknown'}` : undefined}
        onClose={() => setSelectedLog(null)}
      >
        {selectedLog && (
          <>
            <DrawerSection title="Action Info">
              <div className="flex justify-between items-start py-2 border-b" style={{ borderColor: 'var(--fz-border)' }}>
                <span className="text-sm text-muted">Admin</span>
                <span className="text-sm font-medium">{selectedLog.admin_name || selectedLog.admin_user_id}</span>
              </div>
              <div className="flex justify-between items-start py-2 border-b" style={{ borderColor: 'var(--fz-border)' }}>
                <span className="text-sm text-muted">Action</span>
                <code className="mono text-xs" style={{ background: 'var(--fz-surface-2)', padding: '2px 6px', borderRadius: 4 }}>{selectedLog.action}</code>
              </div>
              <div className="flex justify-between items-start py-2 border-b" style={{ borderColor: 'var(--fz-border)' }}>
                <span className="text-sm text-muted">Module</span>
                <span className="badge badge-neutral">{selectedLog.module}</span>
              </div>
              <div className="flex justify-between items-start py-2 border-b" style={{ borderColor: 'var(--fz-border)' }}>
                <span className="text-sm text-muted">Target</span>
                <span className="text-sm">{selectedLog.target_type} / <span className="mono">{selectedLog.target_id}</span></span>
              </div>
              <div className="flex justify-between items-start py-2 border-b" style={{ borderColor: 'var(--fz-border)' }}>
                <span className="text-sm text-muted">Timestamp</span>
                <span className="text-sm">{formatDateTime(selectedLog.created_at)}</span>
              </div>
              {selectedLog.ip_address && (
                <div className="flex justify-between items-start py-2 border-b" style={{ borderColor: 'var(--fz-border)' }}>
                  <span className="text-sm text-muted">IP Address</span>
                  <span className="text-sm mono">{selectedLog.ip_address}</span>
                </div>
              )}
            </DrawerSection>

            {(selectedLog.before_state || selectedLog.after_state) && (
              <DrawerSection title="State Change">
                <JsonDiff label="" before={selectedLog.before_state} after={selectedLog.after_state} />
              </DrawerSection>
            )}

            {selectedLog.metadata && Object.keys(selectedLog.metadata).length > 0 && (
              <DrawerSection title="Metadata">
                <pre style={{
                  background: 'var(--fz-surface-2)',
                  padding: 'var(--fz-sp-3)',
                  borderRadius: 'var(--fz-radius)',
                  fontSize: 'var(--fz-text-xs)',
                  overflow: 'auto',
                  maxHeight: 200,
                  whiteSpace: 'pre-wrap',
                }}>
                  {JSON.stringify(selectedLog.metadata, null, 2)}
                </pre>
              </DrawerSection>
            )}
          </>
        )}
      </DetailDrawer>
    </div>
  );
}
