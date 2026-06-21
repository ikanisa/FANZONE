import { useCallback, useEffect, useState } from "react";
import { supabase } from "../lib/supabase";
import {
  closeVenueChatThread,
  fetchVenueChatThreads,
  sendVenueChatMessage,
  type VenueChatThread,
} from "../services/venueChatOperations";

export function useVenueChatThreads(venueId: string) {
  const [threads, setThreads] = useState<VenueChatThread[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    if (!venueId) {
      setThreads([]);
      return;
    }

    setLoading(true);
    setError(null);
    try {
      setThreads(await fetchVenueChatThreads(venueId));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to fetch chat threads.");
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
      .channel(`venue-chat-${venueId}-${Date.now()}-${Math.random().toString(16).slice(2)}`)
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "venue_chat_threads",
          filter: `venue_id=eq.${venueId}`,
        },
        () => refresh(),
      )
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "venue_chat_messages",
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

  const sendMessage = async (threadId: string, body: string) => {
    await sendVenueChatMessage(threadId, body);
    await refresh();
  };

  const closeThread = async (threadId: string, resolutionNotes: string) => {
    await closeVenueChatThread(threadId, "resolved", resolutionNotes);
    await refresh();
  };

  return {
    threads: venueId ? threads : [],
    loading: venueId ? loading : false,
    error: venueId ? error : null,
    refresh,
    sendMessage,
    closeThread,
  };
}
