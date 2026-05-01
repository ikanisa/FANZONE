import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import type { Order, OrderItem, OrderItemRow, OrderRow, OrderStatus } from '@fanzone/core';

type OrderWithItemsRow = OrderRow & {
  items?: OrderItemRow[] | null;
};

function mapOrderItem(row: OrderItemRow): OrderItem {
  return {
    id: row.id,
    orderId: row.order_id,
    itemNameSnapshot: row.item_name_snapshot,
    quantity: row.quantity,
    unitPrice: row.unit_price,
    lineTotal: row.line_total,
  };
}

function mapOrder(row: OrderWithItemsRow): Order {
  return {
    id: row.id,
    venueId: row.venue_id,
    tableId: row.table_id,
    orderCode: row.order_code,
    status: row.status,
    paymentMethod: row.payment_method,
    paymentStatus: row.payment_status,
    currencyCode: row.currency_code,
    subtotalAmount: row.subtotal_amount,
    totalAmount: row.total_amount,
    paymentFetAmount: row.payment_fet_amount,
    paymentFetConvertedAmount: row.payment_fet_converted_amount,
    createdAt: row.created_at,
    items: row.items?.map(mapOrderItem) ?? [],
  };
}

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
        setOrders(((data ?? []) as unknown as OrderWithItemsRow[]).map(mapOrder));
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to fetch orders.');
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
        () => fetchOrders()
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
