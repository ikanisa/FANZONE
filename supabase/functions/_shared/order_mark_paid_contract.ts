export const orderMarkPaidPaymentMethods = [
  "cash",
  "momo",
  "revolut",
  "other",
] as const;

export const orderMarkPaidDefaultPaymentMethod = "cash" as const;
export const orderMarkPaidTargetPaymentStatus = "paid" as const;
export const orderMarkPaidCanonicalRpc =
  "venue_update_order_payment_status" as const;
export const orderMarkPaidMaxExternalReferenceLength = 120;
export const orderMarkPaidMaxNoteLength = 240;
