// FANZONE Admin — Topbar with Global Search Palette
import { useAuth } from '../../hooks/useAuth';
import { useGlobalSearch } from '../../hooks/useGlobalSearch';
import { Bell, Search, LogOut, Command } from 'lucide-react';
import { useRef, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

function SearchPalette() {
  const {
    query, setQuery, groupedResults, isOpen, isLoading,
    selectedIndex, setSelectedIndex, close, moveSelection,
    getSelectedResult, TYPE_ICONS,
  } = useGlobalSearch();
  const navigate = useNavigate();
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isOpen && inputRef.current) {
      inputRef.current.focus();
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowDown') { e.preventDefault(); moveSelection('down'); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); moveSelection('up'); }
    else if (e.key === 'Enter') {
      e.preventDefault();
      const result = getSelectedResult();
      if (result) { navigate(result.route); close(); }
    }
    else if (e.key === 'Escape') { close(); }
  };

  let flatIdx = 0;

  return (
    <div className="search-palette-overlay" onClick={close}>
      <div className="search-palette" onClick={e => e.stopPropagation()}>
        <div className="search-palette-input-row">
          <Search size={18} className="text-muted" />
          <input
            ref={inputRef}
            type="text"
            className="search-palette-input"
            placeholder="Search users, fixtures, pools, partners..."
            value={query}
            onChange={e => setQuery(e.target.value)}
            onKeyDown={handleKeyDown}
          />
          <kbd className="search-palette-kbd">ESC</kbd>
        </div>

        {query.length > 0 && (
          <div className="search-palette-results">
            {isLoading && (
              <div className="search-palette-loading">
                <div className="skeleton" style={{ height: 16, width: '60%' }} />
                <div className="skeleton" style={{ height: 16, width: '40%', marginTop: 8 }} />
              </div>
            )}

            {!isLoading && Object.keys(groupedResults).length === 0 && query.length >= 2 && (
              <div className="search-palette-empty">
                <p className="text-sm text-muted">No results for "{query}"</p>
              </div>
            )}

            {Object.entries(groupedResults).map(([type, items]) => (
              <div key={type}>
                <div className="search-palette-group-label">
                  {TYPE_ICONS[type as keyof typeof TYPE_ICONS] || '📄'} {type}s
                </div>
                {items.map(item => {
                  const idx = flatIdx++;
                  return (
                    <button
                      key={item.id}
                      className={`search-palette-item ${idx === selectedIndex ? 'search-palette-item-active' : ''}`}
                      onClick={() => { navigate(item.route); close(); }}
                      onMouseEnter={() => setSelectedIndex(idx)}
                    >
                      <div className="search-palette-item-content">
                        <span className="font-medium">{item.title}</span>
                        <span className="text-xs text-muted">{item.subtitle}</span>
                      </div>
                      <span className="text-xs text-muted mono">{item.id}</span>
                    </button>
                  );
                })}
              </div>
            ))}
          </div>
        )}

        {query.length === 0 && (
          <div className="search-palette-results">
            <div className="search-palette-empty">
              <p className="text-sm text-muted">Start typing to search across all entities...</p>
              <div className="flex gap-4 mt-3 justify-center">
                <span className="text-xs text-muted">👤 Users</span>
                <span className="text-xs text-muted">⚽ Fixtures</span>
                <span className="text-xs text-muted">🎯 Pools</span>
                <span className="text-xs text-muted">🤝 Partners</span>
                <span className="text-xs text-muted">🎁 Rewards</span>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export function Topbar() {
  const { admin, signOut } = useAuth();
  const { open: openSearch } = useGlobalSearch();

  return (
    <>
      <header className="topbar">
        <button className="topbar-search-trigger" onClick={openSearch}>
          <Search size={16} className="topbar-search-icon" />
          <span className="topbar-search-placeholder">Search anything...</span>
          <kbd className="topbar-kbd"><Command size={11} />K</kbd>
        </button>

        <div className="topbar-actions">
          <button className="btn btn-ghost btn-icon topbar-notification" aria-label="Notifications">
            <Bell size={18} />
            <span className="topbar-notification-dot" />
          </button>

          <div className="topbar-divider" />

          <div className="topbar-profile">
            <div className="topbar-avatar">{admin?.display_name?.charAt(0) || 'A'}</div>
            <div className="topbar-profile-info">
              <span className="topbar-profile-name">{admin?.display_name || 'Admin'}</span>
              <span className="topbar-profile-role">{admin?.role?.replace('_', ' ') || 'admin'}</span>
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

        <style>{`
          .topbar {
            height: var(--fz-topbar-h);
            background: var(--fz-surface);
            border-bottom: 1px solid var(--fz-border);
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0 var(--fz-sp-6);
            position: sticky;
            top: 0;
            z-index: 20;
          }
          .topbar-search-trigger {
            display: flex;
            align-items: center;
            gap: var(--fz-sp-2);
            background: var(--fz-surface-2);
            border: 1px solid var(--fz-border);
            border-radius: var(--fz-radius);
            padding: var(--fz-sp-2) var(--fz-sp-3);
            width: 360px;
            transition: border-color var(--fz-transition);
            cursor: pointer;
          }
          .topbar-search-trigger:hover {
            border-color: var(--fz-border-2);
          }
          .topbar-search-icon { color: var(--fz-muted-2); flex-shrink: 0; }
          .topbar-search-placeholder {
            font-size: var(--fz-text-sm);
            color: var(--fz-muted-2);
            flex: 1;
            text-align: left;
          }
          .topbar-kbd {
            display: inline-flex;
            align-items: center;
            gap: 2px;
            font-size: 10px;
            font-family: var(--fz-mono);
            background: var(--fz-surface-3);
            border: 1px solid var(--fz-border-2);
            border-radius: 4px;
            padding: 1px 5px;
            color: var(--fz-muted);
            line-height: 1.6;
          }
          .topbar-actions {
            display: flex;
            align-items: center;
            gap: var(--fz-sp-3);
          }
          .topbar-notification { position: relative; }
          .topbar-notification-dot {
            position: absolute;
            top: 6px;
            right: 6px;
            width: 7px;
            height: 7px;
            background: var(--fz-malta-red);
            border-radius: 50%;
            border: 2px solid var(--fz-surface);
          }
          .topbar-divider {
            width: 1px;
            height: 24px;
            background: var(--fz-border);
          }
          .topbar-profile {
            display: flex;
            align-items: center;
            gap: var(--fz-sp-2);
          }
          .topbar-avatar {
            width: 28px;
            height: 28px;
            background: linear-gradient(135deg, var(--fz-accent), var(--fz-accent-dark));
            border-radius: var(--fz-radius-full);
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 600;
            font-size: 11px;
            color: #fff;
          }
          .topbar-profile-info {
            display: flex;
            flex-direction: column;
            line-height: 1.2;
          }
          .topbar-profile-name { font-size: var(--fz-text-sm); font-weight: 600; }
          .topbar-profile-role { font-size: var(--fz-text-xs); color: var(--fz-muted); text-transform: capitalize; }

          /* ── Search Palette ── */
          .search-palette-overlay {
            position: fixed;
            inset: 0;
            background: rgba(0, 0, 0, 0.65);
            z-index: 100;
            display: flex;
            align-items: flex-start;
            justify-content: center;
            padding-top: 15vh;
            animation: fade-in 100ms ease;
          }
          .search-palette {
            background: var(--fz-surface);
            border: 1px solid var(--fz-border-2);
            border-radius: var(--fz-radius-lg);
            width: 580px;
            max-width: calc(100vw - 32px);
            max-height: 480px;
            overflow: hidden;
            box-shadow: 0 24px 48px -12px rgba(0, 0, 0, 0.4);
            animation: scale-in 150ms ease;
          }
          .search-palette-input-row {
            display: flex;
            align-items: center;
            gap: var(--fz-sp-3);
            padding: var(--fz-sp-4);
            border-bottom: 1px solid var(--fz-border);
          }
          .search-palette-input {
            flex: 1;
            border: none;
            background: transparent;
            font-size: var(--fz-text-base);
            color: var(--fz-text);
            outline: none;
          }
          .search-palette-input::placeholder { color: var(--fz-muted-2); }
          .search-palette-kbd {
            display: inline-flex;
            align-items: center;
            font-size: 10px;
            font-family: var(--fz-mono);
            background: var(--fz-surface-2);
            border: 1px solid var(--fz-border-2);
            border-radius: 4px;
            padding: 2px 6px;
            color: var(--fz-muted);
          }
          .search-palette-results {
            overflow-y: auto;
            max-height: 380px;
            padding: var(--fz-sp-2);
          }
          .search-palette-group-label {
            font-size: var(--fz-text-xs);
            font-weight: 600;
            color: var(--fz-muted);
            text-transform: uppercase;
            letter-spacing: 0.05em;
            padding: var(--fz-sp-2) var(--fz-sp-3);
            margin-top: var(--fz-sp-1);
          }
          .search-palette-item {
            display: flex;
            align-items: center;
            justify-content: space-between;
            width: 100%;
            padding: var(--fz-sp-2) var(--fz-sp-3);
            border-radius: var(--fz-radius);
            transition: background 80ms ease;
            text-align: left;
          }
          .search-palette-item:hover,
          .search-palette-item-active {
            background: var(--fz-surface-2);
          }
          .search-palette-item-content {
            display: flex;
            flex-direction: column;
            gap: 1px;
          }
          .search-palette-empty,
          .search-palette-loading {
            padding: var(--fz-sp-6) var(--fz-sp-4);
            text-align: center;
          }
        `}</style>
      </header>

      <SearchPalette />
    </>
  );
}
