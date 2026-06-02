import { useState, type ReactNode } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import {
  Wallet,
  ArrowUpRight,
  ArrowDownLeft,
  X,
  Receipt,
  ShieldCheck,
} from 'lucide-react';
import { useAppStore } from '../store/useAppStore';
import type { WalletTransaction } from '../store/useAppStore';
import { FETDisplay } from './ui/FETDisplay';
import type { ViewerState } from '../services/api';

export default function WalletHub() {
  const { fetBalance, walletTransactions, hydrateViewerState } = useAppStore();
  const [selectedTx, setSelectedTx] = useState<WalletTransaction | null>(null);

  const earned = walletTransactions
    .filter((tx) => tx.type === 'earn' || tx.type === 'reward_credit')
    .reduce((sum, tx) => sum + tx.amount, 0);
  const spent = walletTransactions
    .filter((tx) => tx.type === 'spend' || tx.type === 'reward_debit')
    .reduce((sum, tx) => sum + tx.amount, 0);

  const applyViewerState = (viewerState: ViewerState | null) => {
    if (!viewerState) return;

    hydrateViewerState({
      fanId: viewerState.profile?.fanId,
      isVerified: viewerState.profile ? !viewerState.profile.isAnonymous : undefined,
      fetBalance: viewerState.wallet?.availableBalanceFet,
      walletTransactions: viewerState.walletTransactions,
      notifications: viewerState.notifications.map((notification) => ({
        id: notification.id,
        type:
          notification.type === 'pool_reward' ||
          notification.type === 'pool_update'
            ? notification.type
            : 'system',
        title: notification.title,
        message: notification.message,
        timestamp: notification.timestamp,
        read: notification.read,
      })),
    });
  };

  return (
    <div className="min-h-screen bg-bg transition-colors duration-300">
      <header className="pt-6 lg:hidden pb-2 px-5 flex items-center justify-between">
        <h1 className="font-display text-4xl text-text tracking-tight flex items-center gap-2">
          <Wallet size={24} className="text-accent" /> Rewards
        </h1>
      </header>

      <div className="p-4 lg:p-12 pb-24 lg:pt-8 space-y-6">
        <div className="bg-gradient-to-br from-[#0F7B6C] to-[#2563EB] rounded-[28px] p-5 text-[#FDFCF0] relative overflow-hidden shadow-[0_10px_30px_-10px_rgba(37,99,235,0.3)]">
          <div className="relative z-10 flex flex-col items-center text-center">
            <div className="text-[10px] font-bold opacity-80 uppercase tracking-widest mb-1 select-none">
              Reward Points
            </div>
            <div className="text-5xl lg:text-6xl font-mono font-bold tracking-tight mb-5 [text-shadow:0_0_20px_rgba(253,252,240,0.3)] flex flex-col items-center justify-center min-h-20">
              <FETDisplay
                amount={fetBalance}
                showFiat={true}
                fiatClassName="opacity-80 text-sm font-sans block mt-1 tracking-normal leading-none"
              />
            </div>
            <div className="bg-[#FDFCF0]/10 border border-[#FDFCF0]/20 rounded-2xl px-4 py-3 text-xs font-bold leading-5 text-[#FDFCF0]">
              FET is a closed-loop rewards ledger for venue rewards, games, and coupons.
            </div>
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
            <h3 className="font-bold text-sm text-text mb-1">Rewards Ledger</h3>
            <p className="text-sm text-muted leading-relaxed">
              FET activity focuses on venue-order rewards, coupon redemptions, game rewards, and audited challenge settlements.
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
    transaction.type === 'earn' || transaction.type === 'reward_credit';

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
                  value={`${transaction.type === 'earn' || transaction.type === 'reward_credit' ? '+' : '-'}${transaction.amount} FET`}
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
