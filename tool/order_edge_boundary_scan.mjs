#!/usr/bin/env node
import { readFileSync } from "node:fs";

const checks = [
  {
    file: "supabase/functions/order_create/index.ts",
    required: [
      "orderCreateMaxTableNumberLength",
      ".upsert(",
      'onConflict: "venue_id,table_number"',
      '.select("id, table_number")',
      '.from("menu_items")',
      '.eq("venue_id", input.venue_id)',
      "is_available",
      "item_name_snapshot: menuItem.name",
      "item_description_snapshot: menuItem.description",
      "unit_price: menuItem.price",
      "line_total: Math.round(itemTotal * 100) / 100",
      "status: orderCreateInitialStatus",
      "payment_status: orderCreateInitialPaymentStatus",
      '.from(\n      "order_state_events",\n    ).insert',
      "previous_status: null",
      "next_status: orderCreateInitialStatus",
      "source: orderCreateStateEventSource",
      'table_number: tableNumber',
      'await supabaseAdmin.from("orders").delete().eq("id", order.id)',
      "orderCreatePaymentMethods",
    ],
    forbidden: [
      {
        pattern: /payment_method:\s*z\s*\.\s*enum\s*\([^)]*["']card["']/s,
        message: "order_create must not accept card as an MVP payment method",
      },
      {
        pattern: /status:\s*["']placed["']/,
        message: "order_create must create submitted orders, not placed",
      },
      {
        pattern: /status:\s*["']received["']/,
        message: "order_create must create submitted orders, not received",
      },
      {
        pattern: /total_amount:\s*input\./,
        message: "order_create must not trust client-provided order totals",
      },
      {
        pattern: /unit_price:\s*inputItem\./,
        message: "order_create must snapshot unit price from menu_items",
      },
    ],
  },
  {
    file: "supabase/functions/order_update_status/index.ts",
    required: [
      "orderUpdateStatusCanonicalRpc",
      "orderUpdateStatusMetadataSource",
      "normalizeOrderStatusForTransition",
      "anyOrderStatuses",
    ],
    forbidden: [
      {
        pattern: /\.from\(["']orders["']\)\s*\.update/s,
        message: "order_update_status must not update orders directly",
      },
      {
        pattern: /\.from\(["']order_state_events["']\)\s*\.insert/s,
        message:
          "order_update_status must not insert order_state_events directly",
      },
    ],
  },
  {
    file: "supabase/functions/order_mark_paid/index.ts",
    required: [
      "orderMarkPaidCanonicalRpc",
      "orderMarkPaidTargetPaymentStatus",
      "orderMarkPaidPaymentMethods",
      "p_amount_received",
      "p_external_reference",
      "p_actor_note",
    ],
    forbidden: [
      {
        pattern: /\.from\(["']orders["']\)\s*\.update/s,
        message: "order_mark_paid must not update orders directly",
      },
      {
        pattern: /\.from\(["']payment_events["']\)\s*\.insert/s,
        message: "order_mark_paid must not insert payment_events directly",
      },
      {
        pattern: /payment_method:\s*z\s*\.\s*enum\s*\([^)]*["']card["']/s,
        message: "order_mark_paid must not accept card as manual MVP method",
      },
    ],
  },
  {
    file: "supabase/functions/_shared/order_update_status_contract.ts",
    required: [
      '"venue_transition_order_status"',
      '"order_update_status"',
    ],
  },
  {
    file: "supabase/functions/_shared/order_mark_paid_contract.ts",
    required: [
      '"venue_update_order_payment_status"',
      '"paid"',
      '"cash"',
      '"momo"',
      '"revolut"',
      '"other"',
      "orderMarkPaidMaxExternalReferenceLength = 120",
      "orderMarkPaidMaxNoteLength = 240",
    ],
    forbidden: [
      {
        pattern: /orderMarkPaidPaymentMethods[\s\S]*["']card["']/,
        message: "order_mark_paid contract must not accept card as manual MVP method",
      },
    ],
  },
];

const failures = [];

for (const check of checks) {
  const source = readFileSync(check.file, "utf8");
  for (const required of check.required) {
    if (!source.includes(required)) {
      failures.push(`${check.file}: missing ${required}`);
    }
  }
  for (const forbidden of check.forbidden ?? []) {
    if (forbidden.pattern.test(source)) {
      failures.push(`${check.file}: ${forbidden.message}`);
    }
  }
}

console.log("FANZONE order Edge boundary scan");

if (failures.length > 0) {
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log("Order Edge boundary scan passed.");
