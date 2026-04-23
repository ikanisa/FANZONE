DROP POLICY IF EXISTS "Admin write app config remote" ON public.app_config_remote;
CREATE POLICY "Admin write app config remote"
ON public.app_config_remote
TO authenticated
USING (public.is_admin_manager(auth.uid()))
WITH CHECK (public.is_admin_manager(auth.uid()));

DROP POLICY IF EXISTS "Admin write country currency map" ON public.country_currency_map;
CREATE POLICY "Admin write country currency map"
ON public.country_currency_map
TO authenticated
USING (public.is_admin_manager(auth.uid()))
WITH CHECK (public.is_admin_manager(auth.uid()));

DROP POLICY IF EXISTS "Admin write country region map" ON public.country_region_map;
CREATE POLICY "Admin write country region map"
ON public.country_region_map
TO authenticated
USING (public.is_admin_manager(auth.uid()))
WITH CHECK (public.is_admin_manager(auth.uid()));

DROP POLICY IF EXISTS "Admin write currency display metadata" ON public.currency_display_metadata;
CREATE POLICY "Admin write currency display metadata"
ON public.currency_display_metadata
TO authenticated
USING (public.is_admin_manager(auth.uid()))
WITH CHECK (public.is_admin_manager(auth.uid()));

DROP POLICY IF EXISTS "Admin write phone presets" ON public.phone_presets;
CREATE POLICY "Admin write phone presets"
ON public.phone_presets
TO authenticated
USING (public.is_admin_manager(auth.uid()))
WITH CHECK (public.is_admin_manager(auth.uid()));
