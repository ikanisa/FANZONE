import type {
  Json,
  Order,
  OrderItem,
  OrderItemRow,
  OrderRow,
  OrderStatus,
  PaymentMethod,
  PaymentStatus,
  VenueOperationalInsights,
  VenueTableRow,
} from '@fanzone/core';
import { supabase } from '../lib/supabase';

export interface RewardConfig {
  venue_id?: string;
  reward_percent: number;
  reward_trigger: 'paid' | 'served';
  accepts_fet_spend: boolean;
  redemption_fet_per_currency: number | null;
  max_fet_spend_per_order: number | null;
  reward_campaign_active: boolean;
  platform_default_reward_percent?: number;
  platform_default_reward_trigger?: string;
}

export interface RewardSummary {
  order_earned_today_fet: number;
  order_spent_today_fet: number;
  pending_settlements_fet: number;
}

export interface VenueTable {
  id: string;
  venueId: string;
  tableNumber: string;
  qrToken: string | null;
  qrUrl: string | null;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

type RpcError = { message?: string } | null;
type SupabaseRpc = {
  rpc<T = Json>(
    fn: string,
    params: Record<string, unknown>,
  ): Promise<{ data: T | null; error: RpcError }>;
};

type OrderWithRelations = OrderRow & {
  items?: OrderItemRow[] | null;
  table?: { table_number?: string | null } | Array<{ table_number?: string | null }> | null;
};

const rpcClient = supabase as unknown as SupabaseRpc;

function asRecord(value: Json | null | undefined): Record<string, Json | undefined> {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, Json | undefined>)
    : {};
}

