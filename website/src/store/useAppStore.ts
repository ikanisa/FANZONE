import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { type ScorePool, type PoolEntry } from '../types';
import { mockScorePools, mockPoolEntries } from '../lib/mockData';

export interface Prediction {
  id: string;
  matchId: string;
  matchName: string;
  market: string;
  selection: string;
  potentialEarn: number;
}

export interface AppNotification {
  id: string;
  type: 'pool_received' | 'pool_settled' | 'system' | 'transfer';
  title: string;
  message: string;
  timestamp: number;
  read: boolean;
}

export interface WalletTransaction {
  id: string;
  title: string;
  amount: number;
  type: 'earn' | 'spend' | 'transfer_sent' | 'transfer_received';
  timestamp: number;
  dateStr: string;
}

interface AppState {
  // Theme State
  theme: 'light' | 'dark';
  toggleTheme: () => void;

  // Auth & Identity State
  isVerified: boolean;
  fanId: string;
  showAuthGate: boolean;
  hasSeenSplash: boolean;
  hasCompletedOnboarding: boolean;
  favoriteTeams: string[];
  profileTeam: string | null;
  openAuthGate: () => void;
  closeAuthGate: () => void;
  verifyPhone: () => void;
  setHasSeenSplash: () => void;
  completeOnboarding: () => void;
  addFavoriteTeam: (team: string) => void;
  setProfileTeam: (team: string | null) => void;

  // User State
  fetBalance: number;
  walletTransactions: WalletTransaction[];
  addFet: (amount: number) => void;
  deductFet: (amount: number) => void;
  transferFET: (recipient: string, amount: number) => { success: boolean; error?: string };

  // Prediction Slip State
  slip: Prediction[];
  isSlipOpen: boolean;
  toggleSlip: () => void;
  openSlip: () => void;
  closeSlip: () => void;
  addPrediction: (prediction: Prediction) => void;
  removePrediction: (id: string) => void;
  clearSlip: () => void;

  // Notifications State
  notifications: AppNotification[];
  unreadCount: number;
  addNotification: (notification: Omit<AppNotification, 'id' | 'timestamp' | 'read'>) => void;
  markAsRead: (id: string) => void;
  markAllAsRead: () => void;

  // Pools State
  scorePools: ScorePool[];
  poolEntries: PoolEntry[];
  createPool: (pool: ScorePool, entry: PoolEntry) => void;
  joinPool: (entry: PoolEntry) => void;
}

