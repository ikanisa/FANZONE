import type { SupabaseClient } from '@supabase/supabase-js';
import { describe, expect, it, vi } from 'vitest';

import { searchEntities } from './searchClient';

describe('searchEntities', () => {
  it('delegates to the admin_global_search RPC and maps the result shape', async () => {
    const rpc = vi.fn().mockResolvedValue({
      data: [
        {
          result_id: 'user-1',
          result_type: 'user',
          title: 'Marco Spiteri',
          subtitle: 'marco@example.com',
          route: '/users?q=Marco',
        },
        {
          result_id: 'match-42',
          result_type: 'fixture',
          title: 'Valletta vs Floriana',
          subtitle: 'live — 2026-04-19',
          route: '/fixtures?q=Marco',
        },
      ],
      error: null,
    });

    const client = { rpc } as unknown as SupabaseClient;
    const results = await searchEntities(client, 'Marco');

    expect(rpc).toHaveBeenCalledWith('admin_global_search', {
      p_query: 'Marco',
      p_limit: 12,
    });
    expect(results).toEqual([
      {
        id: 'user-1',
        type: 'user',
        title: 'Marco Spiteri',
        subtitle: 'marco@example.com',
        route: '/users?q=Marco',
      },
      {
        id: 'match-42',
        type: 'fixture',
        title: 'Valletta vs Floriana',
        subtitle: 'live — 2026-04-19',
        route: '/fixtures?q=Marco',
      },
    ]);
  });

  it('throws when the RPC returns an error', async () => {
    const client = {
      rpc: vi.fn().mockResolvedValue({
        data: null,
        error: { message: 'boom' },
      }),
    } as unknown as SupabaseClient;

    await expect(searchEntities(client, 'Marco')).rejects.toThrow('boom');
  });
});
