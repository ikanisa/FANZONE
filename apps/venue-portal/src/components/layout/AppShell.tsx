import { useState } from 'react';
import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { 
  Utensils, 
  ClipboardList, 
  Trophy, 
  Coins,
  QrCode,
  BarChart3,
  Settings,
  ChevronLeft,
  ChevronRight,
  LogOut
} from 'lucide-react';
import { useVenue } from '../../hooks/useVenueContext';
import { supabase } from '../../lib/supabase';

const navItems = [
  { label: 'Orders', path: '/orders', icon: <ClipboardList size={20} /> },
  { label: 'Menu', path: '/menu', icon: <Utensils size={20} /> },
  { label: 'Pools', path: '/pools', icon: <Trophy size={20} /> },
  { label: 'FET Rewards', path: '/rewards', icon: <Coins size={20} /> },
  { label: 'Tables / QR', path: '/tables', icon: <QrCode size={20} /> },
  { label: 'Insights', path: '/insights', icon: <BarChart3 size={20} /> },
  { label: 'Settings', path: '/settings', icon: <Settings size={20} /> },
];

export const Sidebar = () => {
  const [collapsed, setCollapsed] = useState(false);
  const navigate = useNavigate();

  const handleLogout = async () => {
    await supabase.auth.signOut();
    navigate('/', { replace: true });
  };

  return (
    <aside className={`bg-surface border-r border-border hidden md:flex flex-col transition-all duration-300 ${collapsed ? 'w-20' : 'w-72'}`}>
      <div className="h-20 flex items-center px-6 border-b border-border justify-between">
        {!collapsed && (
          <div>
            <span className="block text-[10px] font-black uppercase tracking-widest text-textSecondary">
              Sports bar ops
            </span>
            <span className="font-black text-xl tracking-tight text-text">Venue Console</span>
          </div>
        )}
        <button onClick={() => setCollapsed(!collapsed)} className="p-2 hover:bg-surface2 rounded-lg text-textSecondary">
          {collapsed ? <ChevronRight size={18} /> : <ChevronLeft size={18} />}
        </button>
      </div>

      <nav className="flex-1 p-4 space-y-2">
        {navItems.map(item => (
          <NavLink
            key={item.path}
            to={item.path}
            className={({ isActive }) => `
              flex items-center gap-3 px-4 py-3 rounded-xl font-bold transition-all
              ${isActive ? 'bg-primary text-primaryText shadow-lg shadow-primary/20' : 'text-textSecondary hover:bg-surface2 hover:text-text'}
              ${collapsed ? 'justify-center px-0' : ''}
            `}
          >
            {item.icon}
            {!collapsed && <span>{item.label}</span>}
          </NavLink>
        ))}
      </nav>

      <div className="p-4 border-t border-border">
        <button
          type="button"
          onClick={handleLogout}
          className={`flex items-center gap-3 w-full px-4 py-3 text-danger font-bold hover:bg-danger/5 rounded-xl transition-all ${collapsed ? 'justify-center px-0' : ''}`}
        >
          <LogOut size={20} />
          {!collapsed && <span>Logout</span>}
        </button>
      </div>
    </aside>
  );
};

export const AppShell = () => {
  const { venue } = useVenue();
  const venueName = venue?.name ?? 'Venue';
  const venueInitials = venueName
    .split(' ')
    .map((namePart) => namePart[0])
    .join('')
    .slice(0, 2)
    .toUpperCase();

  return (
    <div className="flex h-screen bg-bg overflow-hidden">
      <Sidebar />
      <div className="flex-1 flex flex-col overflow-hidden">
        <header className="bg-surface/95 backdrop-blur border-b border-border flex flex-col gap-4 px-4 py-4 md:h-20 md:px-8 md:py-0 md:flex-row md:items-center md:justify-between shrink-0">
          <div>
            <h2 className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Live operations</h2>
            <p className="font-black text-xl text-text">{venueName}</p>
          </div>
          <div className="hidden md:flex items-center gap-4">
            <div className="w-10 h-10 bg-accent text-bg rounded-xl border border-accent/20 flex items-center justify-center font-black">
              {venueInitials}
            </div>
          </div>
          <nav className="md:hidden flex gap-2 overflow-x-auto no-scrollbar pb-1">
            {navItems.map((item) => (
              <NavLink
                key={item.path}
                to={item.path}
                className={({ isActive }) => `
                  shrink-0 flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-black transition-all
                  ${isActive ? 'bg-primary text-primaryText' : 'text-textSecondary bg-surface2'}
                `}
              >
                {item.icon}
                <span>{item.label}</span>
              </NavLink>
            ))}
          </nav>
        </header>
        <main className="flex-1 overflow-y-auto p-4 md:p-8 no-scrollbar">
          <Outlet />
        </main>
      </div>
    </div>
  );
};
