// FANZONE Admin — Admin Access Page — Live Data
import { useState } from 'react';
import { PageHeader } from '../../components/layout/PageHeader';
import { KpiCard } from '../../components/ui/KpiCard';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { ConfirmDialog } from '../../components/ui/ConfirmDialog';
import { LoadingState, ErrorState } from '../../components/ui/StateViews';
import { useAdminUsers, useInviteAdmin, useRevokeAdmin, useChangeAdminRole } from './useAdminAccess';
import { formatDateTime } from '../../lib/formatters';
import { UserPlus, Shield, Trash2, Users, UserCheck, UserX } from 'lucide-react';
import type { AdminUser } from '../../types';
import type { AdminRole } from '../../config/constants';

export function AdminAccessPage() {
  const [page] = useState(0);
  const [showInvite, setShowInvite] = useState(false);
  const [invitePhone, setInvitePhone] = useState('');
  const [inviteRole, setInviteRole] = useState<AdminRole>('viewer');
  const [confirmRevoke, setConfirmRevoke] = useState<AdminUser | null>(null);

  const { data: result, isLoading, error, refetch } = useAdminUsers({ page });
  const inviteMutation = useInviteAdmin();
  const revokeMutation = useRevokeAdmin();
  const changeRoleMutation = useChangeAdminRole();

  const admins = result?.data ?? [];
  const activeCount = admins.filter(a => a.is_active).length;

  const handleInvite = async () => {
    if (!invitePhone.trim()) return;
    await inviteMutation.mutateAsync({
      p_phone: invitePhone.trim(),
      p_role: inviteRole,
    });
    setShowInvite(false); setInvitePhone(''); setInviteRole('viewer');
  };

  const handleRevoke = async () => {
    if (!confirmRevoke) return;
    await revokeMutation.mutateAsync({ p_admin_id: confirmRevoke.id });
    setConfirmRevoke(null);
  };

  const handleRoleChange = async (adminUser: AdminUser, newRole: AdminRole) => {
    await changeRoleMutation.mutateAsync({
      p_admin_id: adminUser.id,
      p_role: newRole,
    });
  };

  return (
    <div>
      <PageHeader title="Admin Access" subtitle="Manage admin users, roles, and permissions" actions={<button className="btn btn-primary" onClick={() => setShowInvite(!showInvite)}><UserPlus size={16} /> Grant Access</button>} />

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard label="Total Admins" value={admins.length} icon={<Users size={18} />} />
        <KpiCard label="Active" value={activeCount} icon={<UserCheck size={18} />} />
        <KpiCard label="Inactive" value={admins.length - activeCount} icon={<UserX size={18} />} />
        <KpiCard label="Roles" value={[...new Set(admins.map(a => a.role))].length} icon={<Shield size={18} />} />
      </div>

      {/* Invite Form */}
      {showInvite && (
        <div className="card mb-4">
          <h3 className="text-md font-semibold mb-2 flex items-center gap-2"><UserPlus size={18} className="text-accent" /> Grant Admin Access</h3>
          <p className="text-sm text-muted mb-4">
            This grants admin access to an existing FANZONE account provisioned on a WhatsApp-enabled phone number. The user must already have signed in at least once.
          </p>
          <div className="flex gap-4 items-end">
            <div className="field-group" style={{ flex: 2 }}>
              <label className="label">WhatsApp Number</label>
              <input className="input" type="tel" placeholder="+356 99 123 456" value={invitePhone} onChange={e => setInvitePhone(e.target.value)} autoFocus />
            </div>
            <div className="field-group" style={{ flex: 1 }}>
              <label className="label">Role</label>
              <select className="input select" value={inviteRole} onChange={e => setInviteRole(e.target.value as AdminRole)}>
                <option value="viewer">Viewer</option>
                <option value="moderator">Moderator</option>
                <option value="admin">Admin</option>
              </select>
            </div>
            <div className="flex gap-2">
              <button className="btn btn-secondary" onClick={() => setShowInvite(false)}>Cancel</button>
              <button className="btn btn-primary" onClick={handleInvite} disabled={!invitePhone.trim() || inviteMutation.isPending}>
                {inviteMutation.isPending ? 'Granting...' : 'Grant Access'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Role Hierarchy */}
      <div className="card mb-6 p-5">
        <h3 className="text-md font-semibold mb-3 flex items-center gap-2"><Shield size={18} className="text-accent" /> Role Hierarchy</h3>
        <div className="grid grid-4 gap-3">
          {[
            { role: 'Super Admin', desc: 'Full system access. Can manage other admins and feature flags.', color: 'var(--fz-malta-red)' },
            { role: 'Admin', desc: 'Full operational access. Cannot manage other admins or system settings.', color: 'var(--fz-accent)' },
            { role: 'Moderator', desc: 'Can moderate content, challenges, and handle reports. No financial ops.', color: 'var(--fz-amber)' },
            { role: 'Viewer', desc: 'Read-only access to dashboard and analytics. No write operations.', color: 'var(--fz-muted)' },
          ].map(r => (
            <div key={r.role} className="p-3" style={{ background: 'var(--fz-surface-2)', borderRadius: 'var(--fz-radius)', borderLeft: `3px solid ${r.color}` }}>
              <div className="font-semibold text-sm mb-1">{r.role}</div>
              <div className="text-xs text-muted">{r.desc}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Admin Table */}
      {isLoading ? <LoadingState lines={4} /> :
       error ? <ErrorState onRetry={() => refetch()} /> : (
        <div className="data-table-container">
          <table className="data-table">
            <thead><tr><th>Admin</th><th>WhatsApp Number</th><th>Role</th><th>Status</th><th>Last Login</th><th>Created</th><th className="cell-actions">Actions</th></tr></thead>
            <tbody>
              {admins.map(a => (
                <tr key={a.id}>
                  <td className="font-medium">{a.display_name}</td>
                  <td className="text-muted">{a.phone || '—'}</td>
                  <td>
                    <select className="input select" style={{ width: 130, padding: '2px 8px', fontSize: 'var(--fz-text-xs)' }} value={a.role} onChange={e => handleRoleChange(a, e.target.value as AdminRole)} disabled={a.role === 'super_admin' || changeRoleMutation.isPending}>
                      <option value="viewer">Viewer</option>
                      <option value="moderator">Moderator</option>
                      <option value="admin">Admin</option>
                      <option value="super_admin">Super Admin</option>
                    </select>
                  </td>
                  <td><StatusBadge status={a.is_active ? 'active' : 'archived'} /></td>
                  <td className="text-muted">{a.last_login_at ? formatDateTime(a.last_login_at) : '—'}</td>
                  <td className="text-muted">{formatDateTime(a.created_at)}</td>
                  <td className="cell-actions">
                    {a.role !== 'super_admin' && (
                      <button className="btn btn-ghost btn-icon btn-sm text-error" onClick={() => setConfirmRevoke(a)} title="Revoke access">
                        <Trash2 size={14} />
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <ConfirmDialog
        open={!!confirmRevoke}
        title="Revoke Admin Access"
        description={`Are you sure you want to revoke admin access for ${confirmRevoke?.display_name}? They will lose all admin privileges immediately.`}
        confirmLabel="Revoke Access"
        danger
        onConfirm={handleRevoke}
        onCancel={() => setConfirmRevoke(null)}
      />
    </div>
  );
}
