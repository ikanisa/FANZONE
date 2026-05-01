-- Remote compatibility shim for projects created before the pool live status.
-- Kept separate from the function migration because PostgreSQL enum values must
-- commit before they can be referenced by functions or policies.

ALTER TYPE public.match_pool_status ADD VALUE IF NOT EXISTS 'live' AFTER 'locked';
