import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export interface AppNotification {
  id: string;
  type: 'pool_update' | 'pool_reward' | 'system' | 'transfer';
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
  openAuthGate: () => void;
  closeAuthGate: () => void;
  verifyPhone: () => void;
  setHasSeenSplash: () => void;
  completeOnboarding: () => void;
  hydrateViewerState: (payload: {
    fanId?: string;
    isVerified?: boolean;
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
      fanId: '',
      showAuthGate: false,
      hasSeenSplash: false,
      hasCompletedOnboarding: false,
      openAuthGate: () => set({ showAuthGate: true }),
      closeAuthGate: () => set({ showAuthGate: false }),
      verifyPhone: () => set({ isVerified: true, showAuthGate: false }),
      setHasSeenSplash: () => set({ hasSeenSplash: true }),
      completeOnboarding: () => set({ hasCompletedOnboarding: true }),
      hydrateViewerState: (payload) =>
        set((state) => {
          const nextNotifications = payload.notifications ?? state.notifications;

          return {
            fanId: payload.fanId ?? state.fanId,
            isVerified: payload.isVerified ?? state.isVerified,
            fetBalance: payload.fetBalance ?? state.fetBalance,
            walletTransactions:
              payload.walletTransactions ?? state.walletTransactions,
            notifications: nextNotifications,
            unreadCount: nextNotifications.filter((notification) => !notification.read)
              .length,
          };
        }),

      // Initial User State
      fetBalance: 0,
      walletTransactions: [],
      addFet: (amount) => set((state) => ({ fetBalance: state.fetBalance + amount })),
      deductFet: (amount) => set((state) => ({ fetBalance: state.fetBalance - amount })),
      
      transferFET: (recipient, amount) => {
        const state = get();
        if (state.fetBalance < amount) return { success: false, error: 'Insufficient funds' };
        if (amount <= 0) return { success: false, error: 'Amount must be greater than 0' };
        
        // Remove spaces or hashes if any were passed
        const cleanRecipient = recipient.replace(/\D/g, '');
        if (cleanRecipient === state.fanId.replace(/\D/g, '')) {
           return { success: false, error: "You cannot transfer FET to yourself." };
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
      notifications: [],
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
      version: 2,
      migrate: (persistedState, version) => {
        if (
          version < 2 &&
          persistedState &&
          typeof persistedState === 'object'
        ) {
          return {
            ...(persistedState as Partial<AppState>),
            fetBalance: 0,
            walletTransactions: [],
          } as AppState;
        }

        return persistedState as AppState;
      },
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
