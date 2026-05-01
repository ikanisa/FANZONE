import { lazy, Suspense, type ReactNode } from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AppShell } from "./components/layout/AppShell";
import { VenueProvider } from "./hooks/useVenueContext";
import { isSupabaseConfigured, venueEnvError } from "./lib/supabase";

const DashboardPage = lazy(() =>
  import("./features/dashboard/DashboardPage").then((module) => ({
    default: module.DashboardPage,
  })),
);
const MenuArchitectPage = lazy(() =>
  import("./features/menu/MenuArchitectPage").then((module) => ({
    default: module.MenuArchitectPage,
  })),
);
const LiveOrderQueuePage = lazy(() =>
  import("./features/orders/LiveOrderQueuePage").then((module) => ({
    default: module.LiveOrderQueuePage,
  })),
);
const VenuePoolsPage = lazy(() =>
  import("./features/pools/VenuePoolsPage").then((module) => ({
    default: module.VenuePoolsPage,
  })),
);
const FETRewardsPage = lazy(() =>
  import("./features/rewards/FETRewardsPage").then((module) => ({
    default: module.FETRewardsPage,
  })),
);
const QRFactoryPage = lazy(() =>
  import("./features/settings/QRFactoryPage").then((module) => ({
    default: module.QRFactoryPage,
  })),
);
const VenueSettingsPage = lazy(() =>
  import("./features/settings/VenueSettingsPage").then((module) => ({
    default: module.VenueSettingsPage,
  })),
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

function ConfigurationError() {
  return (
    <main className="min-h-screen bg-bg text-text flex items-center justify-center p-6">
      <section className="w-full max-w-md rounded-2xl border border-border bg-surface p-8 shadow-2xl shadow-black/30">
        <p className="text-[10px] font-black uppercase tracking-widest text-textSecondary">
          Configuration
        </p>
        <h1 className="mt-3 text-2xl font-black tracking-tight">
          Venue portal is unavailable
        </h1>
        <p className="mt-4 text-sm leading-6 text-textSecondary">
          {venueEnvError}
        </p>
      </section>
    </main>
  );
}

function App() {
  if (!isSupabaseConfigured) {
    return <ConfigurationError />;
  }

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
