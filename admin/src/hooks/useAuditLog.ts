// FANZONE Admin — Audit Log Hook
// Used by all destructive admin actions to create an immutable audit trail.
import { isDemoMode, isSupabaseConfigured, supabase } from '../lib/supabase';
import { useAuth } from './useAuth';
import { useCallback } from 'react';

export function useAuditLog() {
  const { admin } = useAuth();

  const logAction = useCallback(
    async (opts: {
      action: string;
      module: string;
      targetType?: string;
      targetId?: string;
      beforeState?: Record<string, unknown>;
      afterState?: Record<string, unknown>;
      metadata?: Record<string, unknown>;
    }) => {
      if (!admin) {
        return;
      }

      if (isDemoMode) {
        console.log('[AuditLog Demo]', opts);
        return;
      }

      if (!isSupabaseConfigured) {
        return;
      }

      try {
        await supabase.from('admin_audit_logs').insert({
          admin_user_id: admin.id,
          action: opts.action,
          module: opts.module,
          target_type: opts.targetType || null,
          target_id: opts.targetId || null,
          before_state: opts.beforeState || null,
          after_state: opts.afterState || null,
          metadata: opts.metadata || {},
        });
      } catch (err) {
        console.error('[AuditLog] Failed to write audit log:', err);
      }
    },
    [admin],
  );

  return { logAction };
}
