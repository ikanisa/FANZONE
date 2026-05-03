# App Store Privacy Label Notes

Verify these declarations against the final production build and third-party SDK inventory before submission.

## Data Linked To The User

- Contact Info: phone number for WhatsApp OTP.
- User ID: Supabase user ID and 6-digit FANZONE ID.
- Purchases or order activity: venue order records, order status, manual payment status. No direct payment credentials are collected.
- User Content: order notes, pool entries, team membership, game participation where entered by the user.
- Usage Data: app interactions needed to operate venues, orders, pools, games, teams, wallet, eligibility, and support.
- Diagnostics: runtime error logs if telemetry is enabled.

## Data Not Collected In Current Release

- Precise location.
- Contacts.
- Photos or videos.
- Audio.
- Health or fitness.
- Browsing history outside FANZONE.
- Payment card, bank account, MoMo credentials, or Revolut credentials.

## Third-Party SDKs To Review

- Supabase Flutter.
- Firebase Core and Firebase Messaging.
- URL launcher, app links, share, image/cache packages.

The iOS project includes CocoaPods privacy manifests from several dependencies. Confirm App Store Connect privacy answers match both direct app behavior and SDK behavior.

