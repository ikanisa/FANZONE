-- ============================================================================
-- Support for FET token payments in orders
-- Migration: 20260501040000_order_fet_payment_support.sql
-- Purpose: Add columns to track FET token usage in orders.
-- ============================================================================

BEGIN;

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS payment_fet_amount bigint NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS payment_fet_converted_amount decimal(12,2) NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.orders.payment_fet_amount IS 'Amount of FET tokens applied to this order.';
COMMENT ON COLUMN public.orders.payment_fet_converted_amount IS 'Value of applied FET tokens in the order currency.';

COMMIT;
