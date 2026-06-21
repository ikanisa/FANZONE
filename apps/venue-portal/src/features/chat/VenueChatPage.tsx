import { useMemo, useState } from "react";
import {
  CheckCircle2,
  MessageCircle,
  RefreshCcw,
  Send,
} from "lucide-react";
import { EmptyState } from "../../components/console/EmptyState";
import { StatusChip } from "../../components/console/StatusChip";
import { useVenue } from "../../hooks/useVenueContext";
import { useVenueChatThreads } from "../../hooks/useVenueChatThreads";
import type { VenueChatThread } from "../../services/venueChatOperations";

function formatTime(value: string) {
  return new Intl.DateTimeFormat(undefined, {
    hour: "2-digit",
    minute: "2-digit",
    month: "short",
    day: "numeric",
  }).format(new Date(value));
}

function threadTitle(thread: VenueChatThread) {
  return thread.subject?.trim() || `${thread.topic.replace(/_/g, " ")} chat`;
}

export function VenueChatPage() {
  const { venue } = useVenue();
  const venueId = venue?.id ?? "";
  const { threads, loading, error, refresh, sendMessage, closeThread } =
    useVenueChatThreads(venueId);
  const [selectedThreadId, setSelectedThreadId] = useState<string | null>(null);
  const [reply, setReply] = useState("");
  const [resolutionNotes, setResolutionNotes] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const selectedThread = useMemo(
    () =>
      threads.find((thread) => thread.id === selectedThreadId) ??
      threads[0] ??
      null,
    [selectedThreadId, threads],
  );
  const openThreads = threads.filter((thread) =>
    ["open", "in_review"].includes(thread.status),
  ).length;

  const handleSend = async () => {
    if (!selectedThread || !reply.trim()) return;
    setSubmitting(true);
    try {
      await sendMessage(selectedThread.id, reply.trim());
      setReply("");
    } finally {
      setSubmitting(false);
    }
  };

  const handleClose = async () => {
    if (!selectedThread || !resolutionNotes.trim()) return;
    setSubmitting(true);
    try {
      await closeThread(selectedThread.id, resolutionNotes.trim());
      setResolutionNotes("");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <section className="space-y-6">
      <div className="flex flex-col gap-4 xl:flex-row xl:items-end xl:justify-between">
        <div>
          <p className="text-xs font-black uppercase tracking-wide text-textSecondary">
            Customer support
          </p>
          <h1 className="mt-2 text-3xl font-black tracking-tight text-text">
            Venue chat
          </h1>
          <p className="mt-2 max-w-2xl text-sm font-medium leading-6 text-textSecondary">
            Customer messages are scoped to this venue and written through audited server checks.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <StatusChip
            status={openThreads ? "warning" : "open"}
            label={`${openThreads} active`}
          />
          <button type="button" className="btn btn-secondary" onClick={refresh}>
            <RefreshCcw size={18} />
            Refresh
          </button>
        </div>
      </div>

      {error && (
        <div className="rounded-2xl border border-danger/30 bg-danger/10 px-4 py-3 text-sm font-black text-danger">
          {error}
        </div>
      )}

      {threads.length === 0 && !loading ? (
        <EmptyState
          icon={<MessageCircle size={28} />}
          title="No customer chats"
          message="New customer conversations will appear here when guests contact the venue from the mobile app."
        />
      ) : (
        <div className="grid min-h-[620px] gap-4 xl:grid-cols-[360px_1fr]">
          <aside className="rounded-2xl border border-border bg-surface p-3">
            <div className="mb-3 flex items-center justify-between px-2">
              <h2 className="text-sm font-black uppercase tracking-wide text-textSecondary">
                Inbox
              </h2>
              {loading && (
                <span className="text-xs font-black text-textSecondary">
                  Syncing
                </span>
              )}
            </div>
            <div className="space-y-2">
              {threads.map((thread) => {
                const active = selectedThread?.id === thread.id;
                const lastMessage = thread.messages.at(-1);
                return (
                  <button
                    key={thread.id}
                    type="button"
                    onClick={() => setSelectedThreadId(thread.id)}
                    className={`w-full rounded-2xl border p-4 text-left transition ${
                      active
                        ? "border-primary bg-primary/10"
                        : "border-border bg-surface2 hover:bg-surface3"
                    }`}
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div className="min-w-0">
                        <p className="truncate text-sm font-black capitalize text-text">
                          {threadTitle(thread)}
                        </p>
                        <p className="mt-1 text-xs font-bold uppercase tracking-wide text-textSecondary">
                          {thread.topic} · {formatTime(thread.lastMessageAt)}
                        </p>
                      </div>
                      <StatusChip status={thread.status} label={thread.status} />
                    </div>
                    <p className="mt-3 line-clamp-2 text-sm font-medium leading-5 text-textSecondary">
                      {lastMessage?.body ?? "No messages yet."}
                    </p>
                  </button>
                );
              })}
            </div>
          </aside>

          <article className="flex min-h-[620px] flex-col rounded-2xl border border-border bg-surface">
            {selectedThread ? (
              <>
                <header className="border-b border-border p-5">
                  <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
                    <div>
                      <h2 className="text-xl font-black text-text">
                        {threadTitle(selectedThread)}
                      </h2>
                      <p className="mt-1 text-sm font-medium text-textSecondary">
                        Customer {selectedThread.customerUserId.slice(0, 8)}
                        {selectedThread.orderId
                          ? ` · Order ${selectedThread.orderId.slice(0, 8)}`
                          : ""}
                      </p>
                    </div>
                    <StatusChip
                      status={selectedThread.status}
                      label={selectedThread.status}
                    />
                  </div>
                </header>

                <div className="flex-1 space-y-3 overflow-y-auto p-5">
                  {selectedThread.messages.map((message) => {
                    const staffMessage = ["venue_staff", "admin"].includes(
                      message.senderRole,
                    );
                    const systemMessage = message.messageType === "system";
                    return (
                      <div
                        key={message.id}
                        className={`flex ${
                          staffMessage ? "justify-end" : "justify-start"
                        }`}
                      >
                        <div
                          className={`max-w-[78%] rounded-2xl border px-4 py-3 ${
                            systemMessage
                              ? "border-border bg-surface2 text-textSecondary"
                              : staffMessage
                                ? "border-primary/30 bg-primary/10 text-text"
                                : "border-border bg-surface2 text-text"
                          }`}
                        >
                          <p className="text-xs font-black uppercase tracking-wide text-textSecondary">
                            {message.senderRole.replace(/_/g, " ")} ·{" "}
                            {formatTime(message.createdAt)}
                          </p>
                          <p className="mt-2 whitespace-pre-wrap text-sm font-medium leading-6">
                            {message.body}
                          </p>
                        </div>
                      </div>
                    );
                  })}
                </div>

                {["open", "in_review"].includes(selectedThread.status) ? (
                  <footer className="space-y-4 border-t border-border p-5">
                    <div className="flex flex-col gap-3 lg:flex-row">
                      <textarea
                        value={reply}
                        onChange={(event) => setReply(event.target.value)}
                        rows={3}
                        maxLength={2000}
                        className="min-h-24 flex-1 rounded-2xl border border-border bg-surface2 px-4 py-3 text-sm font-medium text-text outline-none focus:border-primary"
                        placeholder="Reply to the customer"
                      />
                      <button
                        type="button"
                        className="btn btn-primary self-stretch lg:self-auto"
                        disabled={submitting || !reply.trim()}
                        onClick={handleSend}
                      >
                        <Send size={18} />
                        Send
                      </button>
                    </div>
                    <div className="flex flex-col gap-3 lg:flex-row">
                      <input
                        value={resolutionNotes}
                        onChange={(event) =>
                          setResolutionNotes(event.target.value)
                        }
                        className="min-h-12 flex-1 rounded-2xl border border-border bg-surface2 px-4 text-sm font-medium text-text outline-none focus:border-primary"
                        placeholder="Resolution note"
                      />
                      <button
                        type="button"
                        className="btn btn-secondary"
                        disabled={submitting || !resolutionNotes.trim()}
                        onClick={handleClose}
                      >
                        <CheckCircle2 size={18} />
                        Resolve
                      </button>
                    </div>
                  </footer>
                ) : (
                  <footer className="border-t border-border p-5 text-sm font-black text-textSecondary">
                    This chat is closed.
                  </footer>
                )}
              </>
            ) : (
              <EmptyState
                icon={<MessageCircle size={28} />}
                title="Select a chat"
                message="Choose a customer conversation to review messages and reply."
              />
            )}
          </article>
        </div>
      )}
    </section>
  );
}
