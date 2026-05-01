import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import type { VenueMatchStake, VenueMatchStakeRow } from '@fanzone/core';

function mapStake(row: VenueMatchStakeRow): VenueMatchStake {
  return {
    id: row.id,
    venueId: row.venue_id,
    matchId: row.match_id,
    entryFeeFet: row.entry_fee_fet,
    totalPoolFet: row.total_pool_fet,
    status: row.status,
    createdAt: row.created_at,
  };
}

export function useVenueStakes(venueId: string) {
  const [stakes, setStakes] = useState<VenueMatchStake[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!venueId) return;

    const fetchStakes = async () => {
      setLoading(true);
      try {
        const { data, error } = await supabase
          .from('venue_match_stakes')
          .select('*')
          .eq('venue_id', venueId)
          .order('created_at', { ascending: false });

        if (error) throw error;
        setStakes(((data ?? []) as VenueMatchStakeRow[]).map(mapStake));
      } catch (err) {
        console.error('Failed to fetch stakes:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchStakes();

    const channel = supabase
      .channel(`venue-stakes-${venueId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'venue_match_stakes', filter: `venue_id=eq.${venueId}` },
        () => fetchStakes()
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [venueId]);

  return { stakes, loading };
}
