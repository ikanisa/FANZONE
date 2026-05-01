export type SearchResultType =
  | 'user'
  | 'venue'
  | 'country'
  | 'competition'
  | 'team'
  | 'fixture'
  | 'pool'
  | 'wallet';

export interface SearchResult {
  id: string;
  type: SearchResultType;
  title: string;
  subtitle: string;
  route: string;
}

export const TYPE_ICONS: Record<SearchResultType, string> = {
  user: 'Wallet User',
  venue: 'Venue',
  country: 'Country',
  competition: 'Competition',
  team: 'Team',
  fixture: 'Match',
  pool: 'Pool',
  wallet: 'Wallet',
};
