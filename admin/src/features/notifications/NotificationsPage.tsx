// FANZONE Admin — Notifications / Campaigns Page
import { useState } from 'react';
import { PageHeader } from '../../components/layout/PageHeader';
import { KpiCard } from '../../components/ui/KpiCard';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { DetailDrawer, DrawerSection, DrawerField } from '../../components/ui/DetailDrawer';
import { ConfirmDialog } from '../../components/ui/ConfirmDialog';
import { LoadingState, ErrorState, EmptyState } from '../../components/ui/StateViews';
import { useCampaigns, useCreateCampaign, useDeleteCampaign, useSendCampaign } from './useNotifications';
import { useAuditLog } from '../../hooks/useAuditLog';
import { formatDateTime, formatNumber } from '../../lib/formatters';
import { Plus, Search, Send, Trash2, Eye, Bell, Calendar, Users, Megaphone, Edit } from 'lucide-react';
import type { Campaign } from '../../types';

export function NotificationsPage() {
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [selectedCampaign, setSelectedCampaign] = useState<Campaign | null>(null);

  // Create form
  const [showCreate, setShowCreate] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newMessage, setNewMessage] = useState('');
  const [newType, setNewType] = useState('in_app');
  const [newSchedule, setNewSchedule] = useState('');

  // Confirm states
  const [sendTarget, setSendTarget] = useState<Campaign | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Campaign | null>(null);

  // Data
  const { data: result, isLoading, error, refetch } = useCampaigns({ page }, { status: statusFilter, search });
  const createMutation = useCreateCampaign();
  const sendCampaignMutation = useSendCampaign();
  const deleteMutation = useDeleteCampaign();
  const { logAction } = useAuditLog();

  const campaigns = result?.data ?? [];
  const draftCount = campaigns.filter(c => c.status === 'draft').length;
  const scheduledCount = campaigns.filter(c => c.status === 'scheduled').length;
  const sentCount = campaigns.filter(c => c.status === 'sent').length;
  const totalRecipients = campaigns.filter(c => c.status === 'sent').reduce((s, c) => s + c.recipient_count, 0);

  const handleCreate = async () => {
    if (!newTitle.trim() || !newMessage.trim()) return;
    await createMutation.mutateAsync({
      title: newTitle.trim(),
      message: newMessage.trim(),
      type: newType,
      segment: { all_users: true },
      scheduledAt: newSchedule || null,
    });
    await logAction({ action: 'create_campaign', module: 'notifications', afterState: { title: newTitle, type: newType } });
    setShowCreate(false);
    setNewTitle('');
    setNewMessage('');
    setNewType('in_app');
    setNewSchedule('');
  };

  const handleSend = async () => {
    if (!sendTarget) return;
    await sendCampaignMutation.mutateAsync({ p_campaign_id: sendTarget.id });
    await logAction({ action: 'send_campaign', module: 'notifications', targetType: 'campaign', targetId: sendTarget.id });
    setSendTarget(null);
    setSelectedCampaign(null);
  };

  const handleDelete = async () => {
    if (!deleteTarget) return;
    await deleteMutation.mutateAsync({ campaignId: deleteTarget.id });
    await logAction({ action: 'delete_campaign', module: 'notifications', targetType: 'campaign', targetId: deleteTarget.id });
    setDeleteTarget(null);
    setSelectedCampaign(null);
  };

  return (
    <div>
      <PageHeader
        title="Notifications"
        subtitle="Campaign builder and targeted messaging"
        actions={
          <button className="btn btn-primary" onClick={() => setShowCreate(!showCreate)}>
            <Plus size={16} /> New Campaign
          </button>
        }
      />

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard label="Drafts" value={draftCount} icon={<Edit size={18} />} />
        <KpiCard label="Scheduled" value={scheduledCount} icon={<Calendar size={18} />} />
        <KpiCard label="Sent" value={sentCount} icon={<Send size={18} />} />
        <KpiCard label="Total Recipients" value={totalRecipients} icon={<Users size={18} />} />
      </div>

      {/* Create Form */}
      {showCreate && (
        <div className="card mb-4">
          <h3 className="text-md font-semibold mb-4 flex items-center gap-2"><Megaphone size={18} className="text-accent" /> Create Campaign</h3>
          <div className="flex flex-col gap-4">
            <div className="flex gap-4">
              <div className="field-group" style={{ flex: 2 }}>
                <label className="label">Title</label>
                <input className="input" placeholder="Campaign title..." value={newTitle} onChange={e => setNewTitle(e.target.value)} autoFocus />
              </div>
              <div className="field-group" style={{ flex: 1 }}>
                <label className="label">Type</label>
                <select className="input select" value={newType} onChange={e => setNewType(e.target.value)}>
                  <option value="in_app">In-App</option>
                  <option value="push">Push</option>
                </select>
              </div>
              <div className="field-group" style={{ flex: 1 }}>
                <label className="label">Schedule (optional)</label>
                <input className="input" type="datetime-local" value={newSchedule} onChange={e => setNewSchedule(e.target.value)} />
              </div>
            </div>
            <div className="field-group">
              <label className="label">Message</label>
              <textarea
                className="input"
                placeholder="Write your notification message... Use emojis for better engagement."
                rows={3}
                value={newMessage}
                onChange={e => setNewMessage(e.target.value)}
                style={{ resize: 'vertical' }}
              />
              <span className="text-xs text-muted">{newMessage.length} characters</span>
            </div>
            <div className="flex justify-end gap-3">
              <button className="btn btn-secondary" onClick={() => setShowCreate(false)}>Cancel</button>
              <button
                className="btn btn-primary"
                onClick={handleCreate}
                disabled={!newTitle.trim() || !newMessage.trim() || createMutation.isPending}
              >
                {createMutation.isPending ? 'Creating...' : newSchedule ? 'Schedule Campaign' : 'Save as Draft'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Filters */}
      <div className="filter-bar mb-4">
        <div style={{ position: 'relative', maxWidth: 320 }}>
          <Search size={16} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--fz-muted-2)' }} />
          <input className="input" style={{ paddingLeft: 36 }} placeholder="Search campaigns..." value={search} onChange={e => { setSearch(e.target.value); setPage(0); }} />
        </div>
        <select className="input select" style={{ maxWidth: 160 }} value={statusFilter} onChange={e => { setStatusFilter(e.target.value); setPage(0); }}>
          <option value="all">All statuses</option>
          <option value="draft">Draft</option>
          <option value="scheduled">Scheduled</option>
          <option value="sent">Sent</option>
        </select>
      </div>

      {/* Content */}
      {isLoading ? <LoadingState lines={5} /> :
       error ? <ErrorState onRetry={() => refetch()} /> :
       campaigns.length === 0 ? <EmptyState title="No campaigns" description="Create your first campaign to engage users." icon={<Bell size={48} />} /> : (
        <div className="data-table-container">
          <table className="data-table">
            <thead><tr><th>Campaign</th><th>Type</th><th>Status</th><th>Recipients</th><th>Scheduled</th><th>Sent</th><th className="cell-actions">Actions</th></tr></thead>
            <tbody>
              {campaigns.map(c => (
                <tr key={c.id} className="cursor-pointer" onClick={() => setSelectedCampaign(c)}>
                  <td>
                    <div className="font-medium">{c.title}</div>
                    <div className="text-xs text-muted" style={{ maxWidth: 300, overflow: 'hidden', textOverflow: 'ellipsis' }}>{c.message}</div>
                  </td>
                  <td><span className={`badge ${c.type === 'push' ? 'badge-info' : 'badge-neutral'}`}>{c.type}</span></td>
                  <td><StatusBadge status={c.status} /></td>
                  <td className="mono">{c.recipient_count > 0 ? formatNumber(c.recipient_count) : '—'}</td>
                  <td className="text-muted">{c.scheduled_at ? formatDateTime(c.scheduled_at) : '—'}</td>
                  <td className="text-muted">{c.sent_at ? formatDateTime(c.sent_at) : '—'}</td>
                  <td className="cell-actions">
                    <div className="flex gap-1">
                      {(c.status === 'draft' || c.status === 'scheduled') && (
                        <button className="btn btn-ghost btn-sm text-success" onClick={e => { e.stopPropagation(); setSendTarget(c); }} title="Send Now">
                          <Send size={14} />
                        </button>
                      )}
                      {c.status === 'draft' && (
                        <button className="btn btn-ghost btn-sm text-error" onClick={e => { e.stopPropagation(); setDeleteTarget(c); }} title="Delete">
                          <Trash2 size={14} />
                        </button>
                      )}
                      <button className="btn btn-ghost btn-sm" onClick={e => { e.stopPropagation(); setSelectedCampaign(c); }} title="View">
                        <Eye size={14} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="pagination">
            <span>Showing {campaigns.length} of {result?.count ?? 0} campaigns</span>
            <div className="pagination-controls">
              <button className="pagination-btn" disabled={page === 0} onClick={() => setPage(p => p - 1)}>←</button>
              <button className="pagination-btn active">{page + 1}</button>
              <button className="pagination-btn" disabled={campaigns.length < (result?.pageSize ?? 25)} onClick={() => setPage(p => p + 1)}>→</button>
            </div>
          </div>
        </div>
      )}

      {/* Campaign Detail Drawer */}
      <DetailDrawer
        open={!!selectedCampaign}
        title={selectedCampaign?.title ?? ''}
        subtitle={selectedCampaign?.id}
        onClose={() => setSelectedCampaign(null)}
        actions={
          selectedCampaign && (selectedCampaign.status === 'draft' || selectedCampaign.status === 'scheduled') ? (
            <>
              <button className="btn btn-primary btn-sm" onClick={() => setSendTarget(selectedCampaign)}>
                <Send size={14} /> Send Now
              </button>
              {selectedCampaign.status === 'draft' && (
                <button className="btn btn-danger btn-sm" onClick={() => setDeleteTarget(selectedCampaign)}>
                  <Trash2 size={14} /> Delete
                </button>
              )}
            </>
          ) : undefined
        }
      >
        {selectedCampaign && (
          <>
            <DrawerSection title="Campaign Details">
              <DrawerField label="Title" value={selectedCampaign.title} />
              <DrawerField label="Type" value={<span className={`badge ${selectedCampaign.type === 'push' ? 'badge-info' : 'badge-neutral'}`}>{selectedCampaign.type}</span>} />
              <DrawerField label="Status" value={<StatusBadge status={selectedCampaign.status} />} />
              <DrawerField label="Created" value={formatDateTime(selectedCampaign.created_at)} />
              {selectedCampaign.scheduled_at && <DrawerField label="Scheduled" value={formatDateTime(selectedCampaign.scheduled_at)} />}
              {selectedCampaign.sent_at && <DrawerField label="Sent" value={formatDateTime(selectedCampaign.sent_at)} />}
              {selectedCampaign.recipient_count > 0 && <DrawerField label="Recipients" value={formatNumber(selectedCampaign.recipient_count)} />}
            </DrawerSection>
            <DrawerSection title="Message">
              <div className="p-3" style={{ background: 'var(--fz-surface-2)', borderRadius: 'var(--fz-radius)', whiteSpace: 'pre-wrap' }}>
                <p className="text-sm">{selectedCampaign.message}</p>
              </div>
            </DrawerSection>
            <DrawerSection title="Segment">
              <pre style={{ background: 'var(--fz-surface-2)', padding: 'var(--fz-sp-3)', borderRadius: 'var(--fz-radius)', fontSize: 'var(--fz-text-xs)', overflow: 'auto', whiteSpace: 'pre-wrap' }}>
                {JSON.stringify(selectedCampaign.segment, null, 2)}
              </pre>
            </DrawerSection>
          </>
        )}
      </DetailDrawer>

      {/* Send Confirmation */}
      <ConfirmDialog
        open={!!sendTarget}
        title="Send Campaign Now"
        description={sendTarget ? `Send "${sendTarget.title}" to all targeted users? This action cannot be undone.` : ''}
        confirmLabel="Send Now"
        onConfirm={handleSend}
        onCancel={() => setSendTarget(null)}
      />

      {/* Delete Confirmation */}
      <ConfirmDialog
        open={!!deleteTarget}
        title="Delete Campaign"
        description={deleteTarget ? `Delete "${deleteTarget.title}"? This action cannot be undone.` : ''}
        confirmLabel="Delete"
        onConfirm={handleDelete}
        onCancel={() => setDeleteTarget(null)}
      />
    </div>
  );
}
