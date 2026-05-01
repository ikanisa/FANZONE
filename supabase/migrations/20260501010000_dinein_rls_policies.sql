-- ============================================================================
-- DineIn RLS Policies
-- Migration: 20260501_dinein_rls_policies.sql
-- Purpose: Row-Level Security for all DineIn hospitality tables
-- Depends on: 20260501_dinein_schema_merge.sql
-- ============================================================================

BEGIN;

-- ══════════════════════════════════════════════════════════════════════════════
-- 1. venues
-- ══════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.venues ENABLE ROW LEVEL SECURITY;

-- Public: anyone can read active venues
CREATE POLICY venues_select_public ON public.venues
  FOR SELECT
  USING (is_active = true);

-- Authenticated owner: can insert their own venue
CREATE POLICY venues_insert_owner ON public.venues
  FOR INSERT
  TO authenticated
  WITH CHECK (owner_id = auth.uid());

-- Venue member (owner/manager): can update venue
CREATE POLICY venues_update_member ON public.venues
  FOR UPDATE
  TO authenticated
  USING (
    public.dinein_is_venue_member(id, ARRAY['owner', 'manager']::public.venue_user_role[])
  )
  WITH CHECK (
    public.dinein_is_venue_member(id, ARRAY['owner', 'manager']::public.venue_user_role[])
  );

-- ══════════════════════════════════════════════════════════════════════════════
-- 2. tables
-- ══════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.tables ENABLE ROW LEVEL SECURITY;

-- Public: anyone can read tables of active venues
CREATE POLICY tables_select_public ON public.tables
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.venues v
      WHERE v.id = venue_id AND v.is_active = true
    )
  );

-- Venue member: can manage tables
CREATE POLICY tables_insert_member ON public.tables
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.dinein_is_venue_member(venue_id)
  );

CREATE POLICY tables_update_member ON public.tables
  FOR UPDATE
  TO authenticated
  USING (public.dinein_is_venue_member(venue_id))
  WITH CHECK (public.dinein_is_venue_member(venue_id));

CREATE POLICY tables_delete_member ON public.tables
  FOR DELETE
  TO authenticated
  USING (
    public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[])
  );

-- ══════════════════════════════════════════════════════════════════════════════
-- 3. venue_users
-- ══════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.venue_users ENABLE ROW LEVEL SECURITY;

-- Members can see their own membership and co-members in venues they belong to
CREATE POLICY venue_users_select_member ON public.venue_users
  FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[])
  );

-- Owner/manager can invite (insert) members
CREATE POLICY venue_users_insert_owner ON public.venue_users
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[])
  );

-- Owner/manager can update members (promote/deactivate)
CREATE POLICY venue_users_update_owner ON public.venue_users
  FOR UPDATE
  TO authenticated
  USING (
    public.dinein_is_venue_member(venue_id, ARRAY['owner']::public.venue_user_role[])
  )
  WITH CHECK (
    public.dinein_is_venue_member(venue_id, ARRAY['owner']::public.venue_user_role[])
  );

-- Owner can remove members
CREATE POLICY venue_users_delete_owner ON public.venue_users
  FOR DELETE
  TO authenticated
  USING (
    public.dinein_is_venue_member(venue_id, ARRAY['owner']::public.venue_user_role[])
  );

-- ══════════════════════════════════════════════════════════════════════════════
-- 4. menu_categories
-- ══════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.menu_categories ENABLE ROW LEVEL SECURITY;

-- Public: anyone can read visible categories of active venues
CREATE POLICY menu_categories_select_public ON public.menu_categories
  FOR SELECT
  USING (
    is_visible = true
    AND EXISTS (
      SELECT 1 FROM public.venues v
      WHERE v.id = venue_id AND v.is_active = true
    )
  );

-- Venue member: full write
CREATE POLICY menu_categories_insert_member ON public.menu_categories
  FOR INSERT
  TO authenticated
  WITH CHECK (public.dinein_is_venue_member(venue_id));

CREATE POLICY menu_categories_update_member ON public.menu_categories
  FOR UPDATE
  TO authenticated
  USING (public.dinein_is_venue_member(venue_id))
  WITH CHECK (public.dinein_is_venue_member(venue_id));

CREATE POLICY menu_categories_delete_member ON public.menu_categories
  FOR DELETE
  TO authenticated
  USING (
    public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[])
  );

-- ══════════════════════════════════════════════════════════════════════════════
-- 5. menu_items
-- ══════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;

