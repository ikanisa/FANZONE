import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { VenueMatchStake } from '@fanzone/core';

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
        setStakes(data as VenueMatchStake[]);
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
