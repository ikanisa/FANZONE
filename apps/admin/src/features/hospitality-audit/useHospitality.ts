import {
  useSupabaseList,
  useSupabaseMutation,
} from "../../hooks/useSupabaseQuery";
import { useQuery } from "@tanstack/react-query";
import {
  adminEnvError,
  isSupabaseConfigured,
  supabase,
} from "../../lib/supabase";
import type { Venue, HospitalityAuditStats } from "../../types";

export interface VenuePerformanceRow {
  venueId: string;
  venueName: string;
  orderCount: number;
  revenueEur: number;
  fetRedeemed: number;
  poolCount: number;
  participantCount: number;
}

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
  return useQuery<HospitalityAuditStats>({
    queryKey: ["hospitality-audit-stats"],
    queryFn: async () => {
      if (!isSupabaseConfigured) {
        throw new Error(adminEnvError);
      }

      const [ordersRes, venuesRes, poolsRes] = await Promise.all([
        supabase.from("orders").select("total_amount, payment_fet_amount"),
        supabase.from("venues").select("id", { count: "exact", head: true }).eq("is_active", true),
        supabase.from("match_pools").select("total_staked_fet").eq("scope", "venue"),
      ]);

      const orders = ordersRes.data || [];
      const pools = poolsRes.data || [];

      return {
        totalOrders: orders.length,
        totalRevenueEur: orders.reduce((sum, o) => sum + (Number(o.total_amount) || 0), 0),
        totalFetRedeemed: orders.reduce((sum, o) => sum + (Number(o.payment_fet_amount) || 0), 0),
        totalStakesCreated: pools.length,
        totalStakedFet: pools.reduce((sum, pool) => sum + (Number(pool.total_staked_fet) || 0), 0),
        activeVenuesCount: venuesRes.count || 0,
      };
    },
    refetchInterval: 120_000,
  });
}

export function useVenuePerformance() {
  return useQuery<VenuePerformanceRow[]>({
    queryKey: ["venue-performance"],
    queryFn: async () => {
      if (!isSupabaseConfigured) {
        throw new Error(adminEnvError);
      }

      const [venuesRes, ordersRes, poolsRes] = await Promise.all([
        supabase
          .from("venues")
          .select("id,name,country_code")
          .eq("is_active", true)
          .order("name", { ascending: true }),
        supabase
          .from("orders")
          .select("venue_id,total_amount,payment_fet_amount"),
        supabase
          .from("match_pools")
          .select("venue_id,total_members")
          .eq("scope", "venue"),
      ]);

      if (venuesRes.error) throw new Error(venuesRes.error.message);
      if (ordersRes.error) throw new Error(ordersRes.error.message);
      if (poolsRes.error) throw new Error(poolsRes.error.message);

      const rows = new Map<string, VenuePerformanceRow>();
      for (const venue of venuesRes.data ?? []) {
        rows.set(venue.id, {
          venueId: venue.id,
          venueName: venue.name,
          orderCount: 0,
          revenueEur: 0,
          fetRedeemed: 0,
          poolCount: 0,
          participantCount: 0,
        });
      }

      for (const order of ordersRes.data ?? []) {
        const venueId = order.venue_id;
        const row = rows.get(venueId);
        if (!row) continue;
        row.orderCount += 1;
        row.revenueEur += Number(order.total_amount) || 0;
        row.fetRedeemed += Number(order.payment_fet_amount) || 0;
      }

      for (const pool of poolsRes.data ?? []) {
        const venueId = pool.venue_id;
        const row = rows.get(venueId);
        if (!row) continue;
        row.poolCount += 1;
        row.participantCount += Number(pool.total_members) || 0;
      }

      return [...rows.values()].sort((left, right) => {
        if (right.orderCount !== left.orderCount) {
          return right.orderCount - left.orderCount;
        }
        return left.venueName.localeCompare(right.venueName);
      });
    },
    refetchInterval: 120_000,
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
