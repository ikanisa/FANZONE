#!/usr/bin/env node
import { readFileSync } from "node:fs";

const checks = [
  {
    file: "apps/venue-portal/src/features/orders/ManualMarkPaidModal.tsx",
    required: [
      "amountReceived",
      "reference",
      "note",
      "staffConfirmed",
      "trimmedNote.length > 0",
      "External mobile-money confirmation",
      "Other externally verified payment",
      "onConfirm({",
    ],
    forbidden: [
      {
        pattern: /value:\s*["']card["']/,
        message: "manual payment modal must not offer card as an MVP method",
      },
    ],
  },
  {
    file: "apps/venue-portal/src/services/venueOperations.ts",
    required: [
      '.from("payment_events")',
      '.from("order_state_events")',
      '"venue_update_order_payment_status"',
      "p_actor_note",
      "p_amount_received",
      "p_external_reference",
      '"venue_manual_payment_reconciliation"',
      "p_business_date",
      '"order_update_status"',
      "metadata: { surface: \"venue-portal\" }",
      '"venue_acknowledge_bell_request"',
      "p_bell_id",
    ],
    forbidden: [
      {
        pattern: /\.from\(["']orders["']\)\s*\.update/s,
        message:
          "venue portal service must not directly update orders for sensitive mutations",
      },
      {
        pattern: /\.from\(["']payment_events["']\)\s*\.insert/s,
        message:
          "venue portal service must not directly insert payment_events",
      },
      {
        pattern: /\.from\(["']order_state_events["']\)\s*\.insert/s,
        message:
          "venue portal service must not directly insert order_state_events",
      },
      {
        pattern: /\.from\(["']bell_requests["']\)\s*\.update/s,
        message:
          "venue portal service must acknowledge bell requests through the audited RPC",
      },
    ],
  },
  {
    file: "apps/venue-portal/src/features/orders/LiveOrderQueuePage.tsx",
    required: [
      "activeOrderStatuses",
      "nextOrderStatuses",
      "manualPaymentStatusRequiresNote",
      "orderStatusRequiresReason",
      "orderTransitionActionLabels",
      "ManualMarkPaidModal",
      "useBellRequests",
      "refreshBells()",
      "amountReceived: details.amountReceived",
      "externalReference: details.reference",
      "details.note",
      "bell.message",
      "Acknowledge",
      "refreshBells()",
      "Reason is required for this order action.",
      "Payment note is required for this payment status.",
    ],
  },
  {
    file: "apps/venue-portal/src/features/orders/OrderDetailPage.tsx",
    required: [
      "nextOrderStatuses",
      "orderStatusRequiresReason",
      "orderTransitionActionLabels",
      "ManualMarkPaidModal",
      "detail.paymentEvents",
      "detail.stateEvents",
      "Manual payment audit trail",
      "Service timeline",
      "amountReceived: details.amountReceived",
      "externalReference: details.reference",
      "Reason is required for this order action.",
    ],
  },
  {
    file: "apps/venue-portal/src/hooks/useOrders.ts",
    required: [
      "filter: `venue_id=eq.${venueId}`",
      "fetchVenueOrders(venueId)",
      "setOrderServiceStatus(orderId, status, reason)",
      "setOrderPaymentStatus(orderId, paymentStatus, paymentMethod, note, details)",
    ],
  },
  {
    file: "apps/venue-portal/src/hooks/usePaymentReconciliation.ts",
    required: [
      "fetchVenuePaymentReconciliation(venueId, businessDate)",
      "filter: `venue_id=eq.${venueId}`",
      "setBusinessDate",
      "refresh",
    ],
    forbidden: [
      {
        pattern: /table:\s*["']payment_events["']/,
        message:
          "payment reconciliation realtime must not subscribe to whole payment_events",
      },
    ],
  },
  {
    file: "apps/venue-portal/src/features/dashboard/DashboardPage.tsx",
    required: [
      "usePaymentReconciliation",
      "Manual payment reconciliation",
      "providerApiUsed",
      "businessDate",
      "Daily close",
    ],
  },
  {
    file: "apps/venue-portal/src/hooks/useBellRequests.ts",
    required: [
      "filter: `venue_id=eq.${venueId}`",
      "fetchActiveBellRequests(venueId)",
      "acknowledgeBellRequest(bellId)",
      "await refresh()",
    ],
  },
];

const failures = [];

for (const check of checks) {
  const source = readFileSync(check.file, "utf8");
  for (const required of check.required ?? []) {
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

console.log("FANZONE venue portal hospitality scan");

if (failures.length > 0) {
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log("Venue portal hospitality scan passed.");
