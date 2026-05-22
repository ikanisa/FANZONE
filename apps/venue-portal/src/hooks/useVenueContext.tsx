/* eslint-disable react-refresh/only-export-components */
import React, { createContext, useContext, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import type { Json, Venue, VenueMember, VenueRow, VenueUserRow } from '@fanzone/core';
import { useVenueAuth } from './useVenueAuth';

type VenueUserWithVenue = VenueUserRow & {
  venue: VenueRow | null;
};

function mapHoursJson(value: Json | null): Record<string, Json> | undefined {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return undefined;
  }
  return value as Record<string, Json>;
}

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
  const { session } = useVenueAuth();
  const [venue, setVenue] = useState<Venue | null>(null);
  const [member, setMember] = useState<VenueMember | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function loadContext() {
      setLoading(true);
      setError(null);
      try {
        if (!session?.userId) {
          if (!cancelled) {
            setVenue(null);
            setMember(null);
            setLoading(false);
          }
          return;
        }

        if (!cancelled) {
          setVenue(null);
          setMember(null);
        }

        // Fetch venue membership
        const { data: memberData, error: memberError } = await supabase
          .from('venue_users')
          .select('*, venue:venues(*)')
          .eq('user_id', session.userId)
          .eq('is_active', true)
          .maybeSingle();

        if (memberError) throw memberError;
        if (!memberData) {
          if (!cancelled) {
            setVenue(null);
            setMember(null);
            setError('You are not associated with any active venue.');
            setLoading(false);
          }
          return;
        }

        const venueUser = memberData as unknown as VenueUserWithVenue;
        const nextMember: VenueMember = {
          id: venueUser.id,
          venueId: venueUser.venue_id,
          userId: venueUser.user_id,
          role: venueUser.role,
          isActive: venueUser.is_active,
        };

        const v = venueUser.venue;
        if (!v) {
          if (!cancelled) {
            setVenue(null);
            setMember(nextMember);
            setError('Venue details are unavailable for this account.');
            setLoading(false);
          }
          return;
        }

        const nextVenue: Venue = {
          id: v.id,
          name: v.name,
          slug: v.slug,
          description: v.description,
          address: v.address_line1,
          country: v.country_code,
          logoUrl: v.logo_url,
          coverUrl: v.cover_url,
          isOpen: v.is_open,
          hoursJson: mapHoursJson(v.hours_json),
          revolutLink: v.revolut_link,
          momoCode: v.momo_code,
          whatsapp: v.whatsapp,
          primaryCategory: v.primary_category,
          rating: v.rating,
          priceLevel: v.price_level,
        };

        if (!cancelled) {
          setMember(nextMember);
          setVenue(nextVenue);
        }
      } catch (err) {
        if (!cancelled) {
          console.error('Failed to load venue context:', err);
          setVenue(null);
          setMember(null);
          setError(err instanceof Error ? err.message : 'Failed to load venue context.');
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    void loadContext();

    const reload = () => void loadContext();
    window.addEventListener('fanzone:venue-auth-change', reload);
    return () => {
      cancelled = true;
      window.removeEventListener('fanzone:venue-auth-change', reload);
    };
  }, [session?.userId]);

  return (
    <VenueContext.Provider value={{ venue, member, loading, error }}>
      {children}
    </VenueContext.Provider>
  );
};

export function useVenueContext() {
  return useVenue();
}
