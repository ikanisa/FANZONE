Historical hotfix SQL that was applied outside the canonical timestamped migration chain.

These files are archived so `supabase db push` does not try to parse them as runnable
migrations. They remain in the repo as implementation history only.

Current canonical replacements:

- `002b_live_backend_hotfixes.sql`
  Superseded by:
  `20260418132000_fet_supply_cap_enforcement.sql`
  `20260418031500_fullstack_hardening.sql`
  `20260418121500_p0_hardening_fixups.sql`

- `006b_transfer_fet_phone_support.sql`
  Superseded by:
  `016_onboarding_currency_fanid.sql`
  `20260418121500_p0_hardening_fixups.sql`
