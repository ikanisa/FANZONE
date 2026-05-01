# Payments

FANZONE does not execute customer payments through a payment API.

Customer money movement remains off-system through:

- cash;
- MoMo/USSD instructions;
- Revolut link handoff;
- other venue-approved external/manual payment instructions.

## Product Rule

Do not add a provider charge/capture/refund API path unless the product, legal, compliance, and security model is redesigned.

The system may store:

- order total;
- payment method label;
- payment status;
- manual payment notes;
- payment event history;
- audit before/after status;
- FET earned/spent state.

The system must not store:

- card PAN;
- card CVV;
- bank credentials;
- MoMo PIN;
- Revolut credentials;
- payment provider secrets in client code.

## Payment Statuses

Venue staff can manage:

- `unpaid`
- `paid`
- `partially_paid`
- `refunded`
- `disputed`

Manual paid action must record:

- actor;
- timestamp;
- order id;
- amount;
- method;
- note if provided;
- before status;
- after status.

## Service Status Separation

Order service status is separate from payment status.

Service status:

- `placed`
- `received`
- `served`
- `cancelled`

Payment status:

- `unpaid`
- `paid`
- `partially_paid`
- `refunded`
- `disputed`

Do not infer service completion from payment state or payment completion from service state.

## FET Rewards

FET earning is controlled by venue/admin config and must be ledger-backed. FET spend on orders is optional per venue and may have a max spend cap.

## Operational Checks

- Confirm payment guidance is clear for every supported country/venue.
- Confirm manual payment status changes write `payment_events`.
- Confirm payment status changes write audit logs.
- Confirm cancelled orders cannot be marked paid.
- Confirm wallet/FET reward triggers only run on approved payment/service conditions.
