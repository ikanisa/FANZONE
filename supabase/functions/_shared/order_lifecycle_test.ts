import {
  anyOrderStatuses,
  isValidOrderTransition,
  nextOrderStatuses,
  normalizeOrderStatusForTransition,
  orderStatusRequiresReason,
} from "./order_lifecycle.ts";

Deno.test("anyOrderStatuses includes target and legacy compatibility values", () => {
  for (
    const status of [
      "draft",
      "submitted",
      "accepted",
      "completed",
      "placed",
      "received",
    ] as const
  ) {
    if (!anyOrderStatuses.includes(status)) {
      throw new Error(`Expected ${status} to be accepted by Edge wrappers`);
    }
  }
});

Deno.test("normalizeOrderStatusForTransition maps legacy status aliases", () => {
  if (normalizeOrderStatusForTransition("placed") !== "submitted") {
    throw new Error("Expected placed to normalize to submitted");
  }
  if (normalizeOrderStatusForTransition("received") !== "accepted") {
    throw new Error("Expected received to normalize to accepted");
  }
});

Deno.test("nextOrderStatuses follows hospitality lifecycle", () => {
  const submitted = nextOrderStatuses("submitted").join(",");
  if (submitted !== "accepted,cancelled,disputed") {
    throw new Error(`Unexpected submitted transitions: ${submitted}`);
  }

  const ready = nextOrderStatuses("ready").join(",");
  if (ready !== "served,cancelled,disputed") {
    throw new Error(`Unexpected ready transitions: ${ready}`);
  }
});

Deno.test("terminal order statuses have no next actions", () => {
  for (const status of ["completed", "cancelled", "refunded"] as const) {
    if (nextOrderStatuses(status).length !== 0) {
      throw new Error(`Expected ${status} to be terminal`);
    }
  }
});

Deno.test("isValidOrderTransition rejects reverse transitions", () => {
  if (!isValidOrderTransition("accepted", "preparing")) {
    throw new Error("Expected accepted -> preparing to be valid");
  }
  if (isValidOrderTransition("accepted", "submitted")) {
    throw new Error("Expected accepted -> submitted to be invalid");
  }
});

Deno.test("exceptional order statuses require operator reasons", () => {
  for (const status of ["cancelled", "refunded", "disputed"] as const) {
    if (!orderStatusRequiresReason(status)) {
      throw new Error(`Expected ${status} to require a reason`);
    }
  }
  if (orderStatusRequiresReason("accepted")) {
    throw new Error("Expected accepted to remain a normal transition");
  }
});
