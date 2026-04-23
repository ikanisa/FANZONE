import { ReactNode, useEffect, useMemo } from 'react';
import {
  Calendar,
  Home,
  Trophy,
  User,
  Wallet,
} from 'lucide-react';
import { NavLink, useLocation } from 'react-router-dom';
import { AuthGateModal } from './ui/AuthGateModal';
import { NotificationToast } from './ui/NotificationToast';
import { useAppStore } from '../store/useAppStore';
import { useScrollDirection } from '../hooks/useScrollDirection';
import { api } from '../services/api';
import { getWebsiteNavigationFeatures } from '../platform/access';
import { usePlatformBootstrap } from '../platform/bootstrap';

interface LayoutProps {
  children: ReactNode;
}

export default function Layout({ children }: LayoutProps) {
  const { unreadCount, fetBalance, hydrateViewerState } = useAppStore();
  const scrollDirection = useScrollDirection();
  const location = useLocation();
  const { bootstrap } = usePlatformBootstrap();

  const isHome = location.pathname === '/';
  const navigationItems = useMemo(
    () =>
      getWebsiteNavigationFeatures().map((feature) => ({
        to:
          feature.channels.web.routeKey ??
          feature.defaultRouteKey ??
          '/',
        label:
          feature.channels.web.navigationLabel ??
          feature.displayName,
        icon: iconForRoute(
          feature.channels.web.routeKey ??
            feature.defaultRouteKey ??
            '/',
        ),
      })),
    [bootstrap],
  );
  const mobileNavigationItems = useMemo(() => {
    const topItems = navigationItems.slice(0, 4);
    return topItems;
  }, [navigationItems]);
  const showWalletLink = navigationItems.some((item) => item.to === '/wallet');

  useEffect(() => {
    let active = true;

    api.getViewerState().then((viewerState) => {
      if (!active || !viewerState) return;
      hydrateViewerState({
        fanId: viewerState.profile?.fanId,
        isVerified: viewerState.profile
          ? !viewerState.profile.isAnonymous
          : undefined,
        favoriteTeams: viewerState.favoriteTeams,
        profileTeam:
          viewerState.profile?.favoriteTeamName ??
          viewerState.favoriteTeams[0] ??
          null,
        fetBalance: viewerState.wallet?.availableBalanceFet,
        walletTransactions: viewerState.walletTransactions,
        notifications: viewerState.notifications,
      });
    });

    return () => {
      active = false;
    };
  }, [hydrateViewerState]);

  return (
    <div className="flex flex-col lg:flex-row min-h-screen bg-bg">
      <NotificationToast />
      
      {/* Mobile Top Bar - Auto-hiding - ONLY ON HOME */}
      {isHome && (
        <div 
          className={`lg:hidden fixed top-0 w-full bg-surface/80 backdrop-blur-2xl border-b border-border flex justify-between items-center px-5 py-4 z-50 transition-transform duration-300 ease-in-out ${
            scrollDirection === 'down' ? '-translate-y-full' : 'translate-y-0'
          }`}
        >
          <div className="flex items-center gap-2 cursor-pointer group">
            <div className="w-8 h-8 rounded-[10px] bg-gradient-to-br from-accent to-accent/80 flex items-center justify-center shadow-inner border border-white/10">
              <span className="text-surface text-sm font-sans font-black tracking-tighter">FZ</span>
            </div>
            <div className="font-display text-xl tracking-tight leading-none group-hover:opacity-80 transition-opacity">
              <span className="text-text">FAN</span><span className="text-accent3 opacity-90">ZONE</span>
            </div>
          </div>
          {showWalletLink && (
            <NavLink to="/wallet" className="bg-surface_container_lowest hover:bg-surface2 transition-colors px-3 py-1.5 rounded-full border border-border flex items-center gap-2 shadow-sm">
               <div className="w-4 h-4 rounded-full bg-accent3/20 flex items-center justify-center border border-accent3/30">
                 <Wallet size={10} className="text-accent3" />
               </div>
               <span className="font-mono text-xs font-bold text-text">{fetBalance}</span>
            </NavLink>
          )}
        </div>
      )}

      {/* Sidebar - Desktop */}
      <nav className="hidden lg:flex w-64 flex-col bg-surface border-r border-border p-6 fixed h-full z-40">
        <div className="mb-12 cursor-pointer">
          <h1 className="font-display text-4xl text-text tracking-tight flex items-center gap-2">
            <span className="w-8 h-8 rounded bg-accent flex items-center justify-center text-surface text-lg font-sans font-black">F</span>
            <span className="text-success">FAN</span><span className="text-accent3">ZONE</span>
          </h1>
        </div>

        <div className="flex flex-col gap-2">
          {navigationItems.map((item) => (
            <NavItem
              key={item.to}
              to={item.to}
              icon={item.icon}
              label={item.label}
              badge={item.to === '/profile' ? unreadCount : 0}
            />
          ))}
        </div>
      </nav>

      {/* Main Content */}
      <main className={`flex-1 min-w-0 w-full lg:w-auto lg:ml-64 lg:pt-0 pb-20 lg:pb-0 overflow-x-hidden ${isHome ? 'pt-16' : 'pt-0'}`}>
        {children}
      </main>

      {/* Bottom Nav - Mobile Auto-hiding Glassy */}
      <div 
        className={`lg:hidden fixed bottom-0 w-full bg-surface/90 backdrop-blur-xl border-t border-border flex justify-around px-2 py-3 z-50 transition-transform duration-300 ease-in-out ${
          scrollDirection === 'down' ? 'translate-y-full' : 'translate-y-0'
        }`}
      >
        {mobileNavigationItems.map((item) => (
          <NavItem
            key={item.to}
            to={item.to}
            icon={item.icon}
            label={item.label}
            mobile
            badge={item.to === '/profile' ? unreadCount : 0}
          />
        ))}
      </div>

      <AuthGateModal />
    </div>
  );
}

function iconForRoute(route: string) {
  if (route === '/leaderboard') return <Trophy size={20} />;
  if (route === '/wallet') return <Wallet size={20} />;
  if (route === '/profile') return <User size={20} />;
  if (route === '/fixtures') return <Calendar size={20} />;
  return <Home size={20} />;
}

function NavItem({ to, icon, label, mobile = false, badge = 0 }: { to: string; icon: ReactNode; label: string; mobile?: boolean; badge?: number }) {
  return (
    <NavLink 
      to={to} 
      className={({ isActive }) => 
        `flex items-center gap-3 transition-colors relative ${
          mobile 
            ? `flex-col gap-1 px-3 py-1 rounded-xl ${isActive ? 'text-accent [text-shadow:0_0_10px_rgba(34,211,238,0.4)]' : 'text-muted hover:text-text'}`
            : `px-4 py-3 rounded-xl ${isActive ? 'bg-surface2 text-accent font-bold [text-shadow:0_0_10px_rgba(34,211,238,0.2)]' : 'text-muted hover:text-text hover:bg-surface2/50'}`
        }`
      }
    >
      {({ isActive }) => (
        <>
          <div className="relative">
            {icon}
            {badge > 0 && (
              <span className="absolute -top-1 -right-1 w-2.5 h-2.5 bg-danger rounded-full ring-2 ring-surface shadow-[0_0_8px_rgba(239,68,68,0.6)]"></span>
            )}
          </div>
          {label && (!mobile || isActive) && <span className={`font-sans tracking-tight ${mobile ? 'text-[10px] font-bold' : 'text-sm font-medium'}`}>{label}</span>}
        </>
      )}
    </NavLink>
  );
}
