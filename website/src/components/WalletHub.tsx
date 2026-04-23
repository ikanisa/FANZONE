import { useState, type ReactNode } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import {
  Wallet,
  ArrowUpRight,
  ArrowDownLeft,
  Send,
  X,
  CheckSquare,
  Receipt,
  ShieldCheck,
} from 'lucide-react';
import { useAppStore } from '../store/useAppStore';
import type { WalletTransaction } from '../store/useAppStore';
import { FETDisplay } from './ui/FETDisplay';
import { api, type ViewerState } from '../services/api';

export default function WalletHub() {
  const { fetBalance, walletTransactions, hydrateViewerState } = useAppStore();
  const [showTransferSheet, setShowTransferSheet] = useState(false);
  const [selectedTx, setSelectedTx] = useState<WalletTransaction | null>(null);

  const earned = walletTransactions
    .filter((tx) => tx.type === 'earn' || tx.type === 'transfer_received')
    .reduce((sum, tx) => sum + tx.amount, 0);
  const spent = walletTransactions
    .filter((tx) => tx.type === 'spend' || tx.type === 'transfer_sent')
    .reduce((sum, tx) => sum + tx.amount, 0);

  const applyViewerState = (viewerState: ViewerState | null) => {
    if (!viewerState) return;

    hydrateViewerState({
      fanId: viewerState.profile?.fanId,
      isVerified: viewerState.profile ? !viewerState.profile.isAnonymous : undefined,
      favoriteTeams: viewerState.favoriteTeams,
      profileTeam: viewerState.profile?.favoriteTeamName ?? viewerState.favoriteTeams[0] ?? null,
      fetBalance: viewerState.wallet?.availableBalanceFet,
      walletTransactions: viewerState.walletTransactions,
      notifications: viewerState.notifications.map((notification) => ({
        id: notification.id,
        type:
          notification.type === 'prediction_reward' ||
          notification.type === 'prediction_update' ||
          notification.type === 'transfer'
            ? notification.type
            : 'system',
        title: notification.title,
        message: notification.message,
        timestamp: notification.timestamp,
        read: notification.read,
      })),
    });
  };

  const handleTransfer = async (recipient: string, amount: number) => {
    const result = await api.transferFetByFanId(recipient, amount);
    if (result.success && result.viewerState) {
      applyViewerState(result.viewerState);
    }

    return {
      success: result.success,
      error: result.error,
    };
  };

  return (
    <div className="min-h-screen bg-bg transition-colors duration-300">
      <header className="pt-6 lg:hidden pb-2 px-5 flex items-center justify-between">
        <h1 className="font-display text-4xl text-text tracking-tight flex items-center gap-2">
          <Wallet size={24} className="text-accent" /> Wallet
        </h1>
      </header>

      <div className="p-4 lg:p-12 pb-24 lg:pt-8 space-y-6">
        <div className="bg-gradient-to-br from-[#0F7B6C] to-[#2563EB] rounded-[28px] p-5 text-[#FDFCF0] relative overflow-hidden shadow-[0_10px_30px_-10px_rgba(37,99,235,0.3)]">
          <div className="relative z-10 flex flex-col items-center text-center">
            <div className="text-[10px] font-bold opacity-80 uppercase tracking-widest mb-1 select-none">
              Total Balance
            </div>
            <div className="text-5xl lg:text-6xl font-mono font-bold tracking-tight mb-5 [text-shadow:0_0_20px_rgba(253,252,240,0.3)] flex flex-col items-center justify-center min-h-20">
              <FETDisplay
                amount={fetBalance}
                showFiat={true}
                fiatClassName="opacity-80 text-sm font-sans block mt-1 tracking-normal leading-none"
              />
            </div>
            <button
              onClick={() => setShowTransferSheet(true)}
              className="bg-[#FDFCF0] text-[#09090b] h-12 px-5 rounded-xl font-bold flex items-center justify-center gap-2 hover:scale-[1.02] transition-transform shadow-sm"
            >
              <Send size={14} className="text-accent" />
              <span className="text-[10px] tracking-widest">SEND FET</span>
            </button>
          </div>
          <Wallet
            className="absolute -bottom-6 -right-6 text-white/5 mix-blend-overlay rotate-[-15deg] pointer-events-none"
            size={200}
          />
        </div>

        <div className="grid grid-cols-2 gap-2">
          <MetricCard
            label="Earned"
            amount={earned}
            positive={true}
            icon={<ArrowUpRight size={14} />}
          />
          <MetricCard
            label="Spent"
            amount={spent}
            positive={false}
            icon={<ArrowDownLeft size={14} />}
          />
        </div>

        <section className="bg-surface2 rounded-[20px] border border-border p-4 flex items-start gap-3 shadow-sm">
          <div className="w-10 h-10 rounded-full bg-success/10 text-success border border-success/20 flex items-center justify-center shrink-0">
            <ShieldCheck size={18} />
          </div>
          <div>
            <h3 className="font-bold text-sm text-text mb-1">Lean Wallet Flow</h3>
            <p className="text-sm text-muted leading-relaxed">
              Wallet activity now focuses on transfers and lean prediction rewards.
              The old marketplace and club-split logic is no longer part of the retained product flow.
            </p>
          </div>
        </section>

        <section>
          <div className="flex items-center gap-2 mb-2 px-1">
            <ArrowDownLeft size={14} className="text-muted" />
            <h3 className="font-sans font-bold text-sm text-text">History</h3>
          </div>
          <div className="bg-surface2 rounded-[20px] border border-border shadow-sm flex flex-col overflow-hidden divide-y divide-border/50">
            {walletTransactions.map((tx) => (
              <div key={tx.id} onClick={() => setSelectedTx(tx)}>
                <TransactionItem transaction={tx} />
              </div>
            ))}
            {walletTransactions.length === 0 && (
              <div className="text-[10px] uppercase tracking-widest text-muted text-center py-6 font-bold">
                No history available
              </div>
            )}
          </div>
        </section>
      </div>

      <TransferSheet
        isOpen={showTransferSheet}
        onClose={() => setShowTransferSheet(false)}
        balance={fetBalance}
        onTransfer={handleTransfer}
      />

      <TransactionReceiptModal
        transaction={selectedTx}
        onClose={() => setSelectedTx(null)}
      />
    </div>
  );
}

