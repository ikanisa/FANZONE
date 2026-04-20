import { ReactNode } from 'react';
import { Home, Trophy, Calendar, User, Zap, Wallet, Swords } from 'lucide-react';
import { NavLink } from 'react-router-dom';
import { AuthGateModal } from './ui/AuthGateModal';
import { NotificationToast } from './ui/NotificationToast';
import { useAppStore } from '../store/useAppStore';
import { useScrollDirection } from '../hooks/useScrollDirection';

interface LayoutProps {
  children: ReactNode;
}

export default function Layout({ children }: LayoutProps) {
  const { unreadCount, fetBalance } = useAppStore();
  const scrollDirection = useScrollDirection();

  return (
    <div className="flex min-h-screen bg-bg">
      <NotificationToast />
      
      {/* Mobile Top Bar - Auto-hiding */}
      <div 
        className={`lg:hidden fixed top-0 w-full bg-surface/90 backdrop-blur-xl border-b border-border flex justify-between items-center px-6 py-3 z-50 transition-transform duration-300 ease-in-out ${
          scrollDirection === 'down' ? '-translate-y-full' : 'translate-y-0'
        }`}
      >
        <div className="flex items-center gap-2 font-display text-2xl text-text tracking-tight cursor-pointer">
          <span className="w-6 h-6 rounded bg-primary flex items-center justify-center text-surface text-xs font-sans font-black">F</span>
          <span className="text-primary">FAN</span>ZONE
        </div>
        <div className="flex items-center gap-3">
          <div className="bg-surface2 px-3 py-1.5 rounded-full border border-border flex items-center gap-1.5">
             <Wallet size={12} className="text-secondary" />
             <span className="font-mono text-xs font-bold text-text">{fetBalance}</span>
          </div>
        </div>
      </div>

      {/* Sidebar - Desktop */}
      <nav className="hidden lg:flex w-64 flex-col bg-surface border-r border-border p-6 fixed h-full z-40">
        <div className="mb-12 cursor-pointer">
          <h1 className="font-display text-4xl text-text tracking-tight flex items-center gap-2">
            <span className="w-8 h-8 rounded bg-primary flex items-center justify-center text-surface text-lg font-sans font-black">F</span>
            <span className="text-primary">FAN</span>ZONE
          </h1>
        </div>

        <div className="flex flex-col gap-2">
          <NavItem to="/" icon={<Home size={20} />} label="Home" />
          <NavItem to="/fixtures" icon={<Calendar size={20} />} label="Fixtures" />
          <NavItem to="/pools" icon={<Swords size={20} />} label="Pools" />
          <NavItem to="/jackpot" icon={<Zap size={20} />} label="Jackpots" />
          <NavItem to="/leaderboard" icon={<Trophy size={20} />} label="Leaderboard" />
          <NavItem to="/wallet" icon={<Wallet size={20} />} label="Wallet" />
          <NavItem to="/profile" icon={<User size={20} />} label="Profile" badge={unreadCount} />
        </div>
      </nav>

      {/* Main Content */}
      <main className="flex-1 lg:ml-64 pt-16 lg:pt-0 pb-20 lg:pb-0">
        {children}
      </main>

      {/* Bottom Nav - Mobile Auto-hiding Glassy */}
      <div 
        className={`lg:hidden fixed bottom-0 w-full bg-surface/90 backdrop-blur-xl border-t border-border flex justify-around px-2 py-3 z-50 transition-transform duration-300 ease-in-out ${
          scrollDirection === 'down' ? 'translate-y-full' : 'translate-y-0'
        }`}
      >
        <NavItem to="/" icon={<Home size={22} />} label="Home" mobile />
        <NavItem to="/fixtures" icon={<Calendar size={22} />} label="Matches" mobile />
        <NavItem to="/pools" icon={<Swords size={22} />} label="Pools" mobile />
        <NavItem to="/profile" icon={<User size={22} />} label="Profile" mobile badge={unreadCount} />
      </div>

      <AuthGateModal />
    </div>
  );
}

function NavItem({ to, icon, label, mobile = false, badge = 0 }: { to: string; icon: ReactNode; label: string; mobile?: boolean; badge?: number }) {
  return (
    <NavLink 
      to={to} 
      className={({ isActive }) => 
        `flex items-center gap-3 transition-colors relative ${
          mobile 
            ? `flex-col gap-1 px-3 py-1 rounded-xl ${isActive ? 'text-primary [text-shadow:0_0_10px_rgba(152,255,152,0.4)]' : 'text-muted hover:text-text'}`
            : `px-4 py-3 rounded-xl ${isActive ? 'bg-surface2 text-primary font-bold [text-shadow:0_0_10px_rgba(152,255,152,0.2)]' : 'text-muted hover:text-text hover:bg-surface2/50'}`
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
