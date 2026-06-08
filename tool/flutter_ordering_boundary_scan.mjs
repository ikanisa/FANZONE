#!/usr/bin/env node
import { readFileSync } from "node:fs";

const checks = [
  {
    file: "lib/features/ordering/data/order_gateway.dart",
    required: [
      "'order_create'",
      "'table_number': request.tableNumber",
      "'payment_method': request.paymentMethod.name",
      "'menu_item_id': item.menuItemId",
      "'quantity': item.quantity",
      "'add_ons': item.addOns",
      "'payment-hub'",
      "method == PaymentMethod.cash || method == PaymentMethod.card",
      "'user_submit_order_payment'",
      "'p_payment_method': method.name",
      "PaymentMethod.card ||\n      PaymentMethod.other => PaymentMethod.cash",
    ],
    forbidden: [
      {
        pattern: /'total_amount'\s*:\s*request\./,
        message: "order_create payload must not include client total_amount",
      },
      {
        pattern: /'subtotal_amount'\s*:\s*request\./,
        message:
          "order_create payload must not include client subtotal_amount",
      },
      {
        pattern: /'unit_price'\s*:\s*item\./,
        message: "order_create payload must not include client unit_price",
      },
      {
        pattern: /'line_total'\s*:\s*item\./,
        message: "order_create payload must not include client line_total",
      },
      {
        pattern: /'item_name_snapshot'\s*:\s*item\./,
        message:
          "order_create payload must not include client item_name_snapshot",
      },
    ],
  },
  {
    file: "lib/features/ordering/screens/checkout_screen.dart",
    required: [
      "normalizeManualTableNumber(_tableNumberController.text)",
      "tableNumber: tableNumber",
      "PaymentMethod.card:\n    case PaymentMethod.other:\n      return false",
      "uri.scheme != 'https'",
      "PaymentMethod.revolut",
    ],
    forbidden: [
      {
        pattern: /PaymentMethod\.card,[\s\S]{0,180}_PaymentMethodTile/,
        message: "checkout must not render card as a customer payment option",
      },
      {
        pattern: /qr[_-]?code|scan qr|qr ordering/i,
        message: "checkout must not require QR ordering",
      },
    ],
  },
  {
    file: "lib/features/ordering/providers/order_provider.dart",
    required: [
      "PaymentMethod.momo || PaymentMethod.revolut || PaymentMethod.other => true",
      "PaymentMethod.cash || PaymentMethod.card => false",
      "PaymentStatus.pending",
      "PaymentStatus.unpaid",
    ],
  },
  {
    file: "lib/features/ordering/screens/order_tracking_screen.dart",
    required: [
      "bellGatewayProvider",
      ".ringBell(",
      "Order support ${type.auditLabel}: Order #",
      "Report issue",
      "Request cancellation",
      "Request refund review",
      "It does not change order or payment status automatically.",
      "canSubmitPaymentForOrder(widget.order)",
      "Awaiting venue.",
      "PaymentStatus.paymentSubmitted",
      "PaymentStatus.paid",
    ],
  },
  {
    file: "lib/features/ordering/widgets/payment_handoff_sheet.dart",
    required: [
      "Staff confirms payment.",
      "Open USSD",
      "Open Revolut",
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

const orderGatewaySource = readFileSync(
  "lib/features/ordering/data/order_gateway.dart",
  "utf8",
);
const submitRpcIndex = orderGatewaySource.indexOf("'user_submit_order_payment'");
const submitStartIndex = submitRpcIndex === -1
  ? -1
  : orderGatewaySource.lastIndexOf("Future<void> submitPayment({", submitRpcIndex);
const submitEndIndex = submitStartIndex === -1
  ? -1
  : orderGatewaySource.indexOf("Future<void> spendFetOnOrder({", submitStartIndex);
const submitPaymentSource = submitStartIndex === -1
  ? ""
  : orderGatewaySource.slice(submitStartIndex, submitEndIndex === -1 ? undefined : submitEndIndex);
const customerSubmitPaymentUsesRpc = submitPaymentSource.includes(
  "'user_submit_order_payment'",
);
const customerSubmitPaymentUsesStaffWrapper = submitPaymentSource.includes(
  "'order_mark_paid'",
);
if (!customerSubmitPaymentUsesRpc) {
  failures.push(
    "lib/features/ordering/data/order_gateway.dart: customer payment submission must use user_submit_order_payment",
  );
}
if (customerSubmitPaymentUsesStaffWrapper) {
  failures.push(
    "lib/features/ordering/data/order_gateway.dart: customer payment submission must not call staff manual paid wrapper",
  );
}

console.log("FANZONE Flutter ordering boundary scan");

if (failures.length > 0) {
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log("Flutter ordering boundary scan passed.");
