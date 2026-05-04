import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { AuditAction, EntityType } from "./types.ts";
import { Logger } from "./logger.ts";

/**
 * Audit log metadata interface
 */
export interface AuditMetadata {
  requestId?: string;
  previousValue?: unknown;
  newValue?: unknown;
  reason?: string;
  [key: string]: unknown;
}

/**
 * Write an entry to the admin_audit_logs table
 * Uses service role client to bypass RLS
 */
export async function writeAuditLog(
  supabaseAdmin: SupabaseClient,
  actorUserId: string,
  action: AuditAction | string,
  entityType: EntityType | string,
  entityId: string | null,
  metadata?: AuditMetadata,
  logger?: Logger,
): Promise<void> {
  try {
    const { data: adminRecord } = await supabaseAdmin
      .from("admin_users")
      .select("id")
      .eq("user_id", actorUserId)
      .eq("is_active", true)
      .maybeSingle();

    const { error } = await supabaseAdmin.from("admin_audit_logs").insert({
      admin_user_id: adminRecord?.id ?? null,
      action,
      module: String(entityType),
      target_type: String(entityType),
      target_id: entityId ?? "",
      metadata: metadata || {},
    });

    if (error) {
      logger?.error("Failed to write audit log", {
        error: error.message,
        action,
        entityType,
        entityId,
      });
    } else {
      logger?.debug("Audit log written", { action, entityType, entityId });
    }
  } catch (err) {
    // Audit log failures should not break the main operation
    logger?.error("Audit log exception", {
      error: String(err),
      action,
      entityType,
      entityId,
    });
  }
}

/**
 * Create an audit logger helper bound to a specific actor
 */
export function createAuditLogger(
  supabaseAdmin: SupabaseClient,
  actorUserId: string,
  requestId: string,
  logger?: Logger,
) {
  return {
    log: (
      action: AuditAction | string,
      entityType: EntityType | string,
      entityId: string | null,
      metadata?: Omit<AuditMetadata, "requestId">,
    ) => {
      return writeAuditLog(
        supabaseAdmin,
        actorUserId,
        action,
        entityType,
        entityId,
        { ...metadata, requestId },
        logger,
      );
    },
  };
}

export type AuditLogger = ReturnType<typeof createAuditLogger>;