export const useAppStore = create<AppState>()(
  persist(
    (set, get) => ({
      // Theme State
      theme: 'light',
      toggleTheme: () => set((state) => ({ theme: state.theme === 'light' ? 'dark' : 'light' })),

      // Initial Auth State
      isVerified: false,
      fanId: '#483 291',
      showAuthGate: false,
      hasSeenSplash: false,
      hasCompletedOnboarding: false,
      favoriteTeams: [],
      profileTeam: null,
      openAuthGate: () => set({ showAuthGate: true }),
      closeAuthGate: () => set({ showAuthGate: false }),
      verifyPhone: () => set({ isVerified: true, showAuthGate: false }),
      setHasSeenSplash: () => set({ hasSeenSplash: true }),
      completeOnboarding: () => set({ hasCompletedOnboarding: true }),
      addFavoriteTeam: (team) => set((state) => {
        if (!state.favoriteTeams.includes(team)) {
          return {
            favoriteTeams: [...state.favoriteTeams, team],
            // Auto-set profile team to the first favorite team added
            profileTeam: state.profileTeam ? state.profileTeam : team
          };
        }
        return state;
      }),
      setProfileTeam: (team) => set({ profileTeam: team }),

      // Initial User State
      fetBalance: 4205, // Adjusted to account for new mock transactions calculations
      walletTransactions: [
        {
          id: 'tx_init4',
          title: 'Transfer to Fan #882190',
          amount: 300,
          type: 'transfer_sent',
          timestamp: Date.now() - 3600000,
          dateStr: '1 hour ago'
        },
        {
          id: 'tx_init3',
          title: 'Transfer from Fan #910243',
          amount: 500,
          type: 'transfer_received',
          timestamp: Date.now() - 43200000,
          dateStr: '12 hours ago'
        },
        {
          id: 'tx_init2',
          title: 'Daily Login Streak',
          amount: 5,
          type: 'earn',
          timestamp: Date.now() - 86400000,
          dateStr: 'Yesterday'
        },
        {
          id: 'tx_init1',
          title: 'Welcome Bonus',
          amount: 5000,
          type: 'earn',
          timestamp: Date.now() - 172800000,
          dateStr: '2 days ago'
        }
      ],
      addFet: (amount) => set((state) => ({ fetBalance: state.fetBalance + amount })),
      deductFet: (amount) => set((state) => ({ fetBalance: state.fetBalance - amount })),
      
      transferFET: (recipient, amount) => {
        const state = get();
        if (state.fetBalance < amount) return { success: false, error: 'Insufficient funds' };
        if (amount <= 0) return { success: false, error: 'Amount must be greater than 0' };
        
        // Remove spaces or hashes if any were passed
        const cleanRecipient = recipient.replace(/\D/g, '');
        if (cleanRecipient === state.fanId.replace(/\D/g, '')) {
           return { success: false, error: "You cannot transfer tokens to yourself." };
        }
        
        const newTx: WalletTransaction = {
          id: Math.random().toString(36).substring(7),
          title: `Transfer to Fan #${cleanRecipient}`,
          amount: amount,
          type: 'transfer_sent',
          timestamp: Date.now(),
          dateStr: 'Just now'
        };

        set((s) => ({
          fetBalance: s.fetBalance - amount,
          walletTransactions: [newTx, ...s.walletTransactions]
        }));

        // Trigger a notification
        state.addNotification({
          type: 'transfer',
          title: 'Transfer Successful',
          message: `You successfully sent ${amount} FET to Fan #${cleanRecipient}.`
        });

        return { success: true };
      },

      // Initial Slip State
      slip: [],
      isSlipOpen: false,
      toggleSlip: () => set((state) => ({ isSlipOpen: !state.isSlipOpen })),
      openSlip: () => set({ isSlipOpen: true }),
      closeSlip: () => set({ isSlipOpen: false }),
      addPrediction: (prediction) => set((state) => {
        const existingIndex = state.slip.findIndex(p => p.matchId === prediction.matchId && p.market === prediction.market);
        if (existingIndex >= 0) {
          const newSlip = [...state.slip];
          newSlip[existingIndex] = prediction;
          return { slip: newSlip, isSlipOpen: true };
        }
        return { slip: [...state.slip, prediction], isSlipOpen: true };
      }),
      removePrediction: (id) => set((state) => ({
        slip: state.slip.filter((p) => p.id !== id),
        isSlipOpen: state.slip.length - 1 > 0 ? state.isSlipOpen : false
      })),
      clearSlip: () => set({ slip: [], isSlipOpen: false }),

      // Notifications State
      notifications: [
        {
          id: 'n1',
          type: 'system',
          title: 'Welcome to FANZONE',
          message: 'Predict matches, earn FET, and climb the leaderboard.',
          timestamp: Date.now() - 86400000,
          read: true,
        }
      ],
      unreadCount: 0,
      addNotification: (notification) => set((state) => {
        const newNotification: AppNotification = {
          ...notification,
          id: Math.random().toString(36).substring(7),
          timestamp: Date.now(),
          read: false,
        };
        return {
          notifications: [newNotification, ...state.notifications],
          unreadCount: state.unreadCount + 1,
        };
      }),
      markAsRead: (id) => set((state) => {
        const notifications = state.notifications.map(n => 
          n.id === id ? { ...n, read: true } : n
        );
        return {
          notifications,
          unreadCount: notifications.filter(n => !n.read).length
        };
      }),
      markAllAsRead: () => set((state) => ({
        notifications: state.notifications.map(n => ({ ...n, read: true })),
        unreadCount: 0
      })),

      // Pool State
      scorePools: mockScorePools,
      poolEntries: mockPoolEntries,
      createPool: (pool, entry) => set((state) => {
        const newTx: WalletTransaction = {
          id: Math.random().toString(36).substring(7),
          title: `Stake: ${pool.matchName}`,
          amount: pool.stake,
          type: 'spend',
          timestamp: Date.now(),
          dateStr: 'Just now'
        };
        return {
          scorePools: [pool, ...state.scorePools],
          poolEntries: [entry, ...state.poolEntries],
          fetBalance: state.fetBalance - pool.stake,
          walletTransactions: [newTx, ...state.walletTransactions]
        };
      }),
      joinPool: (entry) => set((state) => {
        const poolIndex = state.scorePools.findIndex(c => c.id === entry.poolId);
        if (poolIndex === -1) return state;

        const newPools = [...state.scorePools];
        const pool = newPools[poolIndex];
        
        newPools[poolIndex] = {
          ...pool,
          totalPool: pool.totalPool + entry.stake,
          participantsCount: pool.participantsCount + 1
        };

        const newTx: WalletTransaction = {
          id: Math.random().toString(36).substring(7),
          title: `Pool Joined: ${pool.matchName}`,
          amount: entry.stake,
          type: 'spend',
          timestamp: Date.now(),
          dateStr: 'Just now'
        };

        return {
          scorePools: newPools,
          poolEntries: [...state.poolEntries, entry],
          fetBalance: state.fetBalance - entry.stake,
          walletTransactions: [newTx, ...state.walletTransactions]
        };
      }),
    }),
    {
      name: 'fanzone-storage',
      partialize: (state) => ({ 
        theme: state.theme,
        hasSeenSplash: state.hasSeenSplash,
        hasCompletedOnboarding: state.hasCompletedOnboarding,
        isVerified: state.isVerified,
        fetBalance: state.fetBalance,
        walletTransactions: state.walletTransactions,
        scorePools: state.scorePools,
        poolEntries: state.poolEntries,
      }),
    }
  )
);
