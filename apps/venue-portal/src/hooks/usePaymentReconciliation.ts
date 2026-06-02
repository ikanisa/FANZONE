import { useCallback, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import {
  fetchVenuePaymentReconciliation,
  type PaymentReconciliationSummary,
} from '../services/venueOperations';

function todayUtcDate() {
  return new Date().toISOString().slice(0, 10);
}

export function usePaymentReconciliation(venueId: string) {
  const [businessDate, setBusinessDate] = useState(todayUtcDate);
  const [rows, setRows] = useState<PaymentReconciliationSummary[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    if (!venueId) {
      setRows([]);
      return;
    }

    setLoading(true);
    setError(null);
    try {
      setRows(await fetchVenuePaymentReconciliation(venueId, businessDate));
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : 'Failed to load payment reconciliation.',
      );
    } finally {
      setLoading(false);
    }
  }, [businessDate, venueId]);

  useEffect(() => {
    if (!venueId) return;

    const timer = window.setTimeout(() => {
      void refresh();
    }, 0);

    const channel = supabase
      .channel(`venue-payment-reconciliation-${venueId}-${Date.now()}-${Math.random().toString(16).slice(2)}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'orders', filter: `venue_id=eq.${venueId}` },
        () => refresh(),
      )
      .subscribe();

    return () => {
      window.clearTimeout(timer);
      supabase.removeChannel(channel);
    };
  }, [refresh, venueId]);

  return {
    businessDate,
    setBusinessDate,
    rows,
    loading: venueId ? loading : false,
    error: venueId ? error : null,
    refresh,
  };
}
