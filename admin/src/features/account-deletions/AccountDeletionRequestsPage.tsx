import { useMemo, useState } from 'react';
import { Search, ShieldCheck, UserX, CircleOff, Eye } from 'lucide-react';

import { PageHeader } from '../../components/layout/PageHeader';
import { DetailDrawer, DrawerField, DrawerSection } from '../../components/ui/DetailDrawer';
import { EmptyState, ErrorState, LoadingState } from '../../components/ui/StateViews';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { useSupabaseMutation, useSupabasePaginated } from '../../hooks/useSupabaseQuery';
import { useAuditLog } from '../../hooks/useAuditLog';
import { useAuth } from '../../hooks/useAuth';
import { adminEnvError, isDemoMode, isSupabaseConfigured, supabase } from '../../lib/supabase';
import { formatDateTime } from '../../lib/formatters';

type RequestStatus = 'pending' | 'in_review' | 'completed' | 'rejected' | 'cancelled';

interface AccountDeletionRequestRecord {
  id: string;
  user_id: string;
  status: RequestStatus;
  reason: string;
  contact_email: string | null;
  resolution_notes: string | null;
  requested_at: string;
  processed_at: string | null;
  updated_at: string;
}

const STATUS_OPTIONS: Array<{ label: string; value: RequestStatus | 'all' }> = [
  { label: 'All statuses', value: 'all' },
  { label: 'Pending', value: 'pending' },
  { label: 'In review', value: 'in_review' },
  { label: 'Completed', value: 'completed' },
  { label: 'Rejected', value: 'rejected' },
  { label: 'Cancelled', value: 'cancelled' },
];

