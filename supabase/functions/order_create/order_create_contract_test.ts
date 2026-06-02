import {
  orderCreateInitialPaymentStatus,
  orderCreateInitialStatus,
  orderCreateMaxTableNumberLength,
  orderCreatePaymentMethods,
  orderCreateStateEventReason,
  orderCreateStateEventSource,
} from "../_shared/order_create_contract.ts";

Deno.test("order_create contract keeps table-number ordering as the customer flow", () => {
  if (orderCreateMaxTableNumberLength !== 24) {
    throw new Error("Expected table_number length to remain capped at 24");
  }
});

Deno.test("order_create contract starts submitted orders with lifecycle evidence", () => {
  if (orderCreateInitialStatus !== "submitted") {
    throw new Error("Expected new orders to start as submitted");
  }
  if (orderCreateStateEventSource !== "order_create") {
    throw new Error("Expected initial state event source to be order_create");
  }
  if (orderCreateStateEventReason !== "Order submitted by customer") {
    throw new Error("Expected customer-submitted state event reason");
  }
});

Deno.test("order_create contract preserves off-platform payment boundary", () => {
  const methods = orderCreatePaymentMethods.join(",");
  if (methods !== "cash,momo,revolut,other") {
    throw new Error(`Unexpected order payment methods: ${methods}`);
  }
  if (orderCreatePaymentMethods.includes("card" as never)) {
    throw new Error("order_create must not accept card as an MVP method");
  }
  if (orderCreateInitialPaymentStatus !== "pending") {
    throw new Error("Expected manual/off-platform payments to remain pending");
  }
});
