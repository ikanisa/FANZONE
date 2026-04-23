export type SearchResultType =
  | 'user'
  | 'competition'
  | 'fixture'
  | 'prediction'
  | 'wallet';

export interface SearchResult {
  id: string;
  type: SearchResultType;
  title: string;
  subtitle: string;
  route: string;
}

export const TYPE_ICONS: Record<SearchResultType, string> = {
  user: '👤',
  competition: '🏆',
  fixture: '⚽',
  prediction: '🎯',
  wallet: '👛',
};