function MetricCard({
  label,
  amount,
  positive,
  icon,
}: {
  label: string;
  amount: number;
  positive: boolean;
  icon: ReactNode;
}) {
  return (
    <div className="bg-surface2 p-3 rounded-[20px] border border-border shadow-sm flex items-center justify-between">
      <div className="flex-1">
        <div className="text-muted text-[9px] uppercase tracking-widest font-bold mb-0.5 opacity-80">
          {label}
        </div>
        <div
          className={`font-mono text-base font-bold leading-none ${
            positive ? 'text-success' : 'text-accent3'
          }`}
        >
          {positive ? '+' : '-'}
          <FETDisplay amount={amount} showFiat={false} className="inline ml-0.5" />
        </div>
      </div>
      <div
        className={`w-8 h-8 rounded-full flex items-center justify-center shrink-0 border ${
          positive
            ? 'bg-success/10 text-success border-success/20'
            : 'bg-accent3/10 text-accent3 border-accent3/20'
        }`}
      >
        {icon}
      </div>
    </div>
  );
}

function TransactionItem({ transaction }: { transaction: WalletTransaction }) {
  const isPositive =
    transaction.type === 'earn' || transaction.type === 'transfer_received';

  return (
    <div className="p-2 bg-surface hover:bg-surface2 flex items-center justify-between transition-colors gap-3">
      <div className="flex items-center gap-2 overflow-hidden">
        <div
          className={`w-6 h-6 rounded-full flex justify-center items-center shrink-0 border ${
            isPositive
              ? 'bg-success/10 text-success border-success/20'
              : 'bg-accent3/10 text-accent3 border-accent3/20'
          }`}
        >
          {isPositive ? <ArrowUpRight size={10} /> : <ArrowDownLeft size={10} />}
        </div>
        <div className="truncate">
          <div className="text-[10px] font-bold text-text leading-tight truncate">
            {transaction.title}
          </div>
          <div className="text-[8px] font-bold uppercase tracking-widest text-muted truncate">
            {transaction.dateStr}
          </div>
        </div>
      </div>
      <div
        className={`shrink-0 font-mono text-[10px] font-bold leading-none ${
          isPositive ? 'text-success' : 'text-accent3'
        }`}
      >
        {isPositive ? '+' : '-'}
        <FETDisplay amount={transaction.amount} showFiat={false} className="inline ml-0.5" />
      </div>
    </div>
  );
}

