import {
  useSupabaseList,
  useRpcMutation,
} from "../../hooks/useSupabaseQuery";
import type {
  AuditLog,
  PlatformFeatureRecord,
  PlatformContentBlockRecord,
} from "../../types";
import {
  buildPlatformContentBlockPayload,
  buildPlatformFeaturePayload,
  type PlatformFeatureChannelInput,
  type UpsertPlatformContentBlockArgs,
  type UpsertPlatformFeatureArgs,
} from "./payloads";

export function usePlatformFeatures() {
  return useSupabaseList<PlatformFeatureRecord>(
    ["platform-features"],
    "admin_platform_features",
    {
      order: { column: "display_name", ascending: true },
    },
  );
}

export function usePlatformContentBlocks() {
  return useSupabaseList<PlatformContentBlockRecord>(
    ["platform-content-blocks"],
    "admin_platform_content_blocks",
    {
      order: { column: "sort_order", ascending: true },
    },
  );
}

export function usePlatformFeatureAuditLogs(limit = 12) {
  return useSupabaseList<AuditLog>(
    ["platform-feature-audit-logs", limit],
    "platform_feature_audit_logs",
    {
      order: { column: "created_at", ascending: false },
      limit,
    },
  );
}

export function useUpsertPlatformFeature() {
  const mutation = useRpcMutation<{ p_payload: Record<string, unknown> }>({
    fnName: "admin_upsert_platform_feature",
    invalidateKeys: [
      ["platform-features"],
      ["platform-feature-audit-logs"],
    ],
    successMessage: "Platform feature saved.",
  });

  return {
    ...mutation,
    mutateAsync: async (args: UpsertPlatformFeatureArgs) => {
      const featureKey = buildPlatformFeaturePayload(args).feature_key;
      await mutation.mutateAsync({
        p_payload: buildPlatformFeaturePayload(args),
      });
      return featureKey;
    },
  };
}

export function useUpsertPlatformContentBlock() {
  const mutation = useRpcMutation<{ p_payload: Record<string, unknown> }>({
    fnName: "admin_upsert_platform_content_block",
    invalidateKeys: [
      ["platform-content-blocks"],
      ["platform-feature-audit-logs"],
    ],
    successMessage: "Content block saved.",
  });

  return {
    ...mutation,
    mutateAsync: async (args: UpsertPlatformContentBlockArgs) => {
      const blockKey = buildPlatformContentBlockPayload(args).block_key;
      await mutation.mutateAsync({
        p_payload: buildPlatformContentBlockPayload(args),
      });
      return blockKey;
    },
  };
}

export type {
  PlatformFeatureChannelInput,
  UpsertPlatformContentBlockArgs,
  UpsertPlatformFeatureArgs,
};
