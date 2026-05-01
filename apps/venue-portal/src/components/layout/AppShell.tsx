import { useState } from 'react';
import { NavLink, Outlet } from 'react-router-dom';
import { 
  LayoutDashboard, 
  Utensils, 
  ClipboardList, 
  Trophy, 
  BarChart3, 
  ChevronLeft,
  ChevronRight,
  LogOut,
  Bell
} from 'lucide-react';
import { useVenue } from '../../hooks/useVenueContext';

export const Sidebar = () => {
  const [collapsed, setCollapsed] = useState(false);

  const navItems = [
    { label: 'Dashboard', path: '/', icon: <LayoutDashboard size={20} /> },
    { label: 'Menu Architect', path: '/menu', icon: <Utensils size={20} /> },
    { label: 'Live Orders', path: '/orders', icon: <ClipboardList size={20} /> },
    { label: 'Match Stakes', path: '/stakes', icon: <Trophy size={20} /> },
    { label: 'Analytics', path: '/analytics', icon: <BarChart3 size={20} /> },
  ];

  return (
    <aside className={`bg-white border-r border-border flex flex-col transition-all duration-300 ${collapsed ? 'w-20' : 'w-64'}`}>
      <div className="h-20 flex items-center px-6 border-b border-border justify-between">
        {!collapsed && <span className="font-black text-xl tracking-tighter">VENUE MASTER</span>}
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
              ${isActive ? 'bg-primary text-primaryText shadow-lg shadow-primary/20' : 'text-textSecondary hover:bg-surface2'}
              ${collapsed ? 'justify-center px-0' : ''}
            `}
          >
            {item.icon}
            {!collapsed && <span>{item.label}</span>}
          </NavLink>
        ))}
      </nav>

      <div className="p-4 border-t border-border">
        <button className={`flex items-center gap-3 w-full px-4 py-3 text-danger font-bold hover:bg-danger/5 rounded-xl transition-all ${collapsed ? 'justify-center px-0' : ''}`}>
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
    <div className="flex h-screen bg-surface2 overflow-hidden">
      <Sidebar />
      <div className="flex-1 flex flex-col overflow-hidden">
        <header className="h-20 bg-white border-b border-border flex items-center px-8 justify-between shrink-0">
          <div>
            <h2 className="text-sm font-bold text-textSecondary uppercase tracking-widest">Venue Portal</h2>
            <p className="font-black text-text">{venueName}</p>
          </div>
          <div className="flex items-center gap-4">
            <button className="relative p-2 bg-surface2 rounded-xl text-textSecondary hover:text-text transition-colors">
              <Bell size={20} />
              <span className="absolute top-1 right-1 w-2 h-2 bg-danger rounded-full border-2 border-white" />
            </button>
            <div className="w-10 h-10 bg-accent rounded-full border border-primary/10 flex items-center justify-center font-black">
              {venueInitials}
            </div>
          </div>
        </header>
        <main className="flex-1 overflow-y-auto p-8 no-scrollbar">
          <Outlet />
        </main>
      </div>
    </div>
  );
};
