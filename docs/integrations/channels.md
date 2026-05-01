# Channel Integrations

## WhatsApp

Current production channel: WhatsApp OTP through `supabase/functions/whatsapp-otp`.

Required secrets:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY` or `EDGE_SERVICE_ROLE_KEY`
- `FANZONE_JWT_SECRET`
- WhatsApp Business credentials when live delivery is enabled
- optional reviewer values: `WHATSAPP_AUTH_TEST_PHONE`, `WHATSAPP_AUTH_TEST_OTP`, `WHATSAPP_AUTH_TEST_EXPIRY`

Smoke test:

```bash
SUPABASE_URL=... SUPABASE_ANON_KEY=... ./tool/supabase_whatsapp_auth_smoke.sh
```

Rules:

- never log raw OTPs;
- keep reviewer OTP values time-bound;
- rate limit send and verify actions;
- ensure session issuance creates/links user foundation records.

## Push Notifications

Current production channel: Firebase push through `push-notify` and `dispatch-match-alerts`.

Required secrets:

- `SUPABASE_URL`
- `EDGE_SERVICE_ROLE_KEY` or `SUPABASE_SERVICE_ROLE_KEY`
- `PUSH_NOTIFY_SECRET`
- `GOOGLE_SERVICE_ACCOUNT_JSON`
- `CRON_SECRET` for scheduled dispatch

Monitor:

- failed sends;
- invalid tokens;
- cron job failures;
- notification preference filtering.

## Email

Built-in Supabase email auth is intentionally disabled. If operational email is added, document provider, templates, unsubscribe flow, and secrets before launch.

## Telegram, Google Chat, Teams, Voice

No production adapter was found in the repo. Before adding any of these:

- create a dedicated setup document;
- define inbound signature validation;
- define outbound rate limits;
- add tenant scoping;
- add audit logging for sensitive actions;
- add incident and disable steps.

## Channel Safety Checklist

- Validate inbound signatures or shared secrets.
- Treat channel payloads as untrusted.
- Never allow a chat/channel message to grant permissions.
- Avoid leaking tenant data across channels.
- Keep support escalation human-reviewed for financial, wallet, settlement, or admin actions.
