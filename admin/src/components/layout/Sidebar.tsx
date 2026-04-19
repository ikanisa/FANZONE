// FANZONE Admin — Sidebar Navigation
import { NavLink, useLocation } from 'react-router-dom';
import { useAuth } from '../../hooks/useAuth';
import { hasMinRole } from '../../lib/formatters';
import {
  LayoutDashboard, Users, Trophy, Calendar, Target, Swords, Sparkles,
  Coins, Wallet, Handshake, Gift, ShoppingBag, FileText,
  Shield, BarChart3, Settings, UserCog, ScrollText, ChevronLeft, ChevronRight, Bell, UserX,
} from 'lucide-react';
import { useState } from 'react';
import type { AdminRole } from '../../config/constants';
import logoImg from '../../assets/logo-64.png';

interface NavItem {
  label: string;
  path: string;
  icon: React.ReactNode;
  minRole: AdminRole;
  badge?: number;
}

const NAV_SECTIONS: { title: string; items: NavItem[] }[] = [
  {
    title: 'Overview',
    items: [
      { label: 'Dashboard', path: '/', icon: <LayoutDashboard size={18} />, minRole: 'viewer' },
    ],
  },
  {
    title: 'Platform',
    items: [
      { label: 'Users', path: '/users', icon: <Users size={18} />, minRole: 'admin' },
      { label: 'Competitions', path: '/competitions', icon: <Trophy size={18} />, minRole: 'admin' },
      { label: 'Fixtures', path: '/fixtures', icon: <Calendar size={18} />, minRole: 'moderator' },
      { label: 'Predictions', path: '/predictions', icon: <Target size={18} />, minRole: 'admin' },
      { label: 'Pools', path: '/challenges', icon: <Swords size={18} />, minRole: 'moderator' },
      { label: 'Events', path: '/events', icon: <Sparkles size={18} />, minRole: 'admin' },
    ],
  },
  {
    title: 'Finance',
    items: [
      { label: 'FET Tokens', path: '/tokens', icon: <Coins size={18} />, minRole: 'admin' },
      { label: 'Wallets', path: '/wallets', icon: <Wallet size={18} />, minRole: 'admin' },
      { label: 'Partners', path: '/partners', icon: <Handshake size={18} />, minRole: 'admin' },
      { label: 'Rewards', path: '/rewards', icon: <Gift size={18} />, minRole: 'admin' },
      { label: 'Redemptions', path: '/redemptions', icon: <ShoppingBag size={18} />, minRole: 'moderator' },
    ],
  },
  {
    title: 'Operations',
    items: [
      { label: 'Content', path: '/content', icon: <FileText size={18} />, minRole: 'admin' },
      { label: 'Moderation', path: '/moderation', icon: <Shield size={18} />, minRole: 'moderator' },
      { label: 'Analytics', path: '/analytics', icon: <BarChart3 size={18} />, minRole: 'viewer' },
      { label: 'Notifications', path: '/notifications', icon: <Bell size={18} />, minRole: 'admin' },
      { label: 'Account Deletions', path: '/account-deletions', icon: <UserX size={18} />, minRole: 'admin' },
    ],
  },
  {
    title: 'System',
    items: [
      { label: 'Settings', path: '/settings', icon: <Settings size={18} />, minRole: 'super_admin' },
      { label: 'Admin Access', path: '/admin-access', icon: <UserCog size={18} />, minRole: 'super_admin' },
      { label: 'Audit Logs', path: '/audit-logs', icon: <ScrollText size={18} />, minRole: 'admin' },
    ],
  },
];

