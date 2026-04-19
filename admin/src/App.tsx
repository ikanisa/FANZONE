// FANZONE Admin — App Router (with lazy-loaded heavy routes)
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { lazy, Suspense } from 'react';
import { AppShell } from './components/layout/AppShell';
import { AuthGuard } from './features/auth/AuthGuard';
import { RoleGuard } from './features/auth/RoleGuard';
import { LoginPage } from './features/auth/LoginPage';
import { DashboardPage } from './features/dashboard/DashboardPage';
import { UsersPage } from './features/users/UsersPage';
import { CompetitionsPage } from './features/competitions/CompetitionsPage';
import { FixturesPage } from './features/fixtures/FixturesPage';
import { PredictionsPage } from './features/predictions/PredictionsPage';
import { ChallengesPage } from './features/challenges/ChallengesPage';
import { EventsPage } from './features/events/EventsPage';
import { WalletOversightPage } from './features/wallets/WalletOversightPage';
import { PartnersPage } from './features/partners/PartnersPage';
import { RewardsPage } from './features/rewards/RewardsPage';
import { RedemptionsPage } from './features/redemptions/RedemptionsPage';
import { ContentPage } from './features/content/ContentPage';
import { ModerationPage } from './features/moderation/ModerationPage';
import { SettingsPage } from './features/settings/SettingsPage';
import { AdminAccessPage } from './features/admin-access/AdminAccessPage';
import { AccountDeletionRequestsPage } from './features/account-deletions/AccountDeletionRequestsPage';
import { LoadingState } from './components/ui/StateViews';
import { useAuth } from './hooks/useAuth';
import { ROUTES } from './config/routes';

/* ── Lazy-loaded heavy routes (Recharts, CSV export, etc.) ── */
const AnalyticsPage = lazy(() => import('./features/analytics/AnalyticsPage').then(m => ({ default: m.AnalyticsPage })));
const AuditLogsPage = lazy(() => import('./features/audit-logs/AuditLogsPage').then(m => ({ default: m.AuditLogsPage })));
const TokenOpsPage = lazy(() => import('./features/tokens/TokenOpsPage').then(m => ({ default: m.TokenOpsPage })));
const NotificationsPage = lazy(() => import('./features/notifications/NotificationsPage').then(m => ({ default: m.NotificationsPage })));

function LazyRoute({ children }: { children: React.ReactNode }) {
  return <Suspense fallback={<LoadingState lines={8} />}>{children}</Suspense>;
}

function ProtectedRoutes() {
  return (
    <AuthGuard>
      <Routes>
        <Route element={<AppShell />}>
          {/* Overview */}
          <Route path={ROUTES.DASHBOARD} element={<DashboardPage />} />

          {/* Platform */}
          <Route path={ROUTES.USERS} element={<RoleGuard minRole="admin"><UsersPage /></RoleGuard>} />
          <Route path={ROUTES.COMPETITIONS} element={<RoleGuard minRole="admin"><CompetitionsPage /></RoleGuard>} />
          <Route path={ROUTES.FIXTURES} element={<RoleGuard minRole="moderator"><FixturesPage /></RoleGuard>} />
          <Route path={ROUTES.PREDICTIONS} element={<RoleGuard minRole="admin"><PredictionsPage /></RoleGuard>} />
          <Route path={ROUTES.CHALLENGES} element={<RoleGuard minRole="moderator"><ChallengesPage /></RoleGuard>} />
          <Route path={ROUTES.EVENTS} element={<RoleGuard minRole="admin"><EventsPage /></RoleGuard>} />

          {/* Finance */}
          <Route path={ROUTES.TOKENS} element={<RoleGuard minRole="admin"><LazyRoute><TokenOpsPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.WALLETS} element={<RoleGuard minRole="admin"><WalletOversightPage /></RoleGuard>} />
          <Route path={ROUTES.PARTNERS} element={<RoleGuard minRole="admin"><PartnersPage /></RoleGuard>} />
          <Route path={ROUTES.REWARDS} element={<RoleGuard minRole="admin"><RewardsPage /></RoleGuard>} />
          <Route path={ROUTES.REDEMPTIONS} element={<RoleGuard minRole="moderator"><RedemptionsPage /></RoleGuard>} />

          {/* Operations */}
          <Route path={ROUTES.CONTENT} element={<RoleGuard minRole="admin"><ContentPage /></RoleGuard>} />
          <Route path={ROUTES.MODERATION} element={<RoleGuard minRole="moderator"><ModerationPage /></RoleGuard>} />
          <Route path={ROUTES.ANALYTICS} element={<RoleGuard minRole="viewer"><LazyRoute><AnalyticsPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.NOTIFICATIONS} element={<RoleGuard minRole="admin"><LazyRoute><NotificationsPage /></LazyRoute></RoleGuard>} />
          <Route path={ROUTES.ACCOUNT_DELETIONS} element={<RoleGuard minRole="admin"><AccountDeletionRequestsPage /></RoleGuard>} />

          {/* System */}
          <Route path={ROUTES.SETTINGS} element={<RoleGuard minRole="super_admin"><SettingsPage /></RoleGuard>} />
          <Route path={ROUTES.ADMIN_ACCESS} element={<RoleGuard minRole="super_admin"><AdminAccessPage /></RoleGuard>} />
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
