# App Review Notes

## Login

FANZONE uses WhatsApp OTP login only. It does not require email, username, first name, or last name.

Use a stable reviewer phone and OTP configured in the deployed `whatsapp-otp` Edge Function:

- UAT fixture phone: `+35699711145`
- UAT fixture OTP: `123456`

Reviewer flow:
1. Open the app.
2. Enter the reviewer phone.
3. Tap `SEND OTP`.
4. Enter the reviewer OTP.
5. Continue through fan profile setup if shown.

## Payment Explanation

FANZONE does not process payments. Venue orders show external instructions such as MoMo USSD, Revolut link, cash, card, or other venue-supported methods. Venue staff manually confirms payment in the venue dashboard.

## FET Explanation

FET is a closed-loop engagement and reward point. It is not cash, not crypto trading, not an investment, and cannot be cashed out.

## Prediction Pool Explanation

Prediction pools use FET points only. Pools are tied to a specific venue and are settled by app rules. Winners receive FET only when they satisfy the qualifying order rule for that linked venue.

## Review Surface

Please test:
- WhatsApp OTP login.
- Venue browsing.
- Menu and order creation.
- External payment instruction display.
- Pool and game discovery.
- Wallet and FET activity.
- Profile/settings and account deletion request path.

