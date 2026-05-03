import type {
  Json,
  MenuCategoryRow,
  MenuItemRow,
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

export interface VenueMenuRows {
  categories: MenuCategoryRow[];
  items: MenuItemRow[];
}

export interface VenueMenuCategoryCreateInput {
  venueId: string;
  name: string;
  displayOrder: number;
  isVisible?: boolean;
}

export interface VenueMenuItemCreateInput {
  venueId: string;
  categoryId: string;
  name: string;
  description?: string | null;
  price: number;
  currencyCode: string;
  imageUrl?: string | null;
  fetEarnPercentOverride?: number | null;
  isAvailable?: boolean;
  displayOrder: number;
  metadata?: Json | null;
}

export interface VenueMenuItemUpdateInput {
  itemId: string;
  name: string;
  description?: string | null;
  price: number;
  imageUrl?: string | null;
  fetEarnPercentOverride?: number | null;
}

type OrderWithRelations = OrderRow & {
  items?: OrderItemRow[] | null;
  table?: { table_number?: string | null } | Array<{ table_number?: string | null }> | null;
};

type PaymentEventRow = {
  id: string;
  order_id: string;
  provider: PaymentMethod;
  status: PaymentStatus;
  external_reference: string | null;
  request_payload: Json | null;
  response_payload: Json | null;
  created_at: string;
  updated_at: string;
};

export interface PaymentAuditEvent {
  id: string;
  orderId: string;
  provider: PaymentMethod;
  status: PaymentStatus;
  externalReference: string | null;
  amountReceived: number | null;
  orderTotalAmount: number | null;
  note: string | null;
  actorUserId: string | null;
  beforeStatus: string | null;
  afterStatus: string | null;
  providerApiUsed: boolean;
  createdAt: string;
}

export interface OrderDetail {
  order: Order;
  paymentEvents: PaymentAuditEvent[];
}

export interface ManualPaymentDetails {
  amountReceived?: number | null;
  externalReference?: string | null;
}

export interface VenueFetWallet {
  venueId: string;
  availableBalanceFet: number;
  stakedBalanceFet: number;
  pendingBalanceFet: number;
  updatedAt: string | null;
}

export interface VenueFetLedgerEntry {
  id: string;
  venueId: string;
  transactionType: string;
  direction: 'credit' | 'debit';
  amountFet: number;
  balanceBucket: string;
  balanceBeforeFet: number;
  balanceAfterFet: number;
  referenceType: string | null;
  referenceId: string | null;
  poolId: string | null;
  gameSessionId: string | null;
  title: string;
  status: string;
  createdBy: string | null;
  createdAt: string;
}

export interface GameTemplate {
  id: string;
  name: string;
  category: string;
  isActive: boolean;
}

export interface VenueGameSession {
  id: string;
  venueId: string;
  templateId: string;
  templateName: string;
  templateCategory: string;
  status: string;
  scheduledStartAt: string;
  startedAt: string | null;
  endedAt: string | null;
  rewardFet: number;
  selectedQuestionCount: number;
  currentQuestionOrdinal: number | null;
  createdAt: string;
  metadata: Json | null;
}

export interface VenueGameTeam {
  id: string;
  sessionId: string;
  venueId: string;
  name: string;
  scoreFet: number;
  inviteCode: string | null;
  memberCount: number;
  createdAt: string;
}

export interface VenueGameQuestion {
  sessionId: string;
  questionId: string;
  ordinal: number;
  prompt: string;
  options: Json;
}

export interface VenueGameControl {
  session: VenueGameSession;
  teams: VenueGameTeam[];
  currentQuestion: VenueGameQuestion | null;
}

export type VenueScreenMode =
  | 'welcome'
  | 'qr'
  | 'pool'
  | 'game_lobby'
  | 'game_question'
  | 'leaderboard'
  | 'winners'
  | 'menu'
  | 'promo';

export interface VenueScreenState {
  venueId: string;
  mode: VenueScreenMode;
  activePoolId: string | null;
  activeGameSessionId: string | null;
  payload: Json | null;
  updatedBy: string | null;
  updatedAt: string;
}

export interface VenuePoolEntry {
  id: string;
  poolId: string;
  campId: string;
  userId: string;
  amountFet: number;
  status: string;
  payoutFet: number;
  createdAt: string;
}

export interface VenuePoolSettlement {
  id: string;
  poolId: string;
  status: string;
  resultCampId: string | null;
  winnersCount: number;
  totalPaidFet: number;
  payoutPerWinnerFet: number;
  completedAt: string | null;
  errorMessage: string | null;
}

export interface VenuePoolDetailRecord {
  id: string;
  matchId: string;
  matchLabel: string;
  competitionName: string | null;
  status: string;
  title: string | null;
  kickoffAt: string | null;
  entryFeeFet: number;
  stakeMinFet: number;
  stakeMaxFet: number;
  totalMembers: number;
  totalStakedFet: number;
  barStakeFet: number;
  camps: Array<{
    id: string;
    label: string;
    resultCode: string | null;
    memberCount: number;
    totalStakedFet: number;
    isWinningCamp: boolean;
  }>;
}

export interface VenuePoolDetail {
  pool: VenuePoolDetailRecord;
  entries: VenuePoolEntry[];
  settlement: VenuePoolSettlement | null;
}

function asRecord(value: Json | null | undefined): Record<string, Json | undefined> {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, Json | undefined>)
    : {};
}

