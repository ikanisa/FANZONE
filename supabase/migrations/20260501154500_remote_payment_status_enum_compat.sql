-- Add sports-bar manual payment states to older remote projects. Kept separate
-- because PostgreSQL enum values must commit before dependent routines use them.

ALTER TYPE public.venue_payment_status ADD VALUE IF NOT EXISTS 'unpaid' BEFORE 'pending';
ALTER TYPE public.venue_payment_status ADD VALUE IF NOT EXISTS 'partially_paid' AFTER 'paid';
ALTER TYPE public.venue_payment_status ADD VALUE IF NOT EXISTS 'disputed' AFTER 'refunded';
