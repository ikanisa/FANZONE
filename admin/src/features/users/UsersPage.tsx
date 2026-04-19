// FANZONE Admin — Users Page — Live Data
import { useState } from 'react';
import { PageHeader } from '../../components/layout/PageHeader';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { DetailDrawer, DrawerSection, DrawerField } from '../../components/ui/DetailDrawer';
import { ConfirmDialog } from '../../components/ui/ConfirmDialog';
import { LoadingState, ErrorState, EmptyState } from '../../components/ui/StateViews';
import { useUsers, useBanUser, useUnbanUser } from './useUsers';
import { getUserDisplayName, getUserStatus } from './userHelpers';
import { formatDateTime, formatFET, formatRelativeTime } from '../../lib/formatters';
import { Search, Download, Eye, Ban, ShieldOff, MessageSquare } from 'lucide-react';
import type { PlatformUser } from '../../types';

export function UsersPage() {
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [selectedUser, setSelectedUser] = useState<PlatformUser | null>(null);

  // Action states
  const [banTarget, setBanTarget] = useState<PlatformUser | null>(null);
  const [banReason, setBanReason] = useState('');
  const [unbanTarget, setUnbanTarget] = useState<PlatformUser | null>(null);

  // Data
  const { data: result, isLoading, error, refetch } = useUsers({ page }, { search, status: statusFilter });
  const banMutation = useBanUser();
  const unbanMutation = useUnbanUser();

  const users = result?.data ?? [];

  const handleBan = async () => {
    if (!banTarget) return;
    await banMutation.mutateAsync({
      p_target_user_id: banTarget.id,
      p_reason: banReason,
      p_banned_until: null, // Permanent unless specified
    });
    setBanTarget(null);
    setBanReason('');
    setSelectedUser(null);
  };

  const handleUnban = async () => {
    if (!unbanTarget) return;
    await unbanMutation.mutateAsync({ p_target_user_id: unbanTarget.id });
    setUnbanTarget(null);
    setSelectedUser(null);
  };

  return (
    <div>
      <PageHeader
        title="Users"
        subtitle={`${result?.count ?? 0} registered users`}
        actions={
          <button className="btn btn-secondary">
            <Download size={16} /> Export
          </button>
        }
      />

      {/* Filter Bar */}
      <div className="filter-bar mb-4">
        <div className="flex items-center gap-2" style={{ position: 'relative', flex: 1, maxWidth: 360 }}>
          <Search size={16} style={{ position: 'absolute', left: 12, color: 'var(--fz-muted-2)' }} />
          <input
            className="input"
            style={{ paddingLeft: 36 }}
            placeholder="Search by name, email, phone, or ID..."
            value={search}
            onChange={e => { setSearch(e.target.value); setPage(0); }}
          />
        </div>
        <select className="input select" style={{ maxWidth: 160 }} value={statusFilter} onChange={e => { setStatusFilter(e.target.value); setPage(0); }}>
          <option value="all">All statuses</option>
          <option value="active">Active</option>
          <option value="banned">Banned</option>
          <option value="suspended">Suspended</option>
        </select>
      </div>

      {/* Content */}
      {isLoading ? <LoadingState lines={8} /> :
       error ? <ErrorState onRetry={() => refetch()} /> :
       users.length === 0 ? <EmptyState title="No users found" description="Try adjusting your search or filters." /> : (
        <div className="data-table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>User</th>
                <th>Contact</th>
                <th>Status</th>
                <th>FET Balance</th>
                <th>Joined</th>
                <th>Last Active</th>
                <th className="cell-actions">Actions</th>
              </tr>
            </thead>
            <tbody>
              {users.map(user => {
                const name = getUserDisplayName(user);
                const status = getUserStatus(user);
                return (
                  <tr key={user.id} className="cursor-pointer" onClick={() => setSelectedUser(user)}>
                    <td>
                      <div>
                        <div className="font-medium">{name}</div>
                        <div className="text-xs text-muted mono">{user.id}</div>
                      </div>
                    </td>
                    <td>
                      <div className="text-sm">{user.email || '—'}</div>
                      <div className="text-xs text-muted">{user.phone || '—'}</div>
                    </td>
                    <td><StatusBadge status={status} /></td>
                    <td className="mono">{formatFET(user.available_balance_fet ?? 0)}</td>
                    <td className="text-muted">{formatDateTime(user.created_at)}</td>
                    <td className="text-muted">{user.last_sign_in_at ? formatRelativeTime(user.last_sign_in_at) : '—'}</td>
                    <td className="cell-actions">
                      <div className="flex gap-1">
                        <button className="btn btn-ghost btn-sm" onClick={e => { e.stopPropagation(); setSelectedUser(user); }} title="View">
                          <Eye size={14} />
                        </button>
                        {status === 'active' ? (
                          <button className="btn btn-ghost btn-sm text-error" onClick={e => { e.stopPropagation(); setBanTarget(user); }} title="Ban">
                            <Ban size={14} />
                          </button>
                        ) : status === 'banned' ? (
                          <button className="btn btn-ghost btn-sm text-success" onClick={e => { e.stopPropagation(); setUnbanTarget(user); }} title="Unban">
                            <ShieldOff size={14} />
                          </button>
                        ) : null}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          <div className="pagination">
            <span>Showing {users.length} of {result?.count ?? 0} users</span>
            <div className="pagination-controls">
              <button className="pagination-btn" disabled={page === 0} onClick={() => setPage(p => p - 1)}>←</button>
              <button className="pagination-btn active">{page + 1}</button>
              <button className="pagination-btn" disabled={users.length < (result?.pageSize ?? 25)} onClick={() => setPage(p => p + 1)}>→</button>
            </div>
          </div>
        </div>
      )}

      {/* User Detail Drawer */}
      <DetailDrawer
        open={!!selectedUser}
        title={selectedUser ? getUserDisplayName(selectedUser) : ''}
        subtitle={selectedUser?.id}
        onClose={() => setSelectedUser(null)}
        actions={
          selectedUser ? (
            <>
              <button className="btn btn-ghost btn-sm"><MessageSquare size={14} /> Note</button>
              {getUserStatus(selectedUser) === 'active' ? (
                <button className="btn btn-danger btn-sm" onClick={() => setBanTarget(selectedUser)}>
                  <Ban size={14} /> Ban
                </button>
              ) : getUserStatus(selectedUser) === 'banned' ? (
                <button className="btn btn-primary btn-sm" onClick={() => setUnbanTarget(selectedUser)}>
                  <ShieldOff size={14} /> Unban
                </button>
              ) : null}
            </>
          ) : undefined
        }
      >
        {selectedUser && (
          <>
            <DrawerSection title="Profile">
              <DrawerField label="Display Name" value={getUserDisplayName(selectedUser)} />
              <DrawerField label="Email" value={selectedUser.email || '—'} />
              <DrawerField label="Phone" value={selectedUser.phone || '—'} />
              <DrawerField label="Status" value={<StatusBadge status={getUserStatus(selectedUser)} />} />
              <DrawerField label="Joined" value={formatDateTime(selectedUser.created_at)} />
              <DrawerField label="Last Active" value={selectedUser.last_sign_in_at ? formatRelativeTime(selectedUser.last_sign_in_at) : '—'} />
            </DrawerSection>
            <DrawerSection title="Wallet">
              <DrawerField label="Available FET" value={formatFET(selectedUser.available_balance_fet ?? 0)} />
              <DrawerField label="Locked FET" value={formatFET(selectedUser.locked_balance_fet ?? 0)} />
              <DrawerField label="Total FET" value={formatFET((selectedUser.available_balance_fet ?? 0) + (selectedUser.locked_balance_fet ?? 0))} />
            </DrawerSection>
            {selectedUser.raw_user_meta_data?.ban_reason && (
              <DrawerSection title="Ban Info">
                <DrawerField label="Reason" value={<span className="text-error">{selectedUser.raw_user_meta_data.ban_reason as string}</span>} />
              </DrawerSection>
            )}
            <DrawerSection title="Admin Notes">
              <p className="text-sm text-muted">No admin notes yet.</p>
            </DrawerSection>
          </>
        )}
      </DetailDrawer>

      {/* Ban Modal */}
      {banTarget && (
        <div className="modal-overlay" onClick={() => { setBanTarget(null); setBanReason(''); }}>
          <div className="modal-panel" onClick={e => e.stopPropagation()}>
            <div className="flex items-start gap-4 mb-4">
              <div style={{ color: 'var(--fz-error)', flexShrink: 0 }}>
                <Ban size={24} />
              </div>
              <div>
                <h3 className="text-md font-semibold mb-1">Ban User</h3>
                <p className="text-sm text-muted">
                  Ban {getUserDisplayName(banTarget)} ({banTarget.id}). This will prevent them from logging in and freeze their wallet.
                </p>
              </div>
            </div>
            <div className="field-group mb-4">
              <label className="label">Reason (required)</label>
              <textarea
                className="input"
                placeholder="Why is this user being banned?"
                rows={3}
                value={banReason}
                onChange={e => setBanReason(e.target.value)}
                style={{ resize: 'vertical' }}
              />
            </div>
            <div className="flex justify-end gap-3">
              <button className="btn btn-secondary" onClick={() => { setBanTarget(null); setBanReason(''); }} disabled={banMutation.isPending}>Cancel</button>
              <button className="btn btn-danger" onClick={handleBan} disabled={banReason.trim().length < 3 || banMutation.isPending}>
                {banMutation.isPending ? 'Banning...' : 'Ban User'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Unban Confirm */}
      <ConfirmDialog
        open={!!unbanTarget}
        title="Unban User"
        description={unbanTarget ? `Unban ${getUserDisplayName(unbanTarget)}? This will restore their access and unfreeze their wallet.` : ''}
        confirmLabel="Unban"
        onConfirm={handleUnban}
        onCancel={() => setUnbanTarget(null)}
      />
    </div>
  );
}
