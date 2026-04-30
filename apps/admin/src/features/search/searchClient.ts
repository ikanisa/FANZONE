import type { SupabaseClient } from '@supabase/supabase-js';

import type { SearchResult, SearchResultType } from './searchTypes';

interface AdminGlobalSearchRow {
  result_id: string;
  result_type: SearchResultType;
  title: string;
  subtitle: string;
  route: string;
}

export async function searchEntities(
  client: SupabaseClient,
  query: string,
): Promise<SearchResult[]> {
  const { data, error } = await client.rpc('admin_global_search', {
    p_query: query,
    p_limit: 12,
  });

  if (error) {
    throw new Error(error.message);
  }

  return ((data ?? []) as AdminGlobalSearchRow[]).map((row) => ({
    id: row.result_id,
    type: row.result_type,
    title: row.title,
    subtitle: row.subtitle,
    route: row.route,
  }));
}
