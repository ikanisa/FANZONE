// FANZONE Admin — Partners Page — Live Data
import { useState } from 'react';
import { PageHeader } from '../../components/layout/PageHeader';
import { KpiCard } from '../../components/ui/KpiCard';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { DetailDrawer, DrawerSection, DrawerField } from '../../components/ui/DetailDrawer';

import { LoadingState, ErrorState, EmptyState } from '../../components/ui/StateViews';
import { usePartners, useApprovePartner, useRejectPartner, useToggleFeatured } from './usePartners';
import { formatDateTime } from '../../lib/formatters';
import { Plus, Search, Star, StarOff, Check, X as XIcon, Eye, Handshake, Clock, ThumbsUp, ThumbsDown } from 'lucide-react';
import type { Partner } from '../../types';

export function PartnersPage() {
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [selectedPartner, setSelectedPartner] = useState<Partner | null>(null);

  // Action states
  const [rejectTarget, setRejectTarget] = useState<Partner | null>(null);
  const [rejectReason, setRejectReason] = useState('');

  // Data
  const { data: result, isLoading, error, refetch } = usePartners({ page }, { search, status: statusFilter });
  const approveMutation = useApprovePartner();
  const rejectMutation = useRejectPartner();
  const toggleFeaturedMutation = useToggleFeatured();

  const partners = result?.data ?? [];
  const pendingCount = partners.filter(p => p.status === 'pending').length;
  const approvedCount = partners.filter(p => p.status === 'approved').length;
  const featuredCount = partners.filter(p => p.is_featured).length;

  const handleApprove = async (partner: Partner) => {
    await approveMutation.mutateAsync({ p_partner_id: partner.id });
    setSelectedPartner(null);
  };

  const handleReject = async () => {
    if (!rejectTarget) return;
    await rejectMutation.mutateAsync({
      p_partner_id: rejectTarget.id,
      p_reason: rejectReason,
    });
    setRejectTarget(null);
    setRejectReason('');
    setSelectedPartner(null);
  };

  const handleToggleFeatured = async (partner: Partner) => {
    const newFeatured = !partner.is_featured;
    await toggleFeaturedMutation.mutateAsync({
      p_partner_id: partner.id,
      p_is_featured: newFeatured,
    });
  };

  return (
    <div>
      <PageHeader
        title="Partners"
        subtitle={`${result?.count ?? partners.length} partners — ${pendingCount} pending review`}
        actions={<button className="btn btn-primary"><Plus size={16} /> Add Partner</button>}
      />

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard label="Total Partners" value={result?.count ?? partners.length} icon={<Handshake size={18} />} />
        <KpiCard label="Approved" value={approvedCount} icon={<ThumbsUp size={18} />} />
        <KpiCard label="Pending Review" value={pendingCount} icon={<Clock size={18} />} />
        <KpiCard label="Featured" value={featuredCount} icon={<Star size={18} />} />
      </div>

      {/* Filters */}
      <div className="filter-bar mb-4">
        <div style={{ position: 'relative', maxWidth: 320 }}>
          <Search size={16} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--fz-muted-2)' }} />
          <input className="input" style={{ paddingLeft: 36 }} placeholder="Search partners..." value={search} onChange={e => { setSearch(e.target.value); setPage(0); }} />
        </div>
        <select className="input select" style={{ maxWidth: 160 }} value={statusFilter} onChange={e => { setStatusFilter(e.target.value); setPage(0); }}>
          <option value="all">All statuses</option>
          <option value="pending">Pending</option>
          <option value="approved">Approved</option>
          <option value="rejected">Rejected</option>
        </select>
      </div>

      {/* Content */}
      {isLoading ? <LoadingState lines={5} /> :
       error ? <ErrorState onRetry={() => refetch()} /> :
       partners.length === 0 ? <EmptyState title="No partners found" /> : (
        <div className="data-table-container">
          <table className="data-table">
            <thead><tr><th>Partner</th><th>Category</th><th>Country</th><th>Contact</th><th>Featured</th><th>Status</th><th className="cell-actions">Actions</th></tr></thead>
            <tbody>
              {partners.map(p => (
                <tr key={p.id} className="cursor-pointer" onClick={() => setSelectedPartner(p)}>
                  <td><div className="font-medium">{p.name}</div><div className="text-xs text-muted mono">{p.id}</div></td>
                  <td><span className="badge badge-neutral">{p.category}</span></td>
                  <td>{p.country}</td>
                  <td className="text-sm text-muted">{p.contact_email || '—'}</td>
                  <td>
                    <button
                      className="btn btn-ghost btn-icon btn-sm"
                      onClick={e => { e.stopPropagation(); handleToggleFeatured(p); }}
                      title={p.is_featured ? 'Remove from featured' : 'Add to featured'}
                      disabled={p.status !== 'approved'}
                    >
                      {p.is_featured ? <Star size={16} className="text-warning" /> : <StarOff size={16} className="text-muted" />}
                    </button>
                  </td>
                  <td><StatusBadge status={p.status} /></td>
                  <td className="cell-actions">
                    <div className="flex gap-1">
                      {p.status === 'pending' && (
                        <>
                          <button className="btn btn-ghost btn-sm text-success" onClick={e => { e.stopPropagation(); handleApprove(p); }} title="Approve">
                            <Check size={14} /> Approve
                          </button>
                          <button className="btn btn-ghost btn-sm text-error" onClick={e => { e.stopPropagation(); setRejectTarget(p); }} title="Reject">
                            <XIcon size={14} /> Reject
                          </button>
                        </>
                      )}
                      <button className="btn btn-ghost btn-sm" onClick={e => { e.stopPropagation(); setSelectedPartner(p); }} title="View">
                        <Eye size={14} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="pagination">
            <span>Showing {partners.length} of {result?.count ?? 0} partners</span>
            <div className="pagination-controls">
              <button className="pagination-btn" disabled={page === 0} onClick={() => setPage(p => p - 1)}>←</button>
              <button className="pagination-btn active">{page + 1}</button>
              <button className="pagination-btn" disabled={partners.length < (result?.pageSize ?? 25)} onClick={() => setPage(p => p + 1)}>→</button>
            </div>
          </div>
        </div>
      )}

      {/* Partner Detail Drawer */}
      <DetailDrawer
        open={!!selectedPartner}
        title={selectedPartner?.name ?? ''}
        subtitle={selectedPartner?.id}
        onClose={() => setSelectedPartner(null)}
        actions={
          selectedPartner?.status === 'pending' ? (
            <>
              <button className="btn btn-primary btn-sm" onClick={() => handleApprove(selectedPartner)}>
                <Check size={14} /> Approve
              </button>
              <button className="btn btn-danger btn-sm" onClick={() => setRejectTarget(selectedPartner)}>
                <XIcon size={14} /> Reject
              </button>
            </>
          ) : undefined
        }
      >
        {selectedPartner && (
          <>
            <DrawerSection title="Partner Info">
              <DrawerField label="Name" value={selectedPartner.name} />
              <DrawerField label="Category" value={<span className="badge badge-neutral">{selectedPartner.category}</span>} />
              <DrawerField label="Country" value={selectedPartner.country} />
              <DrawerField label="Market" value={selectedPartner.market} />
              <DrawerField label="Status" value={<StatusBadge status={selectedPartner.status} />} />
              <DrawerField label="Featured" value={selectedPartner.is_featured ? '⭐ Yes' : 'No'} />
              <DrawerField label="Created" value={formatDateTime(selectedPartner.created_at)} />
              <DrawerField label="Updated" value={formatDateTime(selectedPartner.updated_at)} />
            </DrawerSection>
            <DrawerSection title="Contact">
              <DrawerField label="Email" value={selectedPartner.contact_email || '—'} />
              <DrawerField label="Phone" value={selectedPartner.contact_phone || '—'} />
              <DrawerField label="Website" value={
                selectedPartner.website_url ? (
                  <a href={selectedPartner.website_url} target="_blank" rel="noopener noreferrer" className="text-accent">
                    {selectedPartner.website_url}
                  </a>
                ) : '—'
              } />
            </DrawerSection>
            {selectedPartner.description && (
              <DrawerSection title="Description">
                <p className="text-sm">{selectedPartner.description}</p>
              </DrawerSection>
            )}
            {selectedPartner.metadata?.rejection_reason && (
              <DrawerSection title="Rejection">
                <p className="text-sm text-error">{selectedPartner.metadata.rejection_reason as string}</p>
              </DrawerSection>
            )}
          </>
        )}
      </DetailDrawer>

      {/* Reject Modal */}
      {rejectTarget && (
        <div className="modal-overlay" onClick={() => { setRejectTarget(null); setRejectReason(''); }}>
          <div className="modal-panel" onClick={e => e.stopPropagation()}>
            <div className="flex items-start gap-4 mb-4">
              <div style={{ color: 'var(--fz-error)', flexShrink: 0 }}><ThumbsDown size={24} /></div>
              <div>
                <h3 className="text-md font-semibold mb-1">Reject Partner</h3>
                <p className="text-sm text-muted">
                  Reject {rejectTarget.name}? This will notify the applicant.
                </p>
              </div>
            </div>
            <div className="field-group mb-4">
              <label className="label">Reason (required)</label>
              <textarea className="input" placeholder="Why is this partner being rejected?" rows={3} value={rejectReason} onChange={e => setRejectReason(e.target.value)} style={{ resize: 'vertical' }} />
            </div>
            <div className="flex justify-end gap-3">
              <button className="btn btn-secondary" onClick={() => { setRejectTarget(null); setRejectReason(''); }} disabled={rejectMutation.isPending}>Cancel</button>
              <button className="btn btn-danger" onClick={handleReject} disabled={rejectReason.trim().length < 3 || rejectMutation.isPending}>
                {rejectMutation.isPending ? 'Rejecting...' : 'Reject Partner'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
