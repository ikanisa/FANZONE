import { lazy, Suspense, type ReactNode } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AppShell } from './components/layout/AppShell';
import { VenueProvider } from './hooks/useVenueContext';

const DashboardPage = lazy(() =>
  import('./features/dashboard/DashboardPage').then((module) => ({
    default: module.DashboardPage,
  }))
);
const MenuArchitectPage = lazy(() =>
  import('./features/menu/MenuArchitectPage').then((module) => ({
    default: module.MenuArchitectPage,
  }))
);
const LiveOrderQueuePage = lazy(() =>
  import('./features/orders/LiveOrderQueuePage').then((module) => ({
    default: module.LiveOrderQueuePage,
  }))
);
const VenuePoolsPage = lazy(() =>
  import('./features/pools/VenuePoolsPage').then((module) => ({
    default: module.VenuePoolsPage,
  }))
);
const FETRewardsPage = lazy(() =>
  import('./features/rewards/FETRewardsPage').then((module) => ({
    default: module.FETRewardsPage,
  }))
);
const QRFactoryPage = lazy(() =>
  import('./features/settings/QRFactoryPage').then((module) => ({
    default: module.QRFactoryPage,
  }))
);
const VenueSettingsPage = lazy(() =>
  import('./features/settings/VenueSettingsPage').then((module) => ({
    default: module.VenueSettingsPage,
  }))
);

function PageLoading() {
  return (
    <div className="min-h-[320px] flex items-center justify-center">
      <div className="h-10 w-10 rounded-full border-4 border-border border-t-primary animate-spin" />
    </div>
  );
}

function lazyPage(page: ReactNode) {
  return <Suspense fallback={<PageLoading />}>{page}</Suspense>;
}

function App() {
  return (
    <VenueProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<AppShell />}>
            <Route index element={<Navigate to="/orders" replace />} />
            <Route path="orders" element={lazyPage(<LiveOrderQueuePage />)} />
            <Route path="menu" element={lazyPage(<MenuArchitectPage />)} />
            <Route path="pools" element={lazyPage(<VenuePoolsPage />)} />
            <Route path="rewards" element={lazyPage(<FETRewardsPage />)} />
            <Route path="tables" element={lazyPage(<QRFactoryPage />)} />
            <Route path="insights" element={lazyPage(<DashboardPage />)} />
            <Route path="settings" element={lazyPage(<VenueSettingsPage />)} />
          </Route>

          <Route path="*" element={<Navigate to="/orders" replace />} />
        </Routes>
      </BrowserRouter>
    </VenueProvider>
  );
}

export default App;
