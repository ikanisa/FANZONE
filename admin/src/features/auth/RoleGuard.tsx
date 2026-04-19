// FANZONE Admin — Role Guard
import { useAuth } from '../../hooks/useAuth';
import { hasMinRole } from '../../lib/formatters';
import { ShieldX } from 'lucide-react';
import type { AdminRole } from '../../config/constants';

interface RoleGuardProps {
  minRole: AdminRole;
  children: React.ReactNode;
}

export function RoleGuard({ minRole, children }: RoleGuardProps) {
  const { admin } = useAuth();

  if (!admin || !hasMinRole(admin.role, minRole)) {
    return (
      <div className="state-view">
        <ShieldX size={48} />
        <h3>Access Denied</h3>
        <p>You do not have permission to access this section. Required role: {minRole.replace('_', ' ')}.</p>
      </div>
    );
  }

  return <>{children}</>;
}
