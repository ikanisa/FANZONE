export const targetOrderStatuses = [
  "draft",
  "submitted",
  "accepted",
  "preparing",
  "ready",
  "served",
  "completed",
  "cancelled",
  "refunded",
  "disputed",
] as const;

export type TargetOrderStatus = typeof targetOrderStatuses[number];
export type LegacyOrderStatus = "placed" | "received";
export type AnyOrderStatus = TargetOrderStatus | LegacyOrderStatus;

export function normalizeOrderStatusForTransition(
  status: AnyOrderStatus,
): TargetOrderStatus {
  if (status === "placed") return "submitted";
  if (status === "received") return "accepted";
  return status;
}

export function nextOrderStatuses(status: AnyOrderStatus): TargetOrderStatus[] {
  switch (status) {
    case "draft":
      return ["submitted"];
    case "placed":
    case "received":
    case "submitted":
      return ["accepted", "cancelled", "disputed"];
    case "accepted":
      return ["preparing", "ready", "cancelled", "disputed"];
    case "preparing":
      return ["ready", "served", "cancelled", "disputed"];
    case "ready":
      return ["served", "cancelled", "disputed"];
    case "served":
      return ["completed", "disputed"];
    case "disputed":
      return ["refunded", "cancelled", "completed"];
    case "completed":
    case "cancelled":
    case "refunded":
      return [];
  }
}

export function isValidOrderTransition(
  current: AnyOrderStatus,
  next: TargetOrderStatus,
): boolean {
  return nextOrderStatuses(current).includes(next);
}
