import { create } from 'zustand';
import { persist } from 'zustand/middleware';

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
  type: 'prediction_update' | 'prediction_reward' | 'system' | 'transfer';
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
  setFavoriteTeams: (teams: string[]) => void;
  setProfileTeam: (team: string | null) => void;
  hydrateViewerState: (payload: {
    fanId?: string;
    isVerified?: boolean;
    favoriteTeams?: string[];
    profileTeam?: string | null;
    fetBalance?: number;
    walletTransactions?: WalletTransaction[];
    notifications?: AppNotification[];
  }) => void;

  // User State
  fetBalance: number;
  walletTransactions: WalletTransaction[];
  addFet: (amount: number) => void;
  deductFet: (amount: number) => void;
  transferFET: (recipient: string, amount: number) => { success: boolean; error?: string };

  // Notifications State
  notifications: AppNotification[];
  unreadCount: number;
  addNotification: (notification: Omit<AppNotification, 'id' | 'timestamp' | 'read'>) => void;
  markAsRead: (id: string) => void;
  markAllAsRead: () => void;

}

export const useAppStore = create<AppState>()(
  persist(
    (set, get) => ({
      // Theme State
      theme: 'light',
      toggleTheme: () => set((state) => ({ theme: state.theme === 'light' ? 'dark' : 'light' })),

      // Initial Auth State
      isVerified: false,
      fanId: '483291',
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
      setFavoriteTeams: (teams) => set((state) => {
        const uniqueTeams = [...new Set(teams.map((team) => team.trim()).filter(Boolean))];
        return {
          favoriteTeams: uniqueTeams,
          profileTeam:
            state.profileTeam && uniqueTeams.includes(state.profileTeam)
              ? state.profileTeam
              : uniqueTeams[0] ?? state.profileTeam,
        };
      }),
      setProfileTeam: (team) => set({ profileTeam: team }),
      hydrateViewerState: (payload) =>
        set((state) => {
          const nextNotifications = payload.notifications ?? state.notifications;
          const nextFavoriteTeams =
            payload.favoriteTeams && payload.favoriteTeams.length > 0
              ? [...new Set(payload.favoriteTeams)]
              : state.favoriteTeams;

          return {
            fanId: payload.fanId ?? state.fanId,
            isVerified: payload.isVerified ?? state.isVerified,
            favoriteTeams: nextFavoriteTeams,
            profileTeam:
              payload.profileTeam ??
              state.profileTeam ??
              nextFavoriteTeams[0] ??
              null,
            fetBalance: payload.fetBalance ?? state.fetBalance,
            walletTransactions:
              payload.walletTransactions ?? state.walletTransactions,
            notifications: nextNotifications,
            unreadCount: nextNotifications.filter((notification) => !notification.read)
              .length,
          };
        }),

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
      }),
    }
  )
);
