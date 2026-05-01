// FANZONE Admin — Sidebar Navigation
import { NavLink, useLocation } from "react-router-dom";
import { useState } from "react";
import {
  BarChart3,
  Building2,
  ChevronLeft,
  ChevronRight,
  Coins,
  Flag,
  Globe2,
  ListChecks,
  ScrollText,
  Shield,
  SlidersHorizontal,
  Trophy,
  Users,
  Wallet,
} from "lucide-react";

import { ROUTES } from "../../config/routes";
import type { AdminRole } from "../../config/constants";
import { useAuth } from "../../hooks/useAuth";
import { hasMinRole } from "../../lib/formatters";
import { FanzoneWordmark } from "../FanzoneWordmark";

const logoImg = "/brand/logo-mark-64.png";

interface NavItem {
  label: string;
  path: string;
  icon: React.ReactNode;
  minRole: AdminRole;
}

const NAV_ITEMS: NavItem[] = [
  {
    label: "Overview",
    path: ROUTES.OVERVIEW,
    icon: <BarChart3 size={18} />,
    minRole: "viewer",
  },
  {
    label: "Countries",
    path: ROUTES.COUNTRIES,
    icon: <Globe2 size={18} />,
    minRole: "admin",
  },
  {
    label: "Venues",
    path: ROUTES.VENUES,
    icon: <Building2 size={18} />,
    minRole: "admin",
  },
  {
    label: "Competitions",
    path: ROUTES.COMPETITIONS,
    icon: <Trophy size={18} />,
    minRole: "admin",
  },
  {
    label: "Teams",
    path: ROUTES.TEAMS,
    icon: <Users size={18} />,
    minRole: "admin",
  },
  {
    label: "Curated Matches",
    path: ROUTES.CURATED_MATCHES,
    icon: <ListChecks size={18} />,
    minRole: "admin",
  },
  {
    label: "Pools",
    path: ROUTES.POOLS,
    icon: <Trophy size={18} />,
    minRole: "admin",
  },
  {
    label: "FET Wallets",
    path: ROUTES.FET_WALLETS,
    icon: <Wallet size={18} />,
    minRole: "admin",
  },
  {
    label: "Settlements",
    path: ROUTES.SETTLEMENTS,
    icon: <Flag size={18} />,
    minRole: "admin",
  },
  {
    label: "Reward Rules",
    path: ROUTES.REWARD_RULES,
    icon: <Coins size={18} />,
    minRole: "admin",
  },
  {
    label: "Risk & Abuse",
    path: ROUTES.RISK_ABUSE,
    icon: <Shield size={18} />,
    minRole: "moderator",
  },
  {
    label: "Feature Flags",
    path: ROUTES.FEATURE_FLAGS,
    icon: <SlidersHorizontal size={18} />,
    minRole: "admin",
  },
  {
    label: "Audit Logs",
    path: ROUTES.AUDIT_LOGS,
    icon: <ScrollText size={18} />,
    minRole: "admin",
  },
];

export function Sidebar() {
  const { admin } = useAuth();
  const location = useLocation();
  const [collapsed, setCollapsed] = useState(false);
  const role = admin?.role || "viewer";
  const visibleItems = NAV_ITEMS.filter((item) => hasMinRole(role, item.minRole));

  return (
    <aside className={`sidebar ${collapsed ? "sidebar-collapsed" : ""}`}>
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

      <nav className="sidebar-nav">
        <div className="sidebar-section">
          {!collapsed && <div className="sidebar-section-title">Admin PWA</div>}
          {visibleItems.map((item) => (
            <NavLink
              key={item.path}
              to={item.path}
              end={item.path === ROUTES.OVERVIEW}
              className={({ isActive }) =>
                `sidebar-link ${isActive || (item.path !== ROUTES.OVERVIEW && location.pathname.startsWith(item.path)) ? "active" : ""}`
              }
              title={collapsed ? item.label : undefined}
            >
              {item.icon}
              {!collapsed && <span>{item.label}</span>}
            </NavLink>
          ))}
        </div>
      </nav>

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
