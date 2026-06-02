import {
  anyOrderStatuses,
  normalizeOrderStatusForTransition,
} from "../_shared/order_lifecycle.ts";
import {
  orderUpdateStatusCanonicalRpc,
  orderUpdateStatusMetadataSource,
} from "../_shared/order_update_status_contract.ts";

Deno.test("order_update_status delegates lifecycle mutation to canonical transition RPC", () => {
  if (orderUpdateStatusCanonicalRpc !== "venue_transition_order_status") {
    throw new Error(
      "order_update_status must delegate to venue_transition_order_status",
    );
  }
  if (orderUpdateStatusMetadataSource !== "order_update_status") {
    throw new Error("order_update_status metadata source changed");
  }
});

Deno.test("order_update_status keeps legacy status compatibility at the wrapper boundary", () => {
  for (
    const status of ["placed", "received", "submitted", "accepted"] as const
  ) {
    if (!anyOrderStatuses.includes(status)) {
      throw new Error(`Expected wrapper schema to accept ${status}`);
    }
  }
  if (normalizeOrderStatusForTransition("placed") !== "submitted") {
    throw new Error("Expected placed to normalize to submitted");
  }
  if (normalizeOrderStatusForTransition("received") !== "accepted") {
    throw new Error("Expected received to normalize to accepted");
  }
});
