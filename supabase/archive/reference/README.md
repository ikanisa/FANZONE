Reference-only SQL artifacts that are preserved for historical context and schema notes.

These files are intentionally kept out of `supabase/migrations` so the CLI only sees
the canonical runnable migration chain.

- `001_engagement_tables_reference.sql` is the original documentation-only schema note.
  The active migration chain now uses `supabase/migrations/001_engagement_tables.sql`
  as the authoritative bootstrap for fresh environments.
