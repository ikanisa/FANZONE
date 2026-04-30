import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { Order, OrderStatus } from '@fanzone/core';

export function useOrders(venueId: string) {
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!venueId) return;

    // 1. Initial Fetch
    const fetchOrders = async () => {
      try {
        const { data, error } = await supabase
          .from('orders')
          .select('*, items:order_items(*)')
          .eq('venue_id', venueId)
          .neq('status', 'cancelled')
          .neq('status', 'served')
          .order('created_at', { ascending: true });

        if (error) throw error;
        setOrders(data as Order[]);
      } catch (err: any) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };

    fetchOrders();

    // 2. Realtime Subscription
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
        async (payload) => {
          if (payload.eventType === 'INSERT') {
            // Fetch full order with items for new orders
            const { data } = await supabase
              .from('orders')
              .select('*, items:order_items(*)')
              .eq('id', payload.new.id)
              .single();
            
            if (data) {
              setOrders((current) => [...current, data as Order]);
              // Play chime?
            }
          } else if (payload.eventType === 'UPDATE') {
            const updatedOrder = payload.new as Order;
            if (updatedOrder.status === 'served' || updatedOrder.status === 'cancelled') {
              setOrders((current) => current.filter((o) => o.id !== updatedOrder.id));
            } else {
              setOrders((current) =>
                current.map((o) => (o.id === updatedOrder.id ? { ...o, ...updatedOrder } : o))
              );
            }
          } else if (payload.eventType === 'DELETE') {
            setOrders((current) => current.filter((o) => o.id !== payload.old.id));
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [venueId]);

  const updateOrderStatus = async (orderId: string, status: OrderStatus) => {
    const { error } = await supabase
      .from('orders')
      .update({ status })
      .eq('id', orderId);
    
    if (error) throw error;
  };

  return { orders, loading, error, updateOrderStatus };
}
