// FANZONE Admin — App Router (with lazy-loaded heavy routes)
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
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
const UsersPage = lazyPage(
  () => import('./features/users/UsersPage'),
  'UsersPage',
);
const CompetitionsPage = lazyPage(
  () => import('./features/competitions/CompetitionsPage'),
  'CompetitionsPage',
);
const FixturesPage = lazyPage(
  () => import('./features/fixtures/FixturesPage'),
  'FixturesPage',
);
const PredictionsPage = lazyPage(
  () => import('./features/predictions/PredictionsPage'),
  'PredictionsPage',
);
const WalletOversightPage = lazyPage(
  () => import('./features/wallets/WalletOversightPage'),
  'WalletOversightPage',
);
const ModerationPage = lazyPage(
  () => import('./features/moderation/ModerationPage'),
  'ModerationPage',
);
const SettingsPage = lazyPage(
  () => import('./features/settings/SettingsPage'),
  'SettingsPage',
);
const AdminAccessPage = lazyPage(
  () => import('./features/admin-access/AdminAccessPage'),
  'AdminAccessPage',
);
const AccountDeletionRequestsPage = lazyPage(
  () => import('./features/account-deletions/AccountDeletionRequestsPage'),
  'AccountDeletionRequestsPage',
);
const AnalyticsPage = lazyPage(
  () => import('./features/analytics/AnalyticsPage'),
  'AnalyticsPage',
);
const AuditLogsPage = lazyPage(
  () => import('./features/audit-logs/AuditLogsPage'),
  'AuditLogsPage',
);
const TokenOpsPage = lazyPage(
  () => import('./features/tokens/TokenOpsPage'),
  'TokenOpsPage',
);

function LazyRoute({ children }: { children: React.ReactNode }) {
  return <Suspense fallback={<LoadingState lines={8} />}>{children}</Suspense>;
}

function ProtectedRoutes() {
  return (
    <AuthGuard>
      <Routes>
        <Route element={<AppShell />}>
          {/* Overview */}
          <Route path={ROUTES.DASHBOARD} element={<LazyRoute><DashboardPage /></LazyRoute>} />

          {/* Platform */}
          <Route path={ROUTES.USERS} element={<RoleGuard minRole="admin"><LazyRoute><UsersPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.COMPETITIONS} element={<RoleGuard minRole="admin"><LazyRoute><CompetitionsPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.FIXTURES} element={<RoleGuard minRole="moderator"><LazyRoute><FixturesPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.PREDICTIONS} element={<RoleGuard minRole="admin"><LazyRoute><PredictionsPage /></LazyRoute></RoleGuard>} />

          {/* Finance */}
          <Route path={ROUTES.TOKENS} element={<RoleGuard minRole="admin"><LazyRoute><TokenOpsPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.WALLETS} element={<RoleGuard minRole="admin"><LazyRoute><WalletOversightPage /></LazyRoute></RoleGuard>} />

          {/* Operations */}
          <Route path={ROUTES.MODERATION} element={<RoleGuard minRole="moderator"><LazyRoute><ModerationPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.ANALYTICS} element={<RoleGuard minRole="viewer"><LazyRoute><AnalyticsPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.ACCOUNT_DELETIONS} element={<RoleGuard minRole="admin"><LazyRoute><AccountDeletionRequestsPage /></LazyRoute></RoleGuard>} />

          {/* System */}
          <Route path={ROUTES.SETTINGS} element={<RoleGuard minRole="super_admin"><LazyRoute><SettingsPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.ADMIN_ACCESS} element={<RoleGuard minRole="super_admin"><LazyRoute><AdminAccessPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.AUDIT_LOGS} element={<RoleGuard minRole="admin"><LazyRoute><AuditLogsPage /></LazyRoute></RoleGuard>} />

          {/* Fallback */}
          <Route path="*" element={<Navigate to={ROUTES.DASHBOARD} replace />} />
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
        <Route path={ROUTES.LOGIN} element={admin ? <Navigate to={ROUTES.DASHBOARD} replace /> : <LoginPage />} />
        <Route path="/*" element={<ProtectedRoutes />} />
      </Routes>
    </BrowserRouter>
  );
}
