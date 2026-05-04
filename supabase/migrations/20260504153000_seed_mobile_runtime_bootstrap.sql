-- Seed the minimum runtime bootstrap data required by the release mobile app.
-- Without phone_presets/default_phone_country_code the first-run WhatsApp OTP
-- screen falls back to a generic "+" prefix and reviewer/UAT login cannot use
-- the intended E.164 market numbers.

INSERT INTO public.country_region_map (
  country_code,
  region,
  country_name,
  flag_emoji
)
VALUES
  ('MT', 'europe', 'Malta', '🇲🇹'),
  ('RW', 'africa', 'Rwanda', '🇷🇼'),
  ('GB', 'europe', 'United Kingdom', '🇬🇧'),
  ('US', 'north_america', 'United States', '🇺🇸')
ON CONFLICT (country_code) DO UPDATE
SET
  region = EXCLUDED.region,
  country_name = EXCLUDED.country_name,
  flag_emoji = EXCLUDED.flag_emoji,
  updated_at = now();

INSERT INTO public.phone_presets (
  country_code,
  dial_code,
  hint,
  min_digits
)
VALUES
  ('MT', '+356', '0000 0000', 8),
  ('RW', '+250', '000 000 000', 9),
  ('GB', '+44', '0000 000000', 10),
  ('US', '+1', '000 000 0000', 10)
ON CONFLICT (country_code) DO UPDATE
SET
  dial_code = EXCLUDED.dial_code,
  hint = EXCLUDED.hint,
  min_digits = EXCLUDED.min_digits,
  updated_at = now();

INSERT INTO public.currency_display_metadata (
  currency_code,
  symbol,
  decimals,
  space_separated
)
VALUES
  ('EUR', '€', 2, false),
  ('RWF', 'RWF', 0, true),
  ('GBP', '£', 2, false),
  ('USD', '$', 2, false)
ON CONFLICT (currency_code) DO UPDATE
SET
  symbol = EXCLUDED.symbol,
  decimals = EXCLUDED.decimals,
  space_separated = EXCLUDED.space_separated,
  updated_at = now();

INSERT INTO public.country_currency_map (
  country_code,
  currency_code,
  country_name
)
VALUES
  ('MT', 'EUR', 'Malta'),
  ('RW', 'RWF', 'Rwanda'),
  ('GB', 'GBP', 'United Kingdom'),
  ('US', 'USD', 'United States')
ON CONFLICT (country_code) DO UPDATE
SET
  currency_code = EXCLUDED.currency_code,
  country_name = EXCLUDED.country_name,
  updated_at = now();

INSERT INTO public.app_config_remote (key, value, description)
VALUES
  (
    'default_phone_country_code',
    '"MT"'::jsonb,
    'Default launch market country code for mobile WhatsApp OTP input.'
  ),
  (
    'priority_phone_country_codes',
    '["MT", "RW", "GB", "US"]'::jsonb,
    'Preferred ordering for country phone selectors and bootstrap defaults.'
  )
ON CONFLICT (key) DO UPDATE
SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = timezone('utc'::text, now());
