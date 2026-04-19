export interface PaginatedResult<T> {
  data: T[];
  count: number;
  page: number;
  pageSize: number;
}

export interface DashboardKpi {
  label: string;
  value: number;
  trend?: number;
  trendDirection?: 'up' | 'down' | 'neutral';
  icon?: string;
}
