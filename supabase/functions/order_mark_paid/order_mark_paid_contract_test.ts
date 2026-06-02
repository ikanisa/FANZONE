import {
  orderMarkPaidCanonicalRpc,
  orderMarkPaidDefaultPaymentMethod,
  orderMarkPaidMaxExternalReferenceLength,
  orderMarkPaidMaxNoteLength,
  orderMarkPaidPaymentMethods,
  orderMarkPaidTargetPaymentStatus,
} from "../_shared/order_mark_paid_contract.ts";

Deno.test("order_mark_paid delegates manual confirmation to the canonical payment RPC", () => {
  if (orderMarkPaidCanonicalRpc !== "venue_update_order_payment_status") {
    throw new Error(
      "order_mark_paid must delegate to the canonical payment RPC",
    );
  }
  if (orderMarkPaidTargetPaymentStatus !== "paid") {
    throw new Error("order_mark_paid must remain a paid-confirmation wrapper");
  }
});

Deno.test("order_mark_paid keeps manual/off-platform payment request shape", () => {
  const methods = orderMarkPaidPaymentMethods.join(",");
  if (methods !== "cash,momo,revolut,other") {
    throw new Error(`Unexpected manual payment methods: ${methods}`);
  }
  if (orderMarkPaidPaymentMethods.includes("card" as never)) {
    throw new Error("order_mark_paid must not accept card as an MVP method");
  }
  if (orderMarkPaidDefaultPaymentMethod !== "cash") {
    throw new Error("Expected cash to remain the compatibility default");
  }
  if (orderMarkPaidMaxExternalReferenceLength !== 120) {
    throw new Error("Unexpected external reference length limit");
  }
  if (orderMarkPaidMaxNoteLength !== 240) {
    throw new Error("Unexpected actor note length limit");
  }
});
