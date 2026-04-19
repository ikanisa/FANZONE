export type SearchResultType =
  | 'user'
  | 'fixture'
  | 'pool'
  | 'partner'
  | 'reward'
  | 'campaign';

export interface SearchResult {
  id: string;
  type: SearchResultType;
  title: string;
  subtitle: string;
  route: string;
}

export const TYPE_ICONS: Record<SearchResultType, string> = {
  user: '👤',
  fixture: '⚽',
  pool: '🎯',
  partner: '🤝',
  reward: '🎁',
  campaign: '📢',
};
