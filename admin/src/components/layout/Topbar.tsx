import { Bell, Command, LogOut, Search } from 'lucide-react';

import { useAuth } from '../../hooks/useAuth';
import { useGlobalSearch } from '../../hooks/useGlobalSearch';
import { SearchPalette } from './SearchPalette';

export function Topbar() {
  const { admin, signOut } = useAuth();
  const search = useGlobalSearch();

  return (
    <>
      <header className="topbar">
        <button className="topbar-search-trigger" onClick={search.open}>
          <Search size={16} className="topbar-search-icon" />
          <span className="topbar-search-placeholder">Search anything...</span>
          <kbd className="topbar-kbd">
            <Command size={11} />
            K
          </kbd>
        </button>

        <div className="topbar-actions">
          <button
            className="btn btn-ghost btn-icon topbar-notification"
            aria-label="Notifications"
          >
            <Bell size={18} />
            <span className="topbar-notification-dot" />
          </button>

          <div className="topbar-divider" />

          <div className="topbar-profile">
            <div className="topbar-avatar">
              {admin?.display_name?.charAt(0) || 'A'}
            </div>
            <div className="topbar-profile-info">
              <span className="topbar-profile-name">
                {admin?.display_name || 'Admin'}
              </span>
              <span className="topbar-profile-role">
                {admin?.role?.replace('_', ' ') || 'admin'}
              </span>
            </div>
          </div>

          <button
            className="btn btn-ghost btn-icon"
            onClick={signOut}
            title="Sign out"
            aria-label="Sign out"
          >
            <LogOut size={18} />
          </button>
        </div>
      </header>

      <SearchPalette {...search} />
    </>
  );
}
