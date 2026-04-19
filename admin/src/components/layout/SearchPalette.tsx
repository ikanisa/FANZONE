import { Search } from 'lucide-react';
import { useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';

import type { GlobalSearchController } from '../../hooks/useGlobalSearch';

type SearchPaletteProps = Pick<
  GlobalSearchController,
  | 'query'
  | 'setQuery'
  | 'groupedResults'
  | 'isOpen'
  | 'isLoading'
  | 'selectedIndex'
  | 'setSelectedIndex'
  | 'close'
  | 'moveSelection'
  | 'getSelectedResult'
  | 'TYPE_ICONS'
>;

export function SearchPalette({
  query,
  setQuery,
  groupedResults,
  isOpen,
  isLoading,
  selectedIndex,
  setSelectedIndex,
  close,
  moveSelection,
  getSelectedResult,
  TYPE_ICONS,
}: SearchPaletteProps) {
  const navigate = useNavigate();
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isOpen && inputRef.current) {
      inputRef.current.focus();
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const handleKeyDown = (event: React.KeyboardEvent) => {
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      moveSelection('down');
      return;
    }

    if (event.key === 'ArrowUp') {
      event.preventDefault();
      moveSelection('up');
      return;
    }

    if (event.key === 'Enter') {
      event.preventDefault();
      const result = getSelectedResult();
      if (result) {
        navigate(result.route);
        close();
      }
      return;
    }

    if (event.key === 'Escape') {
      close();
    }
  };

  let flatIndex = 0;

  return (
    <div className="search-palette-overlay" onClick={close}>
      <div className="search-palette" onClick={(event) => event.stopPropagation()}>
        <div className="search-palette-input-row">
          <Search size={18} className="text-muted" />
          <input
            ref={inputRef}
            type="text"
            className="search-palette-input"
            placeholder="Search users, fixtures, pools, partners..."
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            onKeyDown={handleKeyDown}
          />
          <kbd className="search-palette-kbd">ESC</kbd>
        </div>

        {query.length > 0 && (
          <div className="search-palette-results">
            {isLoading && (
              <div className="search-palette-loading">
                <div className="skeleton" style={{ height: 16, width: '60%' }} />
                <div
                  className="skeleton"
                  style={{ height: 16, width: '40%', marginTop: 8 }}
                />
              </div>
            )}

            {!isLoading &&
              Object.keys(groupedResults).length === 0 &&
              query.length >= 2 && (
                <div className="search-palette-empty">
                  <p className="text-sm text-muted">No results for "{query}"</p>
                </div>
              )}

            {Object.entries(groupedResults).map(([type, items]) => (
              <div key={type}>
                <div className="search-palette-group-label">
                  {TYPE_ICONS[type as keyof typeof TYPE_ICONS] || '📄'} {type}s
                </div>
                {items.map((item) => {
                  const itemIndex = flatIndex++;
                  return (
                    <button
                      key={item.id}
                      className={`search-palette-item ${
                        itemIndex === selectedIndex
                          ? 'search-palette-item-active'
                          : ''
                      }`}
                      onClick={() => {
                        navigate(item.route);
                        close();
                      }}
                      onMouseEnter={() => setSelectedIndex(itemIndex)}
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
              <p className="text-sm text-muted">
                Start typing to search across users, fixtures, pools, rewards, and
                campaigns.
              </p>
              <div className="flex gap-4 mt-3 justify-center">
                <span className="text-xs text-muted">👤 Users</span>
                <span className="text-xs text-muted">⚽ Fixtures</span>
                <span className="text-xs text-muted">🎯 Pools</span>
                <span className="text-xs text-muted">🤝 Partners</span>
                <span className="text-xs text-muted">🎁 Rewards</span>
                <span className="text-xs text-muted">📢 Campaigns</span>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
