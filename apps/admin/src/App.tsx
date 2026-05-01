// FANZONE Admin — App Router (with lazy-loaded heavy routes)
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { lazy, Suspense } from 'react';
import { AppShell } from './components/layout/AppShell';
import { AuthGuard } from './features/auth/AuthGuard';
import { RoleGuard } from './features/auth/RoleGuard';
import { LoginPage } from './features/auth/LoginPage';
import { LoadingState } from './components/ui/StateViews';
import { useAuth } from './hooks/useAuth';
import { ROUTES } from './config/routes';

function lazyPage<T extends Record<string, React.ComponentType>>(
  importer: () => Promise<T>,
  exportName: keyof T,
) {
  return lazy(async () => {
    const module = await importer();
    return { default: module[exportName] };
  });
}

const DashboardPage = lazyPage(
  () => import('./features/dashboard/DashboardPage'),
  'DashboardPage',
);
const CountriesPage = lazyPage(
  () => import('./features/countries/CountriesPage'),
  'CountriesPage',
);
const VenuesPage = lazyPage(
  () => import('./features/venues/VenuesPage'),
  'VenuesPage',
);
const CompetitionsPage = lazyPage(
  () => import('./features/competitions/CompetitionsPage'),
  'CompetitionsPage',
);
const TeamsPage = lazyPage(
  () => import('./features/teams/TeamsPage'),
  'TeamsPage',
);
const MatchCurationPage = lazyPage(
  () => import('./features/match-curation/MatchCurationPage'),
  'MatchCurationPage',
);
const PoolOperationsPage = lazyPage(
  () => import('./features/pool-operations/PoolOperationsPage'),
  'PoolOperationsPage',
);
const WalletOversightPage = lazyPage(
  () => import('./features/wallets/WalletOversightPage'),
  'WalletOversightPage',
);
const RewardRulesPage = lazyPage(
  () => import('./features/reward-rules/RewardRulesPage'),
  'RewardRulesPage',
);
const ModerationPage = lazyPage(
  () => import('./features/moderation/ModerationPage'),
  'ModerationPage',
);
const PlatformControlPage = lazyPage(
  () => import('./features/platform-control/PlatformControlPage'),
  'PlatformControlPage',
);
const AuditLogsPage = lazyPage(
  () => import('./features/audit-logs/AuditLogsPage'),
  'AuditLogsPage',
);

function LazyRoute({ children }: { children: React.ReactNode }) {
  return <Suspense fallback={<LoadingState lines={8} />}>{children}</Suspense>;
}

function ProtectedRoutes() {
  return (
    <AuthGuard>
      <Routes>
        <Route element={<AppShell />}>
          <Route path={ROUTES.OVERVIEW} element={<LazyRoute><DashboardPage /></LazyRoute>} />
          <Route path={ROUTES.COUNTRIES} element={<RoleGuard minRole="admin"><LazyRoute><CountriesPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.VENUES} element={<RoleGuard minRole="admin"><LazyRoute><VenuesPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.COMPETITIONS} element={<RoleGuard minRole="admin"><LazyRoute><CompetitionsPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.TEAMS} element={<RoleGuard minRole="admin"><LazyRoute><TeamsPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.CURATED_MATCHES} element={<RoleGuard minRole="admin"><LazyRoute><MatchCurationPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.POOLS} element={<RoleGuard minRole="admin"><LazyRoute><PoolOperationsPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.FET_WALLETS} element={<RoleGuard minRole="admin"><LazyRoute><WalletOversightPage /></LazyRoute></RoleGuard>} />
          <Route
            path={ROUTES.SETTLEMENTS}
            element={
              <RoleGuard minRole="admin">
                <LazyRoute>
                  <PoolOperationsPage
                    title="Settlements"
                    subtitle="Pool settlement queue, failed settlements, and final result processing."
                  />
                </LazyRoute>
              </RoleGuard>
            }
          />
          <Route path={ROUTES.REWARD_RULES} element={<RoleGuard minRole="admin"><LazyRoute><RewardRulesPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.RISK_ABUSE} element={<RoleGuard minRole="moderator"><LazyRoute><ModerationPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.FEATURE_FLAGS} element={<RoleGuard minRole="admin"><LazyRoute><PlatformControlPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.AUDIT_LOGS} element={<RoleGuard minRole="admin"><LazyRoute><AuditLogsPage /></LazyRoute></RoleGuard>} />
          <Route path="*" element={<Navigate to={ROUTES.OVERVIEW} replace />} />
        </Route>
      </Routes>
    </AuthGuard>
  );
}

export function App() {
  const { admin } = useAuth();

  return (
    <BrowserRouter>
      <Routes>
        <Route path={ROUTES.LOGIN} element={admin ? <Navigate to={ROUTES.OVERVIEW} replace /> : <LoginPage />} />
        <Route path="/*" element={<ProtectedRoutes />} />
      </Routes>
    </BrowserRouter>
  );
}
