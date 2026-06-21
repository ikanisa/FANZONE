import type {
  VenueChatMessageRow,
  VenueChatStatus,
  VenueChatThreadRow,
  VenueChatTopic,
} from "@fanzone/core";
import { supabase } from "../lib/supabase";

export interface VenueChatMessage {
  id: string;
  threadId: string;
  venueId: string;
  senderUserId: string | null;
  senderRole: VenueChatMessageRow["sender_role"];
  body: string;
  messageType: VenueChatMessageRow["message_type"];
  moderationStatus: VenueChatMessageRow["moderation_status"];
  createdAt: string;
}

export interface VenueChatThread {
  id: string;
  venueId: string;
  customerUserId: string;
  orderId: string | null;
  supportRequestId: string | null;
  topic: VenueChatTopic;
  subject: string | null;
  status: VenueChatStatus;
  assignedTo: string | null;
  resolutionNotes: string | null;
  lastMessageAt: string;
  closedAt: string | null;
  closedBy: string | null;
  createdAt: string;
  updatedAt: string;
  messages: VenueChatMessage[];
}

type ChatRpcPayload = {
  thread?: VenueChatThreadRow;
  message?: VenueChatMessageRow;
};

function mapMessage(row: VenueChatMessageRow): VenueChatMessage {
  return {
    id: row.id,
    threadId: row.thread_id,
    venueId: row.venue_id,
    senderUserId: row.sender_user_id,
    senderRole: row.sender_role,
    body: row.body,
    messageType: row.message_type,
    moderationStatus: row.moderation_status,
    createdAt: row.created_at,
  };
}

function mapThread(
  row: VenueChatThreadRow,
  messages: VenueChatMessage[],
): VenueChatThread {
  return {
    id: row.id,
    venueId: row.venue_id,
    customerUserId: row.customer_user_id,
    orderId: row.order_id,
    supportRequestId: row.support_request_id,
    topic: row.topic,
    subject: row.subject,
    status: row.status,
    assignedTo: row.assigned_to,
    resolutionNotes: row.resolution_notes,
    lastMessageAt: row.last_message_at,
    closedAt: row.closed_at,
    closedBy: row.closed_by,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    messages,
  };
}

export async function fetchVenueChatThreads(
  venueId: string,
): Promise<VenueChatThread[]> {
  const { data: threads, error: threadError } = await supabase
    .from("venue_chat_threads")
    .select("*")
    .eq("venue_id", venueId)
    .order("last_message_at", { ascending: false })
    .limit(50);

  if (threadError) throw threadError;

  const threadRows = (threads ?? []) as VenueChatThreadRow[];
  if (threadRows.length === 0) return [];

  const threadIds = threadRows.map((thread) => thread.id);
  const { data: messages, error: messageError } = await supabase
    .from("venue_chat_messages")
    .select("*")
    .eq("venue_id", venueId)
    .in("thread_id", threadIds)
    .order("created_at", { ascending: true });

  if (messageError) throw messageError;

  const messagesByThread = new Map<string, VenueChatMessage[]>();
  for (const row of (messages ?? []) as VenueChatMessageRow[]) {
    const mapped = mapMessage(row);
    const list = messagesByThread.get(mapped.threadId) ?? [];
    list.push(mapped);
    messagesByThread.set(mapped.threadId, list);
  }

  return threadRows.map((thread) =>
    mapThread(thread, messagesByThread.get(thread.id) ?? []),
  );
}

export async function sendVenueChatMessage(
  threadId: string,
  body: string,
): Promise<ChatRpcPayload> {
  const { data, error } = await supabase.rpc("send_venue_chat_message", {
    p_thread_id: threadId,
    p_body: body,
  });

  if (error) throw error;
  return (data ?? {}) as ChatRpcPayload;
}

export async function closeVenueChatThread(
  threadId: string,
  status: Extract<VenueChatStatus, "resolved" | "closed" | "cancelled">,
  resolutionNotes: string,
): Promise<VenueChatThreadRow> {
  const { data, error } = await supabase.rpc("close_venue_chat_thread", {
    p_thread_id: threadId,
    p_status: status,
    p_resolution_notes: resolutionNotes,
  });

  if (error) throw error;
  return data as VenueChatThreadRow;
}
