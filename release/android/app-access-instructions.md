# Google Play App Access Instructions

## Reviewer Login

FANZONE uses WhatsApp OTP login only. It does not use email/password, username, first name, or last name.

Provide a stable reviewer route before submitting:

- Reviewer phone: configure in production Edge Function secrets as `WHATSAPP_AUTH_TEST_PHONE`, then enter the actual reviewer phone only in Play Console app-access instructions or the private release evidence bundle. Do not commit it.
- Reviewer OTP: configure in production Edge Function secrets as `WHATSAPP_AUTH_TEST_OTP`, then enter the actual reviewer OTP only in Play Console app-access instructions or the private release evidence bundle. Do not commit it.

## Reviewer Steps

1. Open the app.
2. Select WhatsApp login.
3. Enter the reviewer phone number.
4. Tap `SEND OTP`.
5. Enter the reviewer OTP.
6. Complete fan profile if prompted.
7. Browse venues, menus, pools, games, rewards-ledger activity, and profile.

## Product Review Notes

- Users are assigned a unique 6-digit FANZONE ID.
- Orders are linked to venues and payments are external.
- Venue staff manually confirms paid orders in the venue dashboard.
- FET rewards are closed-loop app/venue reward points with no cash-out.
- Winning pool/game users only receive non-cash FET reward-point allocation when they have a qualifying paid order from the linked venue within 2 hours before the game or pool start time.
