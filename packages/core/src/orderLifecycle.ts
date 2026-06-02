import type { OrderStatus, PaymentStatus } from "./types";

export const targetOrderStatuses: readonly OrderStatus[] = [
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

export const orderServiceStatuses: readonly OrderStatus[] = [
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

export const activeOrderStatuses: readonly OrderStatus[] = [
  "placed",
  "received",
  "submitted",
  "accepted",
  "preparing",
  "ready",
  "served",
] as const;

export const orderTransitionActionLabels: Partial<Record<OrderStatus, string>> =
  {
    submitted: "Submit",
    accepted: "Accept order",
    preparing: "Preparing",
    ready: "Ready",
    served: "Serve order",
    completed: "Complete",
    cancelled: "Cancel",
    disputed: "Dispute",
    refunded: "Refund",
  };

export const orderStatusesRequiringReason: readonly OrderStatus[] = [
  "cancelled",
  "refunded",
  "disputed",
] as const;

export const manualPaymentStatusesRequiringNote: readonly PaymentStatus[] = [
  "paid",
  "partially_paid",
  "refunded",
  "disputed",
] as const;

export function normalizeOrderStatus(status: OrderStatus): OrderStatus {
  if (status === "placed") return "submitted";
  if (status === "received") return "accepted";
  return status;
}

export function readableOrderStatus(status: OrderStatus): string {
  const normalized = normalizeOrderStatus(status);
  return normalized.replace(/_/g, " ");
}

export function nextOrderStatuses(status: OrderStatus): OrderStatus[] {
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

export function isTerminalOrderStatus(status: OrderStatus): boolean {
  return status === "completed" || status === "cancelled" ||
    status === "refunded";
}

export function isActiveOrderStatus(status: OrderStatus): boolean {
  return activeOrderStatuses.includes(status);
}

export function orderStatusRequiresReason(status: OrderStatus): boolean {
  return orderStatusesRequiringReason.includes(normalizeOrderStatus(status));
}

export function manualPaymentStatusRequiresNote(
  status: PaymentStatus,
): boolean {
  return manualPaymentStatusesRequiringNote.includes(status);
}
