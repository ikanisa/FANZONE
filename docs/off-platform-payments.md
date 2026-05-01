# Off-Platform Payments

FANZONE does not process card, MoMo, Revolut, or bank payments through a payment provider API.

The production contract is:

- Customers place orders in FANZONE.
- FANZONE may generate external handoff instructions for cash, MoMo USSD, or a venue Revolut link.
- The order payment status remains `pending` after every handoff.
- Venue staff or an admin manually confirms payment after seeing cash, a USSD confirmation SMS, or a Revolut confirmation screen.
- Manual confirmation is recorded through `order_mark_paid` and audited in `audit_logs` and `payment_events`.
- Provider callbacks, webhooks, charge IDs, automatic reconciliation, and payment API verification are intentionally out of scope.

Operational implications:

- `payment-hub` must only return instructions, URLs, and audit records.
- `payment-hub` must never mark an order paid.
- Client checkout must show MoMo only when the venue has `momo_code` or a phone/WhatsApp fallback, and must show Revolut only when the venue has `revolut_link`.
- Clients must not deduct wallet balances or apply token discounts unless a server-side wallet RPC performs the debit atomically.
- Venue staff should treat `payment_status = pending` as unpaid until they manually confirm proof.