function TransferSheet({
  isOpen,
  onClose,
  balance,
  onTransfer,
}: {
  isOpen: boolean;
  onClose: () => void;
  balance: number;
  onTransfer: (
    recipient: string,
    amount: number,
  ) => Promise<{ success: boolean; error?: string }>;
}) {
  const [recipient, setRecipient] = useState('');
  const [amount, setAmount] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const numAmount = parseInt(amount, 10) || 0;
  const cleanRecipient = recipient.replace(/\D/g, '');
  const isValid = cleanRecipient.length === 6 && numAmount > 0 && numAmount <= balance;

  const handleTransfer = async () => {
    setError('');
    setIsSubmitting(true);
    const result = await onTransfer(cleanRecipient, numAmount);
    setIsSubmitting(false);
    if (!result.success) {
      setError(result.error || 'Transfer failed');
      return;
    }
    setSuccess(true);
    window.setTimeout(() => {
      setSuccess(false);
      setRecipient('');
      setAmount('');
      onClose();
    }, 1800);
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 bg-bg/90 backdrop-blur-md z-50"
          />
          <motion.div
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            className="fixed bottom-0 left-0 right-0 bg-surface rounded-t-[2rem] border-t border-border z-50 p-6 pb-safe"
          >
            <div className="w-12 h-1.5 bg-surface3 rounded-full mx-auto mb-8" />

            {success ? (
              <div className="text-center py-8">
                <div className="w-20 h-20 bg-accent/20 text-accent rounded-full flex items-center justify-center mx-auto mb-6">
                  <Send size={40} className="translate-x-1" />
                </div>
                <p className="font-display text-3xl text-text tracking-wider mb-2">
                  Transfer Sent
                </p>
                <p className="text-sm text-muted">Your wallet balance has been updated.</p>
              </div>
            ) : (
              <>
                <div className="flex items-center justify-between mb-5">
                  <div>
                    <p className="text-[10px] font-bold tracking-widest uppercase text-muted mb-1">
                      Wallet Transfer
                    </p>
                    <h3 className="font-display text-3xl text-text tracking-widest">
                      Send FET
                    </h3>
                  </div>
                  <button
                    onClick={onClose}
                    className="w-10 h-10 rounded-full bg-surface3 border border-border flex items-center justify-center text-muted hover:text-text"
                  >
                    <X size={18} />
                  </button>
                </div>

                <div className="space-y-4">
                  <div>
                    <label className="text-[10px] font-bold tracking-widest uppercase text-muted mb-2 block">
                      Recipient Fan ID
                    </label>
                    <input
                      value={recipient}
                      onChange={(event) => setRecipient(event.target.value)}
                      className="w-full bg-surface3 border border-border rounded-2xl px-4 py-4 text-text placeholder:text-muted outline-none focus:border-accent transition-colors"
                      placeholder="Enter 6-digit Fan ID"
                      inputMode="numeric"
                    />
                  </div>

                  <div>
                    <label className="text-[10px] font-bold tracking-widest uppercase text-muted mb-2 block">
                      Amount
                    </label>
                    <input
                      value={amount}
                      onChange={(event) => setAmount(event.target.value)}
                      className="w-full bg-surface3 border border-border rounded-2xl px-4 py-4 text-text placeholder:text-muted outline-none focus:border-accent transition-colors"
                      placeholder="Enter FET amount"
                      inputMode="numeric"
                    />
                  </div>

                  <div className="bg-surface3 border border-border rounded-2xl p-4">
                    <div className="flex justify-between items-center">
                      <span className="text-[10px] font-bold tracking-widest uppercase text-muted">
                        Available Balance
                      </span>
                      <span className="font-mono text-sm text-text">{balance} FET</span>
                    </div>
                  </div>

                  {error && <p className="text-sm text-danger">{error}</p>}

                  <button
                    onClick={handleTransfer}
                    disabled={!isValid || isSubmitting}
                    className="w-full bg-accent text-bg font-bold py-4 rounded-2xl transition-all disabled:opacity-40 disabled:cursor-not-allowed"
                  >
                    {isSubmitting ? 'Sending...' : 'Send Now'}
                  </button>
                </div>
              </>
            )}
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}

function TransactionReceiptModal({
  transaction,
  onClose,
}: {
  transaction: WalletTransaction | null;
  onClose: () => void;
}) {
  return (
    <AnimatePresence>
      {transaction && (
        <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-bg/90 backdrop-blur-md z-50"
            onClick={onClose}
          />
          <motion.div
            initial={{ opacity: 0, scale: 0.96, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.96, y: 20 }}
            className="fixed inset-0 z-50 flex items-center justify-center p-6"
          >
            <div className="w-full max-w-md bg-surface2 border border-border rounded-[28px] p-6 shadow-2xl">
              <div className="flex items-center justify-between mb-5">
                <div className="flex items-center gap-3">
                  <div className="w-11 h-11 rounded-full bg-surface3 border border-border flex items-center justify-center text-muted">
                    <Receipt size={22} />
                  </div>
                  <div>
                    <p className="text-[10px] font-bold tracking-widest uppercase text-muted">
                      Transaction Receipt
                    </p>
                    <h3 className="font-display text-2xl text-text tracking-widest">
                      {transaction.title}
                    </h3>
                  </div>
                </div>
                <button
                  onClick={onClose}
                  className="w-10 h-10 rounded-full bg-surface3 border border-border flex items-center justify-center text-muted hover:text-text"
                >
                  <X size={18} />
                </button>
              </div>

              <div className="space-y-3 text-sm">
                <ReceiptRow label="Transaction ID" value={transaction.id} mono />
                <ReceiptRow label="Date" value={transaction.dateStr} />
                <ReceiptRow
                  label="Amount"
                  value={`${transaction.type === 'earn' || transaction.type === 'transfer_received' ? '+' : '-'}${transaction.amount} FET`}
                  mono
                />
                <ReceiptRow label="Type" value={transaction.type.replace('_', ' ')} />
                <div className="flex items-center justify-between pt-3 border-t border-border">
                  <span className="text-muted">Status</span>
                  <span className="text-success font-bold flex items-center gap-1">
                    <CheckSquare size={12} /> Completed
                  </span>
                </div>
              </div>

              <button
                onClick={onClose}
                className="w-full mt-6 bg-surface3 hover:bg-surface border border-border text-text font-bold py-3 rounded-2xl transition-colors"
              >
                Close Receipt
              </button>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}

function ReceiptRow({
  label,
  value,
  mono = false,
}: {
  label: string;
  value: string;
  mono?: boolean;
}) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-muted">{label}</span>
      <span className={mono ? 'font-mono text-text text-right' : 'text-text text-right'}>
        {value}
      </span>
    </div>
  );
}