function asArray(value: Json | null | undefined): Json[] {
  return Array.isArray(value) ? value : [];
}

function stringOrNull(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null;
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
    userId: row.user_id,
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

function mapPaymentEvent(row: PaymentEventRow): PaymentAuditEvent {
  const request = asRecord(row.request_payload);
  const response = asRecord(row.response_payload);
  return {
    id: row.id,
    orderId: row.order_id,
    provider: row.provider,
    status: normalizePaymentStatus(row.status),
    externalReference: row.external_reference,
    amountReceived:
      request.amount_received == null ? null : toNumber(request.amount_received),
    orderTotalAmount:
      request.order_total_amount == null ? null : toNumber(request.order_total_amount),
    note: typeof request.note === 'string' ? request.note : null,
    actorUserId: typeof request.marked_by === 'string' ? request.marked_by : null,
    beforeStatus: typeof request.before_status === 'string' ? request.before_status : null,
    afterStatus: typeof request.after_status === 'string' ? request.after_status : null,
    providerApiUsed: Boolean(response.provider_api_used),
    createdAt: row.created_at,
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

export async function fetchVenueOrderDetail(venueId: string, orderId: string): Promise<OrderDetail> {
  const { data, error } = await supabase
    .from('orders')
    .select('*, items:order_items(*), table:tables(table_number)')
    .eq('venue_id', venueId)
    .eq('id', orderId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new Error('Order not found for this venue.');

  const { data: events, error: eventError } = await supabase
    .from('payment_events')
    .select('*')
    .eq('order_id', orderId)
    .order('created_at', { ascending: false });

  if (eventError) throw eventError;

  return {
    order: mapOrder(data as unknown as OrderWithRelations),
    paymentEvents: ((events ?? []) as PaymentEventRow[]).map(mapPaymentEvent),
  };
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
  details?: ManualPaymentDetails,
) {
  const { data, error } = await supabase.rpc('venue_update_order_payment_status', {
    p_order_id: orderId,
    p_payment_status: normalizePaymentStatus(paymentStatus),
    p_payment_method: paymentMethod,
    p_actor_note: note?.trim() || null,
    p_amount_received: details?.amountReceived ?? null,
    p_external_reference: details?.externalReference?.trim() || null,
  });

  if (error) throw error;
  return data;
}

function menuItemInsertPayload(input: VenueMenuItemCreateInput) {
  return {
    venue_id: input.venueId,
    category_id: input.categoryId,
    name: input.name,
    description: input.description ?? null,
    price: input.price,
    currency_code: input.currencyCode,
    image_url: input.imageUrl ?? null,
    fet_earn_percent_override: input.fetEarnPercentOverride ?? null,
    is_available: input.isAvailable ?? true,
    display_order: input.displayOrder,
    metadata: input.metadata ?? null,
  };
}

export async function fetchVenueMenuRows(venueId: string): Promise<VenueMenuRows> {
  const [categoryResult, itemResult] = await Promise.all([
    supabase
      .from('menu_categories')
      .select('*')
      .eq('venue_id', venueId)
      .order('display_order', { ascending: true }),
    supabase
      .from('menu_items')
      .select('*')
      .eq('venue_id', venueId)
      .order('display_order', { ascending: true }),
  ]);

  if (categoryResult.error) throw categoryResult.error;
  if (itemResult.error) throw itemResult.error;

  return {
    categories: (categoryResult.data ?? []) as MenuCategoryRow[],
    items: (itemResult.data ?? []) as MenuItemRow[],
  };
}

export async function createVenueMenuCategory(
  input: VenueMenuCategoryCreateInput,
): Promise<MenuCategoryRow> {
  const { data, error } = await supabase
    .from('menu_categories')
    .insert({
      venue_id: input.venueId,
      name: input.name,
      display_order: input.displayOrder,
      is_visible: input.isVisible ?? true,
    })
    .select()
    .single();

  if (error) throw error;
  return data as MenuCategoryRow;
}

export async function updateVenueMenuCategoryOrder(
  categoryId: string,
  displayOrder: number,
): Promise<void> {
  const { error } = await supabase
    .from('menu_categories')
    .update({ display_order: displayOrder })
    .eq('id', categoryId);

  if (error) throw error;
}

export async function setVenueMenuCategoryVisibility(
  categoryId: string,
  isVisible: boolean,
): Promise<void> {
  const { error } = await supabase
    .from('menu_categories')
    .update({ is_visible: isVisible })
    .eq('id', categoryId);

  if (error) throw error;
}

export async function createVenueMenuItem(
  input: VenueMenuItemCreateInput,
): Promise<MenuItemRow> {
  const { data, error } = await supabase
    .from('menu_items')
    .insert(menuItemInsertPayload(input))
    .select()
    .single();

  if (error) throw error;
  return data as MenuItemRow;
}

export async function createVenueMenuItems(items: VenueMenuItemCreateInput[]): Promise<void> {
  if (items.length === 0) return;

  const { error } = await supabase
    .from('menu_items')
    .insert(items.map(menuItemInsertPayload));

  if (error) throw error;
}

export async function updateVenueMenuItem(input: VenueMenuItemUpdateInput): Promise<void> {
  const { error } = await supabase
    .from('menu_items')
    .update({
      name: input.name,
      price: input.price,
      description: input.description ?? null,
      image_url: input.imageUrl ?? null,
      fet_earn_percent_override: input.fetEarnPercentOverride ?? null,
    })
    .eq('id', input.itemId);

  if (error) throw error;
}

export async function setVenueMenuItemAvailability(
  itemId: string,
  isAvailable: boolean,
): Promise<void> {
  const { error } = await supabase
    .from('menu_items')
    .update({ is_available: isAvailable })
    .eq('id', itemId);

  if (error) throw error;
}

export async function deleteVenueMenuItem(itemId: string): Promise<void> {
  const { error } = await supabase.from('menu_items').delete().eq('id', itemId);

  if (error) throw error;
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
  const { data, error } = await supabase.rpc('get_venue_fet_reward_config', {
    p_venue_id: venueId,
  });

  if (error) throw new Error(error.message ?? 'Failed to load reward configuration.');
  return mapRewardConfig(data);
}

export async function fetchRewardSummary(venueId: string): Promise<RewardSummary> {
  const { data, error } = await supabase.rpc('get_venue_fet_reward_summary', {
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
  const { data, error } = await supabase.rpc('update_venue_fet_reward_config', {
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
  const baseUrl = String(import.meta.env.VITE_GUEST_APP_URL || 'https://fanzone.ikanisa.com');
  const { data, error } = await supabase.rpc('generate_table_qr', {
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

type VenueWalletRpcRow = {
  venue_id: string;
  available_balance_fet: number;
  staked_balance_fet: number;
  pending_balance_fet: number;
  updated_at: string | null;
};

function mapVenueWallet(row: VenueWalletRpcRow): VenueFetWallet {
  return {
    venueId: row.venue_id,
    availableBalanceFet: toNumber(row.available_balance_fet),
    stakedBalanceFet: toNumber(row.staked_balance_fet),
    pendingBalanceFet: toNumber(row.pending_balance_fet),
    updatedAt: row.updated_at,
  };
}

export async function fetchVenueFetWallet(venueId: string): Promise<VenueFetWallet> {
  const { data, error } = await supabase.rpc('get_venue_fet_wallet', {
    p_venue_id: venueId,
  });

  if (error) throw error;
  const row = Array.isArray(data) ? data[0] : data;
  if (!row) {
    return {
      venueId,
      availableBalanceFet: 0,
      stakedBalanceFet: 0,
      pendingBalanceFet: 0,
      updatedAt: null,
    };
  }

  return mapVenueWallet(row as VenueWalletRpcRow);
}

type VenueLedgerRow = {
  id: string;
  venue_id: string;
  transaction_type: string;
  direction: 'credit' | 'debit';
  amount_fet: number;
  balance_bucket: string;
  balance_before_fet: number;
  balance_after_fet: number;
  reference_type: string | null;
  reference_id: string | null;
  pool_id: string | null;
  game_session_id: string | null;
  title: string;
  status: string;
  created_by: string | null;
  created_at: string;
};

function mapVenueLedgerEntry(row: VenueLedgerRow): VenueFetLedgerEntry {
  return {
    id: row.id,
    venueId: row.venue_id,
    transactionType: row.transaction_type,
    direction: row.direction,
    amountFet: toNumber(row.amount_fet),
    balanceBucket: row.balance_bucket,
    balanceBeforeFet: toNumber(row.balance_before_fet),
    balanceAfterFet: toNumber(row.balance_after_fet),
    referenceType: row.reference_type,
    referenceId: row.reference_id,
    poolId: row.pool_id,
    gameSessionId: row.game_session_id,
    title: row.title,
    status: row.status,
    createdBy: row.created_by,
    createdAt: row.created_at,
  };
}

export async function fetchVenueFetLedger(
  venueId: string,
  limit = 50,
): Promise<VenueFetLedgerEntry[]> {
  const { data, error } = await supabase
    .from('venue_fet_wallet_transactions')
    .select('*')
    .eq('venue_id', venueId)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return ((data ?? []) as VenueLedgerRow[]).map(mapVenueLedgerEntry);
}

export async function requestVenueFetTopUp(
  venueId: string,
  amountFet: number,
  note: string | null,
): Promise<Json | null> {
  const { data, error } = await supabase.rpc('request_venue_fet_top_up', {
    p_venue_id: venueId,
    p_amount_fet: Math.max(1, Math.round(amountFet)),
    p_note: note?.trim() || null,
  });

  if (error) throw error;
  return data as Json | null;
}

type GameTemplateRow = {
  id: string;
  name: string;
  category: string;
  is_active: boolean;
};

export async function fetchGameTemplates(): Promise<GameTemplate[]> {
  const { data, error } = await supabase
    .from('game_templates')
    .select('id, name, category, is_active')
    .eq('is_active', true)
    .order('name', { ascending: true });

  if (error) throw error;
  return ((data ?? []) as GameTemplateRow[]).map((row) => ({
    id: row.id,
    name: row.name,
    category: row.category,
    isActive: row.is_active,
  }));
}

type GameSessionRow = {
  id: string;
  venue_id: string;
  template_id: string;
  status: string;
  scheduled_start_at: string;
  started_at: string | null;
  ended_at: string | null;
  reward_fet: number;
  selected_question_count: number;
  current_question_ordinal: number | null;
  metadata: Json | null;
  created_at: string;
  template?: { name?: string | null; category?: string | null } | Array<{ name?: string | null; category?: string | null }> | null;
};

function relationTemplate(row: GameSessionRow): { name: string; category: string } {
  const template = Array.isArray(row.template) ? row.template[0] : row.template;
  return {
    name: template?.name ?? row.template_id,
    category: template?.category ?? 'game',
  };
}

function mapGameSession(row: GameSessionRow): VenueGameSession {
  const template = relationTemplate(row);
  return {
    id: row.id,
    venueId: row.venue_id,
    templateId: row.template_id,
    templateName: template.name,
    templateCategory: template.category,
    status: row.status,
    scheduledStartAt: row.scheduled_start_at,
    startedAt: row.started_at,
    endedAt: row.ended_at,
    rewardFet: toNumber(row.reward_fet),
    selectedQuestionCount: toNumber(row.selected_question_count),
    currentQuestionOrdinal: row.current_question_ordinal == null ? null : toNumber(row.current_question_ordinal),
    metadata: row.metadata,
    createdAt: row.created_at,
  };
}

export async function fetchVenueGameSessions(venueId: string): Promise<VenueGameSession[]> {
  const { data, error } = await supabase
    .from('game_sessions')
    .select('*, template:game_templates(name, category)')
    .eq('venue_id', venueId)
    .order('scheduled_start_at', { ascending: false });

  if (error) throw error;
  return ((data ?? []) as unknown as GameSessionRow[]).map(mapGameSession);
}

type GameTeamRow = {
  id: string;
  session_id: string;
  venue_id: string;
  name: string;
  score_fet: number;
  invite_code: string | null;
  created_at: string;
  members?: Array<{ user_id: string }> | null;
};

function mapGameTeam(row: GameTeamRow): VenueGameTeam {
  return {
    id: row.id,
    sessionId: row.session_id,
    venueId: row.venue_id,
    name: row.name,
    scoreFet: toNumber(row.score_fet),
    inviteCode: row.invite_code,
    memberCount: row.members?.length ?? 0,
    createdAt: row.created_at,
  };
}

export async function fetchVenueGameTeams(venueId: string): Promise<VenueGameTeam[]> {
  const { data, error } = await supabase
    .from('game_teams')
    .select('*, members:game_team_members(user_id)')
    .eq('venue_id', venueId)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return ((data ?? []) as unknown as GameTeamRow[]).map(mapGameTeam);
}

export async function fetchGameSessionControl(sessionId: string): Promise<VenueGameControl> {
  const { data: sessionData, error: sessionError } = await supabase
    .from('game_sessions')
    .select('*, template:game_templates(name, category)')
    .eq('id', sessionId)
    .maybeSingle();

  if (sessionError) throw sessionError;
  if (!sessionData) throw new Error('Game session not found.');

  const session = mapGameSession(sessionData as unknown as GameSessionRow);
  const { data: teamRows, error: teamError } = await supabase
    .from('game_teams')
    .select('*, members:game_team_members(user_id)')
    .eq('session_id', sessionId)
    .order('score_fet', { ascending: false });

  if (teamError) throw teamError;

  let currentQuestion: VenueGameQuestion | null = null;
  if (session.currentQuestionOrdinal) {
    const { data: questionRows, error: questionError } = await supabase.rpc(
      'get_game_session_question',
      {
        p_session_id: sessionId,
        p_ordinal: session.currentQuestionOrdinal,
      },
    );
    if (questionError) throw questionError;
    const question = Array.isArray(questionRows) ? questionRows[0] : null;
    if (question) {
      const record = question as {
        session_id: string;
        question_id: string;
        ordinal: number;
        prompt: string;
        options: Json;
      };
      currentQuestion = {
        sessionId: record.session_id,
        questionId: record.question_id,
        ordinal: toNumber(record.ordinal),
        prompt: record.prompt,
        options: record.options,
      };
    }
  }

  return {
    session,
    teams: ((teamRows ?? []) as unknown as GameTeamRow[]).map(mapGameTeam),
    currentQuestion,
  };
}

export async function createVenueGameSession(input: {
  venueId: string;
  templateId: string;
  scheduledStartAt: string;
  rewardFet: number;
}): Promise<Json | null> {
  const { data, error } = await supabase.rpc('create_game_session', {
    p_venue_id: input.venueId,
    p_template_id: input.templateId,
    p_scheduled_start_at: input.scheduledStartAt,
    p_reward_fet: Math.max(0, Math.round(input.rewardFet)),
  });

  if (error) throw error;
  return data as Json | null;
}

export async function updateGameSessionLifecycle(
  sessionId: string,
  action: 'start' | 'pause' | 'resume' | 'next_round' | 'end',
  note?: string,
): Promise<Json | null> {
  const { data, error } = await supabase.rpc('update_game_session_lifecycle', {
    p_session_id: sessionId,
    p_action: action,
    p_note: note?.trim() || null,
  });

  if (error) throw error;
  return data as Json | null;
}

type ScreenStateRow = {
  venue_id: string;
  mode: VenueScreenMode;
  active_pool_id: string | null;
  active_game_session_id: string | null;
  payload: Json | null;
  updated_by: string | null;
  updated_at: string;
};

function mapScreenState(row: ScreenStateRow): VenueScreenState {
  return {
    venueId: row.venue_id,
    mode: row.mode,
    activePoolId: row.active_pool_id,
    activeGameSessionId: row.active_game_session_id,
    payload: row.payload,
    updatedBy: row.updated_by,
    updatedAt: row.updated_at,
  };
}

export async function fetchVenueScreenState(venueId: string): Promise<VenueScreenState | null> {
  const { data, error } = await supabase
    .from('venue_screen_states')
    .select('*')
    .eq('venue_id', venueId)
    .maybeSingle();

  if (error) throw error;
  return data ? mapScreenState(data as unknown as ScreenStateRow) : null;
}

export async function setVenueScreenState(input: {
  venueId: string;
  mode: VenueScreenMode;
  activePoolId?: string | null;
  activeGameSessionId?: string | null;
  payload?: Json | null;
}): Promise<Json | null> {
  const { data, error } = await supabase.rpc('set_venue_screen_state', {
    p_venue_id: input.venueId,
    p_mode: input.mode,
    p_active_pool_id: input.activePoolId ?? null,
    p_active_game_session_id: input.activeGameSessionId ?? null,
    p_payload: input.payload ?? {},
  });

  if (error) throw error;
  return data as Json | null;
}

export async function closeVenuePoolJoining(poolId: string, note?: string): Promise<Json | null> {
  const { data, error } = await supabase.rpc('venue_close_match_pool', {
    p_pool_id: poolId,
    p_note: note?.trim() || null,
  });

  if (error) throw error;
  return data as Json | null;
}

export async function settleVenuePool(poolId: string): Promise<Json | null> {
  const { data, error } = await supabase.rpc('venue_settle_match_pool', {
    p_pool_id: poolId,
  });

  if (error) throw error;
  return data as Json | null;
}

type MatchPoolStatsDetailRow = {
  id: string;
  match_id: string;
  title: string | null;
  status: string;
  entry_fee_fet: number;
  stake_min_fet: number;
  stake_max_fet: number;
  total_members: number;
  total_staked_fet: number;
  metadata: Json | null;
  camps: Json;
};

type MatchPoolEntryDetailRow = {
  id: string;
  pool_id: string;
  camp_id: string;
  user_id: string;
  amount_fet: number;
  status: string;
  payout_fet: number;
  created_at: string;
};

type MatchPoolSettlementDetailRow = {
  id: string;
  pool_id: string;
  status: string;
  result_camp_id: string | null;
  winners_count: number;
  total_paid_fet: number;
  payout_per_winner_fet: number;
  completed_at: string | null;
  error_message: string | null;
};

export async function fetchVenuePoolDetail(
  venueId: string,
  poolId: string,
): Promise<VenuePoolDetail> {
  const { data: poolRow, error: poolError } = await supabase
    .from('match_pool_stats')
    .select('*')
    .eq('venue_id', venueId)
    .eq('id', poolId)
    .maybeSingle();

  if (poolError) throw poolError;
  if (!poolRow) throw new Error('Prediction pool not found for this venue.');

  const pool = poolRow as MatchPoolStatsDetailRow;
  const [
    { data: matchRows, error: matchError },
    { data: entryRows, error: entryError },
    { data: settlementRow, error: settlementError },
  ] = await Promise.all([
    supabase
      .from('app_matches')
      .select('competition_name, match_date, home_team, away_team')
      .eq('id', pool.match_id)
      .limit(1),
    supabase
      .from('match_pool_entries')
      .select('*')
      .eq('pool_id', poolId)
      .order('created_at', { ascending: false }),
    supabase
      .from('match_pool_settlements')
      .select('*')
      .eq('pool_id', poolId)
      .maybeSingle(),
  ]);

  if (matchError) throw matchError;
  if (entryError) throw entryError;
  if (settlementError) throw settlementError;

  const matchRecord = (matchRows?.[0] ?? null) as {
    competition_name?: string | null;
    match_date?: string | null;
    home_team?: string | null;
    away_team?: string | null;
  } | null;
  const metadata = asRecord(pool.metadata);
  const camps = asArray(pool.camps).map((item) => {
    const camp = asRecord(item);
    return {
      id: String(camp.id ?? ''),
      label: String(camp.label ?? 'Camp'),
      resultCode: stringOrNull(camp.result_code),
      memberCount: toNumber(camp.member_count),
      totalStakedFet: toNumber(camp.total_staked_fet),
      isWinningCamp: camp.is_winning_camp === true,
    };
  });
  const settlement = settlementRow as unknown as MatchPoolSettlementDetailRow | null;

  return {
    pool: {
      id: pool.id,
      matchId: pool.match_id,
      matchLabel:
        matchRecord?.home_team && matchRecord?.away_team
          ? `${matchRecord.home_team} vs ${matchRecord.away_team}`
          : pool.title ?? 'Prediction pool',
      competitionName: matchRecord?.competition_name ?? null,
      status: pool.status,
      title: pool.title,
      kickoffAt: matchRecord?.match_date ?? null,
      entryFeeFet: toNumber(pool.entry_fee_fet),
      stakeMinFet: toNumber(pool.stake_min_fet),
      stakeMaxFet: toNumber(pool.stake_max_fet),
      totalMembers: toNumber(pool.total_members),
      totalStakedFet: toNumber(pool.total_staked_fet),
      barStakeFet: toNumber(metadata.bar_stake_fet),
      camps,
    },
    entries: ((entryRows ?? []) as MatchPoolEntryDetailRow[]).map((row) => ({
      id: row.id,
      poolId: row.pool_id,
      campId: row.camp_id,
      userId: row.user_id,
      amountFet: toNumber(row.amount_fet),
      status: row.status,
      payoutFet: toNumber(row.payout_fet),
      createdAt: row.created_at,
    })),
    settlement: settlement
      ? {
          id: settlement.id,
          poolId: settlement.pool_id,
          status: settlement.status,
          resultCampId: settlement.result_camp_id,
          winnersCount: toNumber(settlement.winners_count),
          totalPaidFet: toNumber(settlement.total_paid_fet),
          payoutPerWinnerFet: toNumber(settlement.payout_per_winner_fet),
          completedAt: settlement.completed_at,
          errorMessage: settlement.error_message,
        }
      : null,
  };
}

export async function fetchVenueOperationalInsights(venueId: string): Promise<VenueOperationalInsights> {
  const { data, error } = await supabase.rpc('get_venue_operational_insights', {
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
