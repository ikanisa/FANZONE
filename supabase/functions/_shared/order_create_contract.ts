export const orderCreatePaymentMethods = [
  "cash",
  "momo",
  "revolut",
  "other",
] as const;

export const orderCreateInitialStatus = "submitted";
export const orderCreateInitialPaymentStatus = "pending";
export const orderCreateStateEventSource = "order_create";
export const orderCreateStateEventReason = "Order submitted by customer";
export const orderCreateMaxTableNumberLength = 24;
