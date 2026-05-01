# Venue Dashboard UAT Checklist

Use this checklist before releasing the sports-bar operational console.

## Access And Scope

- Sign in as a venue owner, manager, and staff user.
- Confirm each user only sees their assigned venue.
- Confirm owners/managers can update rewards and tables.
- Confirm staff can manage orders but cannot update reward or table configuration.
- Confirm direct URL access to another venue's data is blocked by RLS/RPC checks.

## Orders

- Place a guest order from a table QR flow and confirm it appears in Orders.
- Confirm order number, table, time, items, service status, payment status, total, FET earned, and FET spent are visible.
- Mark a placed order as received.
- Mark a received order as served.
- Cancel an active order.
- Set payment method to cash, MoMo, and Revolut.
- Mark an order paid manually with a note.
- Confirm `payment_events` records method, amount, before/after status, actor, and note.
- Confirm `audit_logs` records `venue_update_order_payment_status`.
- Confirm cancelled orders cannot be marked paid.

## Menu

- Create, reorder, hide, and show categories.
- Create an item with price, description, image URL, availability, and optional FET reward override.
- Edit item name, price, description, image URL, and FET override.
- Toggle item availability and confirm guest ordering respects the setting.
- Delete an item as owner/manager.
- Confirm staff users cannot delete if policy disallows it.

## Pools

- Confirm curated matches are visible.
- Create one official venue pool for a match.
- Confirm a second official venue pool for the same venue and match is rejected.
- Endorse and reject pending user-created venue-linked pools.
- Confirm pool stats show members, camp counts, total staked FET, and share links.
- Confirm settled pools show settlement state and result.

## FET Rewards

- Update default earn percentage.
- Toggle campaign active/inactive.
- Toggle FET spending on orders.
- Set max FET spend per order.
- Set redemption rate.
- Confirm the 100-spend preview matches the configured percentage.
- Confirm changes are written through `update_venue_fet_reward_config` and audit logged.
- Confirm staff users cannot save reward configuration.

## Tables / QR

- Generate table QR codes for a small range.
- Confirm each table has a server-generated token and secure deep link.
- Open a QR link and confirm the guest app receives venue and table context.
- Download a QR image.
- Share or copy a table link.
- Deactivate and reactivate a table.

## Insights

- Confirm today's order count updates after new orders.
- Confirm FET issued and redeemed reflect order ledger state.
- Confirm active pools count updates after creating/settling pools.
- Confirm most active match shows the highest participation venue-linked pool.
- Confirm top menu items update after orders.
- Confirm pending payment count drops after manual payment confirmation.

## Responsive Checks

- Test desktop width, tablet width, and mobile width.
- Confirm the mobile navigation is usable horizontally.
- Confirm all order actions and QR cards fit without text overlap.
- Confirm forms remain usable with long venue, category, item, and match names.
