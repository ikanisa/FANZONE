// FANZONE Admin — Sidebar Navigation
import { NavLink, useLocation } from "react-router-dom";
import { useAuth } from "../../hooks/useAuth";
import { hasMinRole } from "../../lib/formatters";
import {
  LayoutDashboard,
  Users,
  Trophy,
  Calendar,
  Target,
  Swords,
  Sparkles,
  Coins,
  Wallet,
  Handshake,
  Gift,
  ShoppingBag,
  FileText,
  Shield,
  BarChart3,
  Settings,
  UserCog,
  ScrollText,
  ChevronLeft,
  ChevronRight,
  Bell,
  UserX,
} from "lucide-react";
import { useState } from "react";
import type { AdminRole } from "../../config/constants";
import { FanzoneWordmark } from "../FanzoneWordmark";

const logoImg = "/brand/logo-mark-64.png";

interface NavItem {
  label: string;
  path: string;
  icon: React.ReactNode;
  minRole: AdminRole;
  badge?: number;
}

const NAV_SECTIONS: { title: string; items: NavItem[] }[] = [
  {
    title: "Overview",
    items: [
      {
        label: "Dashboard",
        path: "/",
        icon: <LayoutDashboard size={18} />,
        minRole: "viewer",
      },
    ],
  },
  {
    title: "Platform",
    items: [
      {
        label: "Users",
        path: "/users",
        icon: <Users size={18} />,
        minRole: "admin",
      },
      {
        label: "Competitions",
        path: "/competitions",
        icon: <Trophy size={18} />,
        minRole: "admin",
      },
      {
        label: "Fixtures",
        path: "/fixtures",
        icon: <Calendar size={18} />,
        minRole: "moderator",
      },
      {
        label: "Predictions",
        path: "/predictions",
        icon: <Target size={18} />,
        minRole: "admin",
      },
      {
        label: "Pools",
        path: "/challenges",
        icon: <Swords size={18} />,
        minRole: "moderator",
      },
      {
        label: "Events",
        path: "/events",
        icon: <Sparkles size={18} />,
        minRole: "admin",
      },
    ],
  },
  {
    title: "Finance",
    items: [
      {
        label: "FET Tokens",
        path: "/tokens",
        icon: <Coins size={18} />,
        minRole: "admin",
      },
      {
        label: "Wallets",
        path: "/wallets",
        icon: <Wallet size={18} />,
        minRole: "admin",
      },
      {
        label: "Partners",
        path: "/partners",
        icon: <Handshake size={18} />,
        minRole: "admin",
      },
      {
        label: "Rewards",
        path: "/rewards",
        icon: <Gift size={18} />,
        minRole: "admin",
      },
      {
        label: "Redemptions",
        path: "/redemptions",
        icon: <ShoppingBag size={18} />,
        minRole: "moderator",
      },
    ],
  },
  {
    title: "Operations",
    items: [
      {
        label: "Content",
        path: "/content",
        icon: <FileText size={18} />,
        minRole: "admin",
      },
      {
        label: "Moderation",
        path: "/moderation",
        icon: <Shield size={18} />,
        minRole: "moderator",
      },
      {
        label: "Analytics",
        path: "/analytics",
        icon: <BarChart3 size={18} />,
        minRole: "viewer",
      },
      {
        label: "Notifications",
        path: "/notifications",
        icon: <Bell size={18} />,
        minRole: "admin",
      },
      {
        label: "Account Deletions",
        path: "/account-deletions",
        icon: <UserX size={18} />,
        minRole: "admin",
      },
    ],
  },
  {
    title: "System",
    items: [
      {
        label: "Settings",
        path: "/settings",
        icon: <Settings size={18} />,
        minRole: "super_admin",
      },
      {
        label: "Admin Access",
        path: "/admin-access",
        icon: <UserCog size={18} />,
        minRole: "super_admin",
      },
      {
        label: "Audit Logs",
        path: "/audit-logs",
        icon: <ScrollText size={18} />,
        minRole: "admin",
      },
    ],
  },
];

export function Sidebar() {
  const { admin } = useAuth();
  const location = useLocation();
  const [collapsed, setCollapsed] = useState(false);
  const role = admin?.role || "viewer";

  return (
    <aside className={`sidebar ${collapsed ? "sidebar-collapsed" : ""}`}>
      {/* Brand */}
      <div className="sidebar-brand">
        <div className="sidebar-logo">
          <img src={logoImg} alt="FANZONE" className="sidebar-logo-icon" />
          {!collapsed && (
            <span className="sidebar-logo-text">
              <FanzoneWordmark />
            </span>
          )}
        </div>
        <button
          className="btn btn-ghost btn-icon sidebar-toggle"
          onClick={() => setCollapsed(!collapsed)}
          aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
        >
          {collapsed ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
        </button>
      </div>

      {/* Navigation */}
      <nav className="sidebar-nav">
        {NAV_SECTIONS.map((section) => {
          const visibleItems = section.items.filter((item) =>
            hasMinRole(role, item.minRole),
          );
          if (visibleItems.length === 0) return null;

          return (
            <div key={section.title} className="sidebar-section">
              {!collapsed && (
                <div className="sidebar-section-title">{section.title}</div>
              )}
              {visibleItems.map((item) => (
                <NavLink
                  key={item.path}
                  to={item.path}
                  end={item.path === "/"}
                  className={({ isActive }) =>
                    `sidebar-link ${isActive || (item.path !== "/" && location.pathname.startsWith(item.path)) ? "active" : ""}`
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
              <div className="sidebar-user-role">
                {admin.role.replace("_", " ")}
              </div>
            </div>
          </div>
        </div>
      )}
    </aside>
  );
}
