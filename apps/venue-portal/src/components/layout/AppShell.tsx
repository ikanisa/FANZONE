import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { Link, NavLink, Outlet, useNavigate } from 'react-router-dom';
import {
  BarChart3,
  Bell,
  ChevronLeft,
  ChevronRight,
  ClipboardList,
  Coins,
  Gamepad2,
  LayoutDashboard,
  LogOut,
  MonitorPlay,
  Plus,
  Settings,
  ShieldCheck,
  Trophy,
  Users,
  Utensils,
  Wallet,
} from 'lucide-react';
import { StatusChip } from '../console/StatusChip';
import { useOrders } from '../../hooks/useOrders';
import { useVenue } from '../../hooks/useVenueContext';
import { useVenueStats } from '../../hooks/useVenueStats';
import { supabase } from '../../lib/supabase';

const navItems = [
  { label: 'Overview', path: '/overview', icon: <LayoutDashboard size={20} /> },
  { label: 'Orders', path: '/orders', icon: <ClipboardList size={20} /> },
  { label: 'Menu', path: '/menu', icon: <Utensils size={20} /> },
  { label: 'Pools', path: '/pools', icon: <Trophy size={20} /> },
  { label: 'Games', path: '/games', icon: <Gamepad2 size={20} /> },
  { label: 'Teams', path: '/teams', icon: <Users size={20} /> },
  { label: 'Screen', path: '/screen', icon: <MonitorPlay size={20} /> },
  { label: 'FET Wallet', path: '/wallet', icon: <Wallet size={20} /> },
  { label: 'Insights', path: '/insights', icon: <BarChart3 size={20} /> },
  { label: 'Settings', path: '/settings', icon: <Settings size={20} /> },
];

const quickActions = [
  { label: 'Start Game', path: '/games/new', icon: <Gamepad2 size={18} /> },
  { label: 'Create Pool', path: '/pools/new', icon: <Trophy size={18} /> },
  { label: 'Add Menu Item', path: '/menu/items/new', icon: <Utensils size={18} /> },
  { label: 'Open Screen', path: '/screen', icon: <MonitorPlay size={18} /> },
];

const activeServiceStatuses = ['placed', 'received', 'preparing'];

function roleLabel(role: string | undefined) {
  if (!role) return 'Staff';
  return role.replace(/_/g, ' ');
}

function HeaderClock() {
  const [now, setNow] = useState(() => new Date());

  useEffect(() => {
    const timer = window.setInterval(() => setNow(new Date()), 30_000);
    return () => window.clearInterval(timer);
  }, []);

  return (
    <span>
      {new Intl.DateTimeFormat(undefined, {
        weekday: 'short',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      }).format(now)}
    </span>
  );
}

