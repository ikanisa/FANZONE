import {
  manualPaymentStatusRequiresNote,
  nextOrderStatuses,
  normalizeOrderStatus,
  orderStatusRequiresReason,
} from "../packages/core/src/orderLifecycle.ts";

Deno.test("core order lifecycle maps legacy statuses for workflow display", () => {
  if (normalizeOrderStatus("placed") !== "submitted") {
    throw new Error("Expected placed to normalize to submitted");
  }
  if (normalizeOrderStatus("received") !== "accepted") {
    throw new Error("Expected received to normalize to accepted");
  }
});

Deno.test("core order lifecycle requires reasons for exceptional statuses", () => {
  for (const status of ["cancelled", "refunded", "disputed"] as const) {
    if (!orderStatusRequiresReason(status)) {
      throw new Error(`Expected ${status} to require a reason`);
    }
  }

  for (
    const status of ["submitted", "accepted", "preparing", "ready"] as const
  ) {
    if (orderStatusRequiresReason(status)) {
      throw new Error(`Expected ${status} to remain a normal transition`);
    }
  }
});

Deno.test("core order lifecycle exposes only valid next actions", () => {
  const submitted = nextOrderStatuses("submitted").join(",");
  if (submitted !== "accepted,cancelled,disputed") {
    throw new Error(`Unexpected submitted next statuses: ${submitted}`);
  }

  const disputed = nextOrderStatuses("disputed").join(",");
  if (disputed !== "refunded,cancelled,completed") {
    throw new Error(`Unexpected disputed next statuses: ${disputed}`);
  }
});

Deno.test("core manual payment lifecycle requires notes for audited confirmations", () => {
  for (
    const status of ["paid", "partially_paid", "refunded", "disputed"] as const
  ) {
    if (!manualPaymentStatusRequiresNote(status)) {
      throw new Error(`Expected ${status} to require an actor note`);
    }
  }

  for (const status of ["unpaid", "payment_submitted"] as const) {
    if (manualPaymentStatusRequiresNote(status)) {
      throw new Error(`Expected ${status} to remain note-optional`);
    }
  }
});
