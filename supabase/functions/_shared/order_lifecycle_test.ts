import {
  isValidOrderTransition,
  nextOrderStatuses,
  normalizeOrderStatusForTransition,
} from "./order_lifecycle.ts";

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