export const Sidebar = () => {
  const [collapsed, setCollapsed] = useState(false);
  const navigate = useNavigate();

  const handleLogout = async () => {
    await supabase.auth.signOut();
    navigate('/', { replace: true });
  };

  return (
    <aside className={`bg-surface border-r border-border hidden lg:flex flex-col transition-all duration-300 ${collapsed ? 'w-20' : 'w-72'}`}>
      <div className="h-24 flex items-center px-5 border-b border-border justify-between">
        {!collapsed && (
          <div>
            <span className="block text-xs font-black uppercase tracking-wide text-textSecondary">
              Sports-bar ops
            </span>
            <span className="font-black text-2xl tracking-tight text-text">Venue Console</span>
          </div>
        )}
        <button
          type="button"
          onClick={() => setCollapsed(!collapsed)}
          className="p-2.5 hover:bg-surface2 rounded-xl text-textSecondary"
          aria-label={collapsed ? 'Expand navigation' : 'Collapse navigation'}
        >
          {collapsed ? <ChevronRight size={18} /> : <ChevronLeft size={18} />}
        </button>
      </div>

      <nav className="flex-1 p-4 space-y-2 overflow-y-auto no-scrollbar">
        {navItems.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            className={({ isActive }) => `
              flex items-center gap-3 px-4 py-3.5 rounded-2xl font-black transition-all
              ${isActive ? 'bg-primary text-primaryText shadow-lg shadow-primary/20' : 'text-textSecondary hover:bg-surface2 hover:text-text'}
              ${collapsed ? 'justify-center px-0' : ''}
            `}
            title={collapsed ? item.label : undefined}
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
          className={`flex min-h-12 items-center gap-3 w-full px-4 py-3 text-danger font-black hover:bg-danger/5 rounded-2xl transition-all ${collapsed ? 'justify-center px-0' : ''}`}
        >
          <LogOut size={20} />
          {!collapsed && <span>Logout</span>}
        </button>
      </div>
    </aside>
  );
};

export const AppShell = () => {
  const { venue, member } = useVenue();
  const venueId = venue?.id || '';
  const { stats } = useVenueStats(venueId);
  const { orders } = useOrders(venueId);
  const [quickOpen, setQuickOpen] = useState(false);
  const venueName = venue?.name ?? 'Venue';
  const venueInitials = useMemo(
    () =>
      venueName
        .split(' ')
        .map((namePart) => namePart[0])
        .join('')
        .slice(0, 2)
        .toUpperCase(),
    [venueName],
  );
  const activeOrders = orders.filter((order) => activeServiceStatuses.includes(order.status)).length;
  const pendingPayments = orders.filter((order) =>
    ['unpaid', 'payment_submitted', 'pending', 'partially_paid', 'disputed'].includes(order.paymentStatus),
  ).length;

  return (
    <div className="flex h-screen bg-bg overflow-hidden">
      <Sidebar />
      <div className="flex-1 flex flex-col overflow-hidden">
        <header className="bg-surface/95 backdrop-blur border-b border-border shrink-0">
          <div className="px-4 py-4 xl:px-8 xl:py-5 flex flex-col gap-4 2xl:flex-row 2xl:items-center 2xl:justify-between">
            <div className="flex min-w-0 items-center gap-4">
              <div className="w-12 h-12 bg-accent text-bg rounded-2xl border border-accent/20 flex items-center justify-center font-black shrink-0">
                {venueInitials}
              </div>
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2">
                  <p className="text-xs font-black text-textSecondary uppercase tracking-wide">Current venue</p>
                  <StatusChip status={venue?.isOpen ? 'open' : 'closed'} label={venue?.isOpen ? 'Open' : 'Closed'} />
                </div>
                <h2 className="font-black text-2xl md:text-3xl tracking-tight text-text truncate">{venueName}</h2>
              </div>
            </div>

            <div className="flex flex-wrap items-center gap-2 xl:gap-3">
              <HeaderPill label="Time" value={<HeaderClock />} />
              <HeaderPill label="Orders" value={`${activeOrders} active`} tone={activeOrders ? 'primary' : 'neutral'} />
              <HeaderPill label="Payments" value={`${pendingPayments} pending`} tone={pendingPayments ? 'warning' : 'neutral'} />
              <HeaderPill label="Games/Pools" value={`Games pending · ${stats.active_pools} pools`} tone={stats.active_pools ? 'primary' : 'neutral'} />
              <HeaderPill label="FET wallet" value="Ledger needed" icon={<Coins size={16} />} />
            </div>

            <div className="flex items-center gap-3">
              <Link
                to="/notifications"
                className="h-12 w-12 rounded-2xl border border-border bg-surface2 text-textSecondary hover:text-text hover:bg-surface3 flex items-center justify-center"
                aria-label="Open notifications"
              >
                <Bell size={20} />
              </Link>
              <div className="hidden md:flex items-center gap-3 rounded-2xl border border-border bg-surface2 px-4 py-2.5">
                <ShieldCheck size={18} className="text-success" />
                <div>
                  <p className="text-[11px] font-black uppercase tracking-wide text-textSecondary">Role</p>
                  <p className="text-sm font-black capitalize">{roleLabel(member?.role)}</p>
                </div>
              </div>
              <div className="relative">
                <button
                  type="button"
                  className="btn btn-primary"
                  onClick={() => setQuickOpen((current) => !current)}
                >
                  <Plus size={18} />
                  Quick Action
                </button>
                {quickOpen && (
                  <div className="absolute right-0 mt-3 w-64 rounded-3xl border border-border bg-surface shadow-2xl shadow-black/40 p-2 z-20">
                    {quickActions.map((action) => (
                      <Link
                        key={action.path}
                        to={action.path}
                        onClick={() => setQuickOpen(false)}
                        className="flex items-center gap-3 rounded-2xl px-4 py-3 text-sm font-black text-textSecondary hover:bg-surface2 hover:text-text"
                      >
                        {action.icon}
                        {action.label}
                      </Link>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </div>

          <nav className="lg:hidden flex gap-2 overflow-x-auto no-scrollbar px-4 pb-4">
            {navItems.map((item) => (
              <NavLink
                key={item.path}
                to={item.path}
                className={({ isActive }) => `
                  shrink-0 flex items-center gap-2 px-3 py-2.5 rounded-2xl text-sm font-black transition-all
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

function HeaderPill({
  label,
  value,
  tone = 'neutral',
  icon,
}: {
  label: string;
  value: ReactNode;
  tone?: 'neutral' | 'primary' | 'warning';
  icon?: ReactNode;
}) {
  const toneClass = {
    neutral: 'bg-surface2 text-textSecondary border-border',
    primary: 'bg-primary/10 text-primary border-primary/20',
    warning: 'bg-warning/10 text-warning border-warning/20',
  }[tone];

  return (
    <div className={`min-h-12 rounded-2xl border px-4 py-2 flex items-center gap-3 ${toneClass}`}>
      {icon}
      <div>
        <p className="text-[11px] font-black uppercase tracking-wide opacity-75">{label}</p>
        <p className="text-sm font-black text-text">{value}</p>
      </div>
    </div>
  );
}