-- Public: anyone can read available items of active venues
CREATE POLICY menu_items_select_public ON public.menu_items
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.venues v
      WHERE v.id = venue_id AND v.is_active = true
    )
  );

-- Venue member: full write
CREATE POLICY menu_items_insert_member ON public.menu_items
  FOR INSERT
  TO authenticated
  WITH CHECK (public.dinein_is_venue_member(venue_id));

CREATE POLICY menu_items_update_member ON public.menu_items
  FOR UPDATE
  TO authenticated
  USING (public.dinein_is_venue_member(venue_id))
  WITH CHECK (public.dinein_is_venue_member(venue_id));

CREATE POLICY menu_items_delete_member ON public.menu_items
  FOR DELETE
  TO authenticated
  USING (
    public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[])
  );

-- ══════════════════════════════════════════════════════════════════════════════
-- 6. orders
-- ══════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- User: read own orders
CREATE POLICY orders_select_user ON public.orders
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Venue member: read venue orders
CREATE POLICY orders_select_venue_member ON public.orders
  FOR SELECT
  TO authenticated
  USING (public.dinein_is_venue_member(venue_id));

-- Authenticated user: place orders (user_id defaults to auth.uid())
CREATE POLICY orders_insert_user ON public.orders
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Venue member: update order status (received, served, cancelled)
CREATE POLICY orders_update_venue_member ON public.orders
  FOR UPDATE
  TO authenticated
  USING (public.dinein_is_venue_member(venue_id))
  WITH CHECK (public.dinein_is_venue_member(venue_id));

-- ══════════════════════════════════════════════════════════════════════════════
-- 7. order_items
-- ══════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- User: read own order items
CREATE POLICY order_items_select_user ON public.order_items
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.orders o
      WHERE o.id = order_id AND o.user_id = auth.uid()
    )
  );

-- Venue member: read venue order items
CREATE POLICY order_items_select_venue ON public.order_items
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.orders o
      WHERE o.id = order_id
        AND public.dinein_is_venue_member(o.venue_id)
    )
  );

-- Authenticated user: insert items for own orders
CREATE POLICY order_items_insert_user ON public.order_items
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.orders o
      WHERE o.id = order_id AND o.user_id = auth.uid()
    )
  );

-- ══════════════════════════════════════════════════════════════════════════════
-- 8. bell_requests
-- ══════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.bell_requests ENABLE ROW LEVEL SECURITY;

-- User: create bell requests
CREATE POLICY bell_requests_insert_user ON public.bell_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- User: read own bell requests
CREATE POLICY bell_requests_select_user ON public.bell_requests
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Venue member: read + acknowledge bell requests
CREATE POLICY bell_requests_select_venue ON public.bell_requests
  FOR SELECT
  TO authenticated
  USING (public.dinein_is_venue_member(venue_id));

CREATE POLICY bell_requests_update_venue ON public.bell_requests
  FOR UPDATE
  TO authenticated
  USING (public.dinein_is_venue_member(venue_id))
  WITH CHECK (public.dinein_is_venue_member(venue_id));

-- ══════════════════════════════════════════════════════════════════════════════
-- 9. pending_menu_imports
-- ══════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.pending_menu_imports ENABLE ROW LEVEL SECURITY;

-- Venue member: full CRUD on own venue imports
CREATE POLICY pending_menu_imports_select ON public.pending_menu_imports
  FOR SELECT
  TO authenticated
  USING (public.dinein_is_venue_member(venue_id));

CREATE POLICY pending_menu_imports_insert ON public.pending_menu_imports
  FOR INSERT
  TO authenticated
  WITH CHECK (public.dinein_is_venue_member(venue_id));

CREATE POLICY pending_menu_imports_update ON public.pending_menu_imports
  FOR UPDATE
  TO authenticated
  USING (public.dinein_is_venue_member(venue_id))
  WITH CHECK (public.dinein_is_venue_member(venue_id));

CREATE POLICY pending_menu_imports_delete ON public.pending_menu_imports
  FOR DELETE
  TO authenticated
  USING (
    public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[])
  );

-- ══════════════════════════════════════════════════════════════════════════════
-- 10. payment_events
-- ══════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.payment_events ENABLE ROW LEVEL SECURITY;

-- Venue member: read payment events for orders in their venue
CREATE POLICY payment_events_select_venue ON public.payment_events
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.orders o
      WHERE o.id = order_id
        AND public.dinein_is_venue_member(o.venue_id)
    )
  );

-- Service-role only inserts (from edge functions / webhooks)
-- No user insert policy — payment_events are server-managed

COMMIT;