export function Sidebar() {
  const { admin } = useAuth();
  const location = useLocation();
  const [collapsed, setCollapsed] = useState(false);
  const role = admin?.role || 'viewer';

  return (
    <aside className={`sidebar ${collapsed ? 'sidebar-collapsed' : ''}`}>
      {/* Brand */}
      <div className="sidebar-brand">
        <div className="sidebar-logo">
          <img src={logoImg} alt="FANZONE" className="sidebar-logo-icon" />
          {!collapsed && <span className="sidebar-logo-text">FANZONE</span>}
        </div>
        <button
          className="btn btn-ghost btn-icon sidebar-toggle"
          onClick={() => setCollapsed(!collapsed)}
          aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        >
          {collapsed ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
        </button>
      </div>

      {/* Navigation */}
      <nav className="sidebar-nav">
        {NAV_SECTIONS.map(section => {
          const visibleItems = section.items.filter(item => hasMinRole(role, item.minRole));
          if (visibleItems.length === 0) return null;

          return (
            <div key={section.title} className="sidebar-section">
              {!collapsed && <div className="sidebar-section-title">{section.title}</div>}
              {visibleItems.map(item => (
                <NavLink
                  key={item.path}
                  to={item.path}
                  end={item.path === '/'}
                  className={({ isActive }) =>
                    `sidebar-link ${isActive || (item.path !== '/' && location.pathname.startsWith(item.path)) ? 'active' : ''}`
                  }
                  title={collapsed ? item.label : undefined}
                >
                  {item.icon}
                  {!collapsed && <span>{item.label}</span>}
                  {!collapsed && item.badge !== undefined && item.badge > 0 && (
                    <span className="sidebar-badge">{item.badge}</span>
                  )}
                </NavLink>
              ))}
            </div>
          );
        })}
      </nav>

      {/* Footer */}
      {!collapsed && admin && (
        <div className="sidebar-footer">
          <div className="sidebar-user">
            <div className="sidebar-avatar">{admin.display_name.charAt(0)}</div>
            <div className="sidebar-user-info">
              <div className="sidebar-user-name">{admin.display_name}</div>
              <div className="sidebar-user-role">{admin.role.replace('_', ' ')}</div>
            </div>
          </div>
        </div>
      )}

      <style>{`
        .sidebar {
          width: var(--fz-sidebar-w);
          height: 100vh;
          background: var(--fz-surface);
          border-right: 1px solid var(--fz-border);
          display: flex;
          flex-direction: column;
          position: fixed;
          left: 0;
          top: 0;
          z-index: 30;
          transition: width var(--fz-transition-slow);
          overflow: hidden;
        }
        .sidebar-collapsed {
          width: var(--fz-sidebar-collapsed-w);
        }
        .sidebar-brand {
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: var(--fz-sp-4);
          border-bottom: 1px solid var(--fz-border);
          min-height: var(--fz-topbar-h);
        }
        .sidebar-logo {
          display: flex;
          align-items: center;
          gap: var(--fz-sp-3);
        }
        .sidebar-logo-icon {
          width: 32px;
          height: 32px;
          border-radius: var(--fz-radius);
          object-fit: contain;
          flex-shrink: 0;
        }
        .sidebar-logo-text {
          font-size: var(--fz-text-md);
          font-weight: 700;
          letter-spacing: 0.05em;
          color: var(--fz-text);
        }
        .sidebar-toggle {
          opacity: 0;
          transition: opacity var(--fz-transition);
        }
        .sidebar:hover .sidebar-toggle { opacity: 1; }
        .sidebar-nav {
          flex: 1;
          overflow-y: auto;
          padding: var(--fz-sp-2) var(--fz-sp-2);
        }
        .sidebar-section {
          margin-bottom: var(--fz-sp-4);
        }
        .sidebar-section-title {
          font-size: var(--fz-text-xs);
          font-weight: 600;
          color: var(--fz-muted-2);
          text-transform: uppercase;
          letter-spacing: 0.08em;
          padding: var(--fz-sp-2) var(--fz-sp-3);
        }
        .sidebar-link {
          display: flex;
          align-items: center;
          gap: var(--fz-sp-3);
          padding: var(--fz-sp-2) var(--fz-sp-3);
          border-radius: var(--fz-radius);
          font-size: var(--fz-text-sm);
          font-weight: 500;
          color: var(--fz-muted);
          transition: all var(--fz-transition);
          white-space: nowrap;
        }
        .sidebar-link:hover {
          background: var(--fz-surface-2);
          color: var(--fz-text);
        }
        .sidebar-link.active {
          background: rgba(14, 165, 233, 0.1);
          color: var(--fz-accent);
        }
        .sidebar-link.active svg { color: var(--fz-accent); }
        .sidebar-badge {
          margin-left: auto;
          background: var(--fz-malta-red);
          color: #fff;
          font-size: 10px;
          font-weight: 700;
          padding: 1px 6px;
          border-radius: var(--fz-radius-full);
        }
        .sidebar-footer {
          padding: var(--fz-sp-4);
          border-top: 1px solid var(--fz-border);
        }
        .sidebar-user {
          display: flex;
          align-items: center;
          gap: var(--fz-sp-3);
        }
        .sidebar-avatar {
          width: 32px;
          height: 32px;
          background: var(--fz-surface-3);
          border-radius: var(--fz-radius-full);
          display: flex;
          align-items: center;
          justify-content: center;
          font-weight: 600;
          font-size: var(--fz-text-sm);
          color: var(--fz-text);
          flex-shrink: 0;
        }
        .sidebar-user-info { overflow: hidden; }
        .sidebar-user-name {
          font-size: var(--fz-text-sm);
          font-weight: 600;
          color: var(--fz-text);
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
        }
        .sidebar-user-role {
          font-size: var(--fz-text-xs);
          color: var(--fz-muted);
          text-transform: capitalize;
        }
      `}</style>
    </aside>
  );
}
