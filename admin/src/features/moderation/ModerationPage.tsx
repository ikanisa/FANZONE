// FANZONE Admin — Moderation / Risk Page — Live Data
import { useState } from 'react';
import { PageHeader } from '../../components/layout/PageHeader';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { KpiCard } from '../../components/ui/KpiCard';
import { DetailDrawer, DrawerSection, DrawerField } from '../../components/ui/DetailDrawer';
import { LoadingState, ErrorState, EmptyState } from '../../components/ui/StateViews';
import { useReports, useUpdateReportStatus } from './useModeration';
import { useAuditLog } from '../../hooks/useAuditLog';
import { formatRelativeTime, formatDateTime } from '../../lib/formatters';
import { Shield, AlertTriangle, Eye, Clock, Search, CheckCircle, XCircle, ArrowUp } from 'lucide-react';
import type { ModerationReport } from '../../types';

export function ModerationPage() {
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [selectedReport, setSelectedReport] = useState<ModerationReport | null>(null);
  const [resolutionNotes, setResolutionNotes] = useState('');

  // Data
  const { data: result, isLoading, error, refetch } = useReports({ page }, { status: statusFilter, search });
  const updateStatus = useUpdateReportStatus();
  const { logAction } = useAuditLog();

  const reports = result?.data ?? [];

  const handleStatusUpdate = async (reportId: string, newStatus: string) => {
    await updateStatus.mutateAsync({
      reportId,
      status: newStatus,
      resolutionNotes: newStatus === 'resolved' || newStatus === 'dismissed' ? resolutionNotes : undefined,
    });
    await logAction({
      action: `${newStatus}_report`,
      module: 'moderation',
      targetType: 'report',
      targetId: reportId,
      afterState: { status: newStatus, resolution_notes: resolutionNotes || undefined },
    });
    setSelectedReport(null);
    setResolutionNotes('');
  };

  const openCount = reports.filter(r => r.status === 'open').length;
  const investigatingCount = reports.filter(r => r.status === 'investigating').length;
  const escalatedCount = reports.filter(r => r.status === 'escalated').length;

  return (
    <div>
      <PageHeader title="Moderation & Risk" subtitle="Review reports, fraud flags, and account issues" />

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard label="Open Reports" value={openCount} icon={<AlertTriangle size={18} />} />
        <KpiCard label="Investigating" value={investigatingCount} icon={<Eye size={18} />} />
        <KpiCard label="Escalated" value={escalatedCount} icon={<Shield size={18} />} />
        <KpiCard label="Total Reports" value={result?.count ?? reports.length} icon={<Clock size={18} />} />
      </div>

      {/* Filters */}
      <div className="filter-bar mb-4">
        <div style={{ position: 'relative', maxWidth: 320 }}>
          <Search size={16} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--fz-muted-2)' }} />
          <input className="input" style={{ paddingLeft: 36 }} placeholder="Search reports..." value={search} onChange={e => { setSearch(e.target.value); setPage(0); }} />
        </div>
        <select className="input select" style={{ maxWidth: 160 }} value={statusFilter} onChange={e => { setStatusFilter(e.target.value); setPage(0); }}>
          <option value="all">All statuses</option>
          <option value="open">Open</option>
          <option value="investigating">Investigating</option>
          <option value="escalated">Escalated</option>
          <option value="resolved">Resolved</option>
          <option value="dismissed">Dismissed</option>
        </select>
      </div>

      {/* Content */}
      {isLoading ? <LoadingState lines={5} /> :
       error ? <ErrorState onRetry={() => refetch()} /> :
       reports.length === 0 ? <EmptyState title="No reports found" description="The moderation queue is clear." /> : (
        <div className="data-table-container">
          <table className="data-table">
            <thead><tr><th>Report</th><th>Target</th><th>Reason</th><th>Severity</th><th>Status</th><th>Created</th><th className="cell-actions">Actions</th></tr></thead>
            <tbody>
              {reports.map(r => (
                <tr key={r.id} className="cursor-pointer" onClick={() => setSelectedReport(r)}>
                  <td className="mono text-xs">{r.id}</td>
                  <td><span className="badge badge-neutral">{r.target_type}</span> <span className="text-xs mono">{r.target_id}</span></td>
                  <td className="font-medium" style={{ maxWidth: 300, whiteSpace: 'normal' }}>{r.reason}</td>
                  <td><StatusBadge status={r.severity} /></td>
                  <td><StatusBadge status={r.status} /></td>
                  <td className="text-muted">{formatRelativeTime(r.created_at)}</td>
                  <td className="cell-actions">
                    <div className="flex gap-1">
                      {r.status === 'open' && (
                        <button className="btn btn-ghost btn-sm text-accent" onClick={e => { e.stopPropagation(); handleStatusUpdate(r.id, 'investigating'); }} title="Investigate">
                          <Eye size={14} />
                        </button>
                      )}
                      {(r.status === 'open' || r.status === 'investigating') && (
                        <>
                          <button className="btn btn-ghost btn-sm text-success" onClick={e => { e.stopPropagation(); setSelectedReport(r); }} title="Resolve">
                            <CheckCircle size={14} />
                          </button>
                          <button className="btn btn-ghost btn-sm text-error" onClick={e => { e.stopPropagation(); handleStatusUpdate(r.id, 'escalated'); }} title="Escalate">
                            <ArrowUp size={14} />
                          </button>
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="pagination">
            <span>Showing {reports.length} of {result?.count ?? 0} reports</span>
            <div className="pagination-controls">
              <button className="pagination-btn" disabled={page === 0} onClick={() => setPage(p => p - 1)}>←</button>
              <button className="pagination-btn active">{page + 1}</button>
              <button className="pagination-btn" disabled={reports.length < (result?.pageSize ?? 25)} onClick={() => setPage(p => p + 1)}>→</button>
            </div>
          </div>
        </div>
      )}

      {/* Report Detail Drawer */}
      <DetailDrawer
        open={!!selectedReport}
        title={`Report ${selectedReport?.id ?? ''}`}
        subtitle={selectedReport ? `${selectedReport.target_type} / ${selectedReport.target_id}` : undefined}
        onClose={() => { setSelectedReport(null); setResolutionNotes(''); }}
        actions={
          selectedReport && (selectedReport.status === 'open' || selectedReport.status === 'investigating') ? (
            <>
              <button className="btn btn-ghost btn-sm text-success" onClick={() => handleStatusUpdate(selectedReport.id, 'resolved')}>
                <CheckCircle size={14} /> Resolve
              </button>
              <button className="btn btn-ghost btn-sm text-muted" onClick={() => handleStatusUpdate(selectedReport.id, 'dismissed')}>
                <XCircle size={14} /> Dismiss
              </button>
              <button className="btn btn-ghost btn-sm text-error" onClick={() => handleStatusUpdate(selectedReport.id, 'escalated')}>
                <ArrowUp size={14} /> Escalate
              </button>
            </>
          ) : undefined
        }
      >
        {selectedReport && (
          <>
            <DrawerSection title="Report Details">
              <DrawerField label="Target Type" value={selectedReport.target_type} />
              <DrawerField label="Target ID" value={<span className="mono">{selectedReport.target_id}</span>} />
              <DrawerField label="Reason" value={selectedReport.reason} />
              <DrawerField label="Description" value={selectedReport.description || '—'} />
              <DrawerField label="Severity" value={<StatusBadge status={selectedReport.severity} />} />
              <DrawerField label="Status" value={<StatusBadge status={selectedReport.status} />} />
              <DrawerField label="Reporter" value={selectedReport.reporter_user_id || 'System'} />
              <DrawerField label="Created" value={formatDateTime(selectedReport.created_at)} />
              <DrawerField label="Updated" value={formatDateTime(selectedReport.updated_at)} />
            </DrawerSection>
            {selectedReport.resolution_notes && (
              <DrawerSection title="Resolution Notes">
                <p className="text-sm">{selectedReport.resolution_notes}</p>
              </DrawerSection>
            )}
            {(selectedReport.status === 'open' || selectedReport.status === 'investigating') && (
              <DrawerSection title="Add Resolution Notes">
                <textarea
                  className="input"
                  placeholder="Add notes before resolving or dismissing..."
                  rows={3}
                  value={resolutionNotes}
                  onChange={e => setResolutionNotes(e.target.value)}
                  style={{ resize: 'vertical' }}
                />
              </DrawerSection>
            )}
          </>
        )}
      </DetailDrawer>
    </div>
  );
}