export function AccountDeletionRequestsPage() {
  const { admin } = useAuth();
  const { logAction } = useAuditLog();

  const [page, setPage] = useState(0);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<RequestStatus | 'all'>('all');
  const [selectedRequest, setSelectedRequest] = useState<AccountDeletionRequestRecord | null>(null);
  const [resolutionNotes, setResolutionNotes] = useState('');

  const queryKey = useMemo(
    () => ['account-deletion-requests', search, statusFilter] as const,
    [search, statusFilter],
  );

  const {
    data: result,
    isLoading,
    error,
    refetch,
  } = useSupabasePaginated<AccountDeletionRequestRecord>(
    queryKey,
    'account_deletion_requests',
    {
      pagination: { page },
      select:
        'id, user_id, status, reason, contact_email, resolution_notes, requested_at, processed_at, updated_at',
      filters: (query) => {
        let next = query;
        if (statusFilter !== 'all') {
          next = next.eq('status', statusFilter);
        }
        if (search.trim()) {
          const escaped = search.trim().replace(/[%_,]/g, ' ').trim();
          next = next.or(
            `user_id.ilike.%${escaped}%,contact_email.ilike.%${escaped}%,reason.ilike.%${escaped}%,resolution_notes.ilike.%${escaped}%`,
          );
        }
        return next;
      },
      order: { column: 'requested_at', ascending: false },
    },
  );

  const updateMutation = useSupabaseMutation<{
    requestId: string;
    nextStatus: RequestStatus;
    resolutionNotes: string;
  }>({
    mutationFn: async ({ requestId, nextStatus, resolutionNotes }) => {
      if (isDemoMode) {
        return { id: requestId, status: nextStatus };
      }
      if (!isSupabaseConfigured) {
        throw new Error(adminEnvError);
      }

      const now = new Date().toISOString();
      const { data, error } = await supabase
        .from('account_deletion_requests')
        .update({
          status: nextStatus,
          resolution_notes: resolutionNotes.trim() || null,
          processed_at:
            nextStatus === 'pending' ? null : now,
          processed_by:
            nextStatus === 'pending' ? null : (admin?.user_id ?? null),
          updated_at: now,
        })
        .eq('id', requestId)
        .select(
          'id, user_id, status, reason, contact_email, resolution_notes, requested_at, processed_at, updated_at',
        )
        .single();

      if (error) {
        throw new Error(error.message);
      }

      return data;
    },
    invalidateKeys: [['account-deletion-requests']],
    successMessage: 'Deletion request updated.',
  });

  function openRequest(request: AccountDeletionRequestRecord) {
    setSelectedRequest(request);
    setResolutionNotes(request.resolution_notes ?? '');
  }

  const requests = result?.data ?? [];
  const pendingCount = requests.filter((request) => request.status === 'pending').length;
  const inReviewCount = requests.filter((request) => request.status === 'in_review').length;

  async function handleStatusChange(nextStatus: RequestStatus) {
    if (!selectedRequest) return;

    await updateMutation.mutateAsync({
      requestId: selectedRequest.id,
      nextStatus,
      resolutionNotes,
    });
    await logAction({
      action: 'account_deletion_request_status_changed',
      module: 'account_deletions',
      targetType: 'account_deletion_request',
      targetId: selectedRequest.id,
      beforeState: { status: selectedRequest.status },
      afterState: { status: nextStatus, resolutionNotes },
    });
    setSelectedRequest((current) =>
      current
        ? {
            ...current,
            status: nextStatus,
            resolution_notes: resolutionNotes.trim() || null,
            processed_at:
              nextStatus === 'pending' ? null : new Date().toISOString(),
          }
        : current,
    );
  }

  return (
    <div>
      <PageHeader
        title="Account Deletions"
        subtitle="User deletion requests awaiting review or completion"
      />

      <div className="grid grid-3 gap-4 mb-6">
        <div className="card">
          <div className="text-sm text-muted">Visible Requests</div>
          <div className="text-2xl font-semibold">{result?.count ?? 0}</div>
        </div>
        <div className="card">
          <div className="text-sm text-muted">Pending</div>
          <div className="text-2xl font-semibold">{pendingCount}</div>
        </div>
        <div className="card">
          <div className="text-sm text-muted">In Review</div>
          <div className="text-2xl font-semibold">{inReviewCount}</div>
        </div>
      </div>

      <div className="filter-bar mb-4">
        <div style={{ position: 'relative', maxWidth: 360 }}>
          <Search
            size={16}
            style={{
              position: 'absolute',
              left: 12,
              top: '50%',
              transform: 'translateY(-50%)',
              color: 'var(--fz-muted-2)',
            }}
          />
          <input
            className="input"
            style={{ paddingLeft: 36 }}
            placeholder="Search by user, email, or reason..."
            value={search}
            onChange={(event) => {
              setSearch(event.target.value);
              setPage(0);
            }}
          />
        </div>
        <select
          className="input select"
          style={{ maxWidth: 180 }}
          value={statusFilter}
          onChange={(event) => {
            setStatusFilter(event.target.value as RequestStatus | 'all');
            setPage(0);
          }}
        >
          {STATUS_OPTIONS.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      </div>

      {isLoading ? (
        <LoadingState lines={6} />
      ) : error ? (
        <ErrorState
          title="Deletion requests unavailable"
          onRetry={() => refetch()}
        />
      ) : requests.length === 0 ? (
        <EmptyState
          title="No deletion requests"
          description="When users submit deletion requests, they will appear here."
          icon={<UserX size={48} />}
        />
      ) : (
        <div className="data-table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Requester</th>
                <th>Status</th>
                <th>Requested</th>
                <th>Processed</th>
                <th>Contact</th>
                <th className="cell-actions">Actions</th>
              </tr>
            </thead>
            <tbody>
              {requests.map((request) => (
                <tr
                  key={request.id}
                  className="cursor-pointer"
                  onClick={() => openRequest(request)}
                >
                  <td>
                    <div className="font-medium mono">{request.user_id}</div>
                    <div
                      className="text-xs text-muted"
                      style={{
                        maxWidth: 320,
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                      }}
                    >
                      {request.reason}
                    </div>
                  </td>
                  <td>
                    <StatusBadge status={request.status} />
                  </td>
                  <td className="text-muted">{formatDateTime(request.requested_at)}</td>
                  <td className="text-muted">
                    {request.processed_at ? formatDateTime(request.processed_at) : '—'}
                  </td>
                  <td className="text-muted">{request.contact_email || '—'}</td>
                  <td className="cell-actions">
                    <button
                      className="btn btn-ghost btn-sm"
                      title="View"
                      onClick={(event) => {
                        event.stopPropagation();
                        openRequest(request);
                      }}
                    >
                      <Eye size={14} />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          <div className="pagination">
            <span>
              Showing {requests.length} of {result?.count ?? 0} requests
            </span>
            <div className="pagination-controls">
              <button
                className="pagination-btn"
                disabled={page === 0}
                onClick={() => setPage((current) => current - 1)}
              >
                ←
              </button>
              <button className="pagination-btn active">{page + 1}</button>
              <button
                className="pagination-btn"
                disabled={requests.length < (result?.pageSize ?? 25)}
                onClick={() => setPage((current) => current + 1)}
              >
                →
              </button>
            </div>
          </div>
        </div>
      )}

      <DetailDrawer
        open={!!selectedRequest}
        title="Deletion request"
        subtitle={selectedRequest?.id}
        onClose={() => setSelectedRequest(null)}
        actions={
          selectedRequest ? (
            <>
              {selectedRequest.status === 'pending' && (
                <button
                  className="btn btn-secondary btn-sm"
                  onClick={() => handleStatusChange('in_review')}
                  disabled={updateMutation.isPending}
                >
                  <ShieldCheck size={14} /> In review
                </button>
              )}
              {(selectedRequest.status === 'pending' ||
                selectedRequest.status === 'in_review') && (
                <>
                  <button
                    className="btn btn-primary btn-sm"
                    onClick={() => handleStatusChange('completed')}
                    disabled={updateMutation.isPending}
                  >
                    <ShieldCheck size={14} /> Complete
                  </button>
                  <button
                    className="btn btn-danger btn-sm"
                    onClick={() => handleStatusChange('rejected')}
                    disabled={updateMutation.isPending}
                  >
                    <CircleOff size={14} /> Reject
                  </button>
                </>
              )}
            </>
          ) : undefined
        }
      >
        {selectedRequest && (
          <>
            <DrawerSection title="Request">
              <DrawerField label="User ID" value={selectedRequest.user_id} />
              <DrawerField
                label="Status"
                value={<StatusBadge status={selectedRequest.status} />}
              />
              <DrawerField
                label="Requested"
                value={formatDateTime(selectedRequest.requested_at)}
              />
              <DrawerField
                label="Processed"
                value={
                  selectedRequest.processed_at
                    ? formatDateTime(selectedRequest.processed_at)
                    : '—'
                }
              />
              <DrawerField
                label="Contact email"
                value={selectedRequest.contact_email || '—'}
              />
            </DrawerSection>

            <DrawerSection title="Reason">
              <p className="text-sm" style={{ lineHeight: 1.6 }}>
                {selectedRequest.reason}
              </p>
            </DrawerSection>

            <DrawerSection title="Resolution Notes">
              <textarea
                className="input"
                rows={4}
                value={resolutionNotes}
                onChange={(event) => setResolutionNotes(event.target.value)}
                placeholder="Add verification notes, the reason for rejection, or completion details..."
                style={{ resize: 'vertical' }}
              />
            </DrawerSection>
          </>
        )}
      </DetailDrawer>
    </div>
  );
}
