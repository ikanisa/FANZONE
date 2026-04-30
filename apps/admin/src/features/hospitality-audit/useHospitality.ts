import {
  useSupabaseList,
  useSupabaseMutation,
} from "../../hooks/useSupabaseQuery";
import {
  adminEnvError,
  isSupabaseConfigured,
  supabase,
} from "../../lib/supabase";
import type { Venue, HospitalityAuditStats } from "../../types";

export function useVenues() {
  return useSupabaseList<Venue>(
    ["venues"],
    "venues",
    {
      order: { column: "name", ascending: true },
    },
  );
}

export function useHospitalityAuditStats() {
  return useSupabaseMutation<void, HospitalityAuditStats>({
    mutationFn: async () => {
      if (!isSupabaseConfigured) {
        throw new Error(adminEnvError);
      }

      // In a real implementation, this would be a specialized RPC or a complex join
      // For now, we'll aggregate common stats
      const [ordersRes, venuesRes, stakesRes] = await Promise.all([
        supabase.from("orders").select("total_amount, payment_fet_amount"),
        supabase.from("venues").select("id", { count: "exact", head: true }).eq("is_active", true),
        supabase.from("venue_match_stakes").select("total_pool_fet"),
      ]);

      const orders = ordersRes.data || [];
      const stakes = stakesRes.data || [];

      return {
        totalOrders: orders.length,
        totalRevenueEur: orders.reduce((sum, o) => sum + (Number(o.total_amount) || 0), 0),
        totalFetRedeemed: orders.reduce((sum, o) => sum + (Number(o.payment_fet_amount) || 0), 0),
        totalStakesCreated: stakes.length,
        totalStakedFet: stakes.reduce((sum, s) => sum + (Number(s.total_pool_fet) || 0), 0),
        activeVenuesCount: venuesRes.count || 0,
      };
    },
  });
}

export interface UpsertVenueArgs extends Partial<Venue> {
  name: string;
  slug: string;
  country_code: string;
}

export function useUpsertVenue() {
  return useSupabaseMutation<UpsertVenueArgs>({
    mutationFn: async (args) => {
      if (!isSupabaseConfigured) {
        throw new Error(adminEnvError);
      }

      const { data, error } = await supabase
        .from("venues")
        .upsert({
          ...args,
          updated_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (error) {
        throw new Error(error.message);
      }

      return data;
    },
    invalidateKeys: [["venues"]],
    successMessage: "Venue saved successfully.",
  });
}
