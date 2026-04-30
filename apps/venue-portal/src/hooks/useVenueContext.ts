import React, { createContext, useContext, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { Venue, VenueMember } from '@fanzone/core';

interface VenueContextType {
  venue: Venue | null;
  member: VenueMember | null;
  loading: boolean;
  error: string | null;
}

const VenueContext = createContext<VenueContextType>({
  venue: null,
  member: null,
  loading: true,
  error: null,
});

export const useVenue = () => useContext(VenueContext);

export const VenueProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [venue, setVenue] = useState<Venue | null>(null);
  const [member, setMember] = useState<VenueMember | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function loadContext() {
      setLoading(true);
      try {
        const { data: { session } } = await supabase.auth.getSession();
        if (!session?.user) {
          setLoading(false);
          return;
        }

        // Fetch venue membership
        const { data: memberData, error: memberError } = await supabase
          .from('venue_users')
          .select('*, venue:venues(*)')
          .eq('user_id', session.user.id)
          .eq('is_active', true)
          .maybeSingle();

        if (memberError) throw memberError;
        if (!memberData) {
          setError('You are not associated with any active venue.');
          setLoading(false);
          return;
        }

        setMember({
          id: memberData.id,
          venueId: memberData.venue_id,
          userId: memberData.user_id,
          role: memberData.role,
          isActive: memberData.is_active,
        });

        const v = memberData.venue;
        setVenue({
          id: v.id,
          name: v.name,
          slug: v.slug,
          description: v.description,
          address: v.address_line1,
          country: v.country_code,
          logoUrl: v.logo_url,
          coverUrl: v.cover_url,
          isOpen: v.is_open,
          hoursJson: v.hours_json,
          revolutLink: v.revolut_link,
          whatsapp: v.whatsapp,
          primaryCategory: v.primary_category,
          rating: v.rating,
          priceLevel: v.price_level,
        });
      } catch (err: any) {
        console.error('Failed to load venue context:', err);
        setError(err.message);
      } finally {
        setLoading(false);
      }
    }

    loadContext();

    const { data: { subscription } } = supabase.auth.onAuthStateChange(() => {
      loadContext();
    });

    return () => subscription.unsubscribe();
  }, []);

  return (
    <VenueContext.Provider value={{ venue, member, loading, error }}>
      {children}
    </VenueContext.Provider>
  );
};

export function useVenueContext() {
  return useVenue();
}
