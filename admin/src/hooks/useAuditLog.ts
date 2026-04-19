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
        const { error } = await supabase.rpc('admin_log_action', {
          p_action: opts.action,
          p_module: opts.module,
          p_target_type: opts.targetType || null,
          p_target_id: opts.targetId || null,
          p_before_state: opts.beforeState || null,
          p_after_state: opts.afterState || null,
          p_metadata: opts.metadata || {},
        });
        if (error) {
          throw error;
        }
      } catch (err) {
        console.error('[AuditLog] Failed to write audit log:', err);
      }
    },
    [admin],
  );

  return { logAction };
}
