// @vitest-environment jsdom
import { render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { MemoryRouter } from 'react-router-dom';

import { SearchPalette } from './SearchPalette';
import { TYPE_ICONS, type SearchResult } from '../../features/search/searchTypes';

describe('SearchPalette', () => {
  it('renders a visible error state when search fails', () => {
    const selectedResult: SearchResult = {
      id: 'user_1',
      type: 'user',
      title: 'Admin user',
      subtitle: 'viewer',
      route: '/users/user_1',
    };

    render(
      <MemoryRouter>
        <SearchPalette
          query="ham"
          setQuery={vi.fn()}
          groupedResults={{}}
          isOpen
          isLoading={false}
          error="Search is temporarily unavailable. Please try again."
          selectedIndex={0}
          setSelectedIndex={vi.fn()}
          close={vi.fn()}
          moveSelection={vi.fn()}
          getSelectedResult={() => selectedResult}
          TYPE_ICONS={TYPE_ICONS}
        />
      </MemoryRouter>,
    );

    expect(screen.getByRole('alert')).toBeTruthy();
    expect(
      screen.getByText('Search is temporarily unavailable. Please try again.'),
    ).toBeTruthy();
    expect(screen.queryByText(/No results for/)).toBeNull();
  });
});
