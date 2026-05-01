import { useCallback, useEffect, useState } from 'react';
import type { Order, OrderStatus, PaymentMethod, PaymentStatus } from '@fanzone/core';
import { supabase } from '../lib/supabase';
import {
  fetchVenueOrders,
  setOrderPaymentStatus,
  setOrderServiceStatus,
} from '../services/venueOperations';

export function useOrders(venueId: string) {
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    if (!venueId) {
      setOrders([]);
      return;
    }

    setLoading(true);
    setError(null);
    try {
      setOrders(await fetchVenueOrders(venueId));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch orders.');
    } finally {
      setLoading(false);
    }
  }, [venueId]);

  useEffect(() => {
    if (!venueId) return;

    const timer = window.setTimeout(() => {
      void refresh();
    }, 0);

    const channel = supabase
      .channel(`venue-orders-${venueId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'orders',
          filter: `venue_id=eq.${venueId}`,
        },
        () => refresh(),
      )
      .subscribe();

    return () => {
      window.clearTimeout(timer);
      supabase.removeChannel(channel);
    };
  }, [refresh, venueId]);

  const updateOrderStatus = async (orderId: string, status: OrderStatus) => {
    await setOrderServiceStatus(orderId, status);
    await refresh();
  };

  const updatePaymentStatus = async (
    orderId: string,
    paymentStatus: PaymentStatus,
    paymentMethod: PaymentMethod,
    note?: string,
  ) => {
    await setOrderPaymentStatus(orderId, paymentStatus, paymentMethod, note);
    await refresh();
  };

  return {
    orders: venueId ? orders : [],
    loading: venueId ? loading : false,
    error: venueId ? error : null,
    refresh,
    updateOrderStatus,
    updatePaymentStatus,
  };
}