function toNumber(value: unknown, fallback = 0): number {
  const parsed = Number(value ?? fallback);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function normalizePaymentStatus(status: PaymentStatus): PaymentStatus {
  if (status === 'pending') return 'unpaid';
  if (status === 'failed' || status === 'cancelled') return 'disputed';
  return status;
}

function mapOrderItem(row: OrderItemRow): OrderItem {
  return {
    id: row.id,
    orderId: row.order_id,
    itemNameSnapshot: row.item_name_snapshot,
    quantity: Number(row.quantity),
    unitPrice: Number(row.unit_price),
    lineTotal: Number(row.line_total),
  };
}

function relationTableNumber(row: OrderWithRelations): string | null {
  if (!row.table) return null;
  if (Array.isArray(row.table)) return row.table[0]?.table_number ?? null;
  return row.table.table_number ?? null;
}

export function mapOrder(row: OrderWithRelations): Order {
  return {
    id: row.id,
    venueId: row.venue_id,
    tableId: row.table_id,
    tableNumber: relationTableNumber(row),
    orderCode: row.order_code,
    status: row.status,
    paymentMethod: row.payment_method,
    paymentStatus: normalizePaymentStatus(row.payment_status),
    currencyCode: row.currency_code,
    subtotalAmount: toNumber(row.subtotal_amount),
    taxAmount: toNumber(row.tax_amount),
    tipAmount: toNumber(row.tip_amount),
    totalAmount: toNumber(row.total_amount),
    paymentFetAmount: toNumber(row.payment_fet_amount),
    paymentFetConvertedAmount: toNumber(row.payment_fet_converted_amount),
    fetEarned: toNumber(row.fet_earned),
    fetSpent: toNumber(row.fet_spent),
    specialInstructions: row.special_instructions ?? null,
    acceptedAt: row.accepted_at ?? null,
    servedAt: row.served_at ?? null,
    statusChangedAt: row.status_changed_at ?? null,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    items: row.items?.map(mapOrderItem) ?? [],
  };
}

export async function fetchVenueOrders(venueId: string): Promise<Order[]> {
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { data, error } = await supabase
    .from('orders')
    .select('*, items:order_items(*), table:tables(table_number)')
    .eq('venue_id', venueId)
    .gte('created_at', since)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return ((data ?? []) as unknown as OrderWithRelations[]).map(mapOrder);
}

export async function setOrderServiceStatus(orderId: string, status: OrderStatus) {
  const { error } = await supabase.functions.invoke('order_update_status', {
    body: { order_id: orderId, status },
  });

  if (error) throw error;
}

export async function setOrderPaymentStatus(
  orderId: string,
  paymentStatus: PaymentStatus,
  paymentMethod: PaymentMethod,
  note?: string,
) {
  const { data, error } = await supabase.rpc('venue_update_order_payment_status', {
    p_order_id: orderId,
    p_payment_status: normalizePaymentStatus(paymentStatus),
    p_payment_method: paymentMethod,
    p_actor_note: note?.trim() || null,
  });

  if (error) throw error;
  return data;
}

export function mapRewardConfig(value: Partial<RewardConfig> | Json | null | undefined): RewardConfig {
  const record = asRecord(value as Json);
  return {
    venue_id: typeof record.venue_id === 'string' ? record.venue_id : undefined,
    reward_percent: toNumber(record.reward_percent, 10),
    reward_trigger: record.reward_trigger === 'served' ? 'served' : 'paid',
    accepts_fet_spend: Boolean(record.accepts_fet_spend),
    redemption_fet_per_currency:
      record.redemption_fet_per_currency == null
        ? null
        : toNumber(record.redemption_fet_per_currency, 0),
    max_fet_spend_per_order:
      record.max_fet_spend_per_order == null
        ? null
        : toNumber(record.max_fet_spend_per_order, 0),
    reward_campaign_active: record.reward_campaign_active !== false,
    platform_default_reward_percent:
      record.platform_default_reward_percent == null
        ? undefined
        : toNumber(record.platform_default_reward_percent, 10),
    platform_default_reward_trigger:
      typeof record.platform_default_reward_trigger === 'string'
        ? record.platform_default_reward_trigger
        : undefined,
  };
}

export async function fetchRewardConfig(venueId: string): Promise<RewardConfig> {
  const { data, error } = await rpcClient.rpc<Json>('get_venue_fet_reward_config', {
    p_venue_id: venueId,
  });

  if (error) throw new Error(error.message ?? 'Failed to load reward configuration.');
  return mapRewardConfig(data);
}

export async function fetchRewardSummary(venueId: string): Promise<RewardSummary> {
  const { data, error } = await rpcClient.rpc<Json>('get_venue_fet_reward_summary', {
    p_venue_id: venueId,
  });

  if (error) throw new Error(error.message ?? 'Failed to load reward summary.');
  const record = asRecord(data);
  return {
    order_earned_today_fet: toNumber(record.order_earned_today_fet),
    order_spent_today_fet: toNumber(record.order_spent_today_fet),
    pending_settlements_fet: toNumber(record.pending_settlements_fet),
  };
}

export async function saveRewardConfig(venueId: string, config: RewardConfig): Promise<RewardConfig> {
  const { data, error } = await rpcClient.rpc<Json>('update_venue_fet_reward_config', {
    p_venue_id: venueId,
    p_reward_percent: config.reward_percent,
    p_reward_trigger: config.reward_trigger,
    p_accepts_fet_spend: config.accepts_fet_spend,
    p_redemption_fet_per_currency: config.redemption_fet_per_currency,
    p_max_fet_spend_per_order: config.max_fet_spend_per_order,
    p_reward_campaign_active: config.reward_campaign_active,
  });

  if (error) throw new Error(error.message ?? 'Failed to save reward configuration.');
  return mapRewardConfig(data);
}

function mapVenueTable(row: VenueTableRow): VenueTable {
  return {
    id: row.id,
    venueId: row.venue_id,
    tableNumber: row.table_number,
    qrToken: row.qr_token ?? null,
    qrUrl: row.qr_url ?? row.deep_link_uri ?? null,
    isActive: row.is_active,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function fetchVenueTables(venueId: string): Promise<VenueTable[]> {
  const { data, error } = await supabase
    .from('venue_tables')
    .select('*')
    .eq('venue_id', venueId)
    .order('table_number', { ascending: true });

  if (error) throw error;
  return ((data ?? []) as VenueTableRow[]).map(mapVenueTable);
}

export async function generateVenueTableQr(venueId: string, tableNumber: string): Promise<VenueTable> {
  const baseUrl = String(import.meta.env.VITE_GUEST_APP_URL || 'https://fanzone.app');
  const { data, error } = await rpcClient.rpc<Json>('generate_table_qr', {
    p_venue_id: venueId,
    p_table_number: tableNumber.trim(),
    p_base_url: baseUrl,
  });

  if (error) throw new Error(error.message ?? 'Failed to generate table QR.');

  const record = asRecord(data);
  return {
    id: String(record.table_id ?? ''),
    venueId,
    tableNumber,
    qrToken: typeof record.qr_token === 'string' ? record.qr_token : null,
    qrUrl: typeof record.qr_url === 'string' ? record.qr_url : null,
    isActive: true,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
}

export async function setVenueTableActive(tableId: string, isActive: boolean) {
  const { error } = await supabase
    .from('tables')
    .update({ is_active: isActive, updated_at: new Date().toISOString() })
    .eq('id', tableId);

  if (error) throw error;
}

export async function fetchVenueOperationalInsights(venueId: string): Promise<VenueOperationalInsights> {
  const { data, error } = await rpcClient.rpc<Json>('get_venue_operational_insights', {
    p_venue_id: venueId,
  });

  if (error) throw new Error(error.message ?? 'Failed to load venue insights.');
  const record = asRecord(data);
  const topItems = Array.isArray(record.top_menu_items)
    ? record.top_menu_items.map((item) => {
        const itemRecord = asRecord(item);
        return {
          name: String(itemRecord.name ?? 'Item'),
          quantity: toNumber(itemRecord.quantity),
          revenue: toNumber(itemRecord.revenue),
        };
      })
    : [];

  const matchRecord = asRecord(record.most_active_match as Json | null);
  const mostActiveMatch = Object.keys(matchRecord).length
    ? {
        pool_id: String(matchRecord.pool_id ?? ''),
        match_id: String(matchRecord.match_id ?? ''),
        title: String(matchRecord.title ?? 'Venue pool'),
        competition_name:
          typeof matchRecord.competition_name === 'string' ? matchRecord.competition_name : null,
        match_label: String(matchRecord.match_label ?? matchRecord.title ?? 'Match pool'),
        status: String(matchRecord.status ?? 'open') as NonNullable<VenueOperationalInsights['most_active_match']>['status'],
        total_members: toNumber(matchRecord.total_members),
        total_staked_fet: toNumber(matchRecord.total_staked_fet),
      }
    : null;

  return {
    today_orders: toNumber(record.today_orders),
    fet_issued: toNumber(record.fet_issued),
    fet_redeemed: toNumber(record.fet_redeemed),
    active_pools: toNumber(record.active_pools),
    most_active_match: mostActiveMatch,
    top_menu_items: topItems,
    pending_payment_count: toNumber(record.pending_payment_count),
  };
}
