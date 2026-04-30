import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';

export interface VenueStats {
  dailyRevenue: number;
  fetRedeemed: number;
  activeOrders: number;
  matchGuests: number;
}

export function useVenueStats(venueId: string) {
  const [stats, setStats] = useState<VenueStats>({
    dailyRevenue: 0,
    fetRedeemed: 0,
    activeOrders: 0,
    matchGuests: 0,
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!venueId) return;

    const fetchStats = async () => {
      setLoading(true);
      try {
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        // Fetch daily revenue and FET redeemed
        const { data: orders } = await supabase
          .from('orders')
          .select('total_amount, payment_fet_amount, status')
          .eq('venue_id', venueId)
          .gte('created_at', today.toISOString());

        // Fetch active orders (not served or cancelled)
        const { count: activeOrders } = await supabase
          .from('orders')
          .select('*', { count: 'exact', head: true })
          .eq('venue_id', venueId)
          .in('status', ['placed', 'received']);

        // Fetch match guests (participants in active stakes)
        const { data: stakes } = await supabase
          .from('venue_match_stakes')
          .select('id')
          .eq('venue_id', venueId)
          .eq('status', 'open');
        
        let guestCount = 0;
        if (stakes && stakes.length > 0) {
           const stakeIds = stakes.map(s => s.id);
           const { count } = await supabase
             .from('venue_match_stake_entries')
             .select('*', { count: 'exact', head: true })
             .in('stake_id', stakeIds);
           guestCount = count || 0;
        }

        const dailyRevenue = (orders || [])
          .filter(o => o.status !== 'cancelled')
          .reduce((sum, o) => sum + Number(o.total_amount || 0), 0);
        
        const fetRedeemed = (orders || [])
          .filter(o => o.status !== 'cancelled')
          .reduce((sum, o) => sum + Number(o.payment_fet_amount || 0), 0);

        setStats({
          dailyRevenue,
          fetRedeemed,
          activeOrders: activeOrders || 0,
          matchGuests: guestCount,
        });
      } catch (err) {
        console.error('Failed to fetch stats:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchStats();

    // Subscribe to order changes to refresh stats
    const channel = supabase
      .channel(`venue-stats-${venueId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'orders', filter: `venue_id=eq.${venueId}` },
        () => fetchStats()
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [venueId]);

  return { stats, loading };
}
