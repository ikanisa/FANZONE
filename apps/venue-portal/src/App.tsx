import { lazy, Suspense, useState, type FormEvent, type ReactNode } from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AppShell } from "./components/layout/AppShell";
import { VenueProvider } from "./hooks/useVenueContext";
import { VenueAuthProvider, useVenueAuth } from "./hooks/useVenueAuth";
import { isSupabaseConfigured, venueEnvError } from "./lib/supabase";
import {
  BuyFetPage,
  CreatePoolPage,
  GameControlPage,
  GamesPage,
  MenuItemEditorPage,
  NotificationsPage,
  ParticipantsPage,
  PoolDetailPage,
  PoolSettlementPage,
  ScreenControlPage,
  SettingsSubsectionPage,
  StaffPermissionsPage,
  StartGamePage,
  TeamDetailPage,
  TeamsPage,
  WalletLedgerPage,
  WalletPage,
} from "./features/target/TargetPages";

const DashboardPage = lazy(() =>
  import("./features/dashboard/DashboardPage").then((module) => ({
    default: module.DashboardPage,
  })),
);
const OverviewPage = lazy(() =>
  import("./features/overview/OverviewPage").then((module) => ({
    default: module.OverviewPage,
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
const OrderDetailPage = lazy(() =>
  import("./features/orders/OrderDetailPage").then((module) => ({
    default: module.OrderDetailPage,
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

function VenueLoginPage() {
  const { requestOtp, verifyOtp, isLoading, error } = useVenueAuth();
  const [phone, setPhone] = useState("");
  const [sentPhone, setSentPhone] = useState("");
  const [otp, setOtp] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSend = async (event: FormEvent) => {
    event.preventDefault();
    setIsSubmitting(true);
    const sent = await requestOtp(phone);
    if (sent) {
      setSentPhone(phone);
      setOtp("");
    }
    setIsSubmitting(false);
  };

  const handleVerify = async (event: FormEvent) => {
    event.preventDefault();
    if (otp.length !== 6) return;
    setIsSubmitting(true);
    await verifyOtp(sentPhone || phone, otp);
    setIsSubmitting(false);
  };

  return (
    <main className="min-h-screen bg-bg text-text flex items-center justify-center p-6">
      <section className="w-full max-w-md rounded-[28px] border border-border bg-surface p-8 shadow-2xl shadow-black/30">
        <p className="text-xs font-black uppercase tracking-widest text-primary">
          Venue Console
        </p>
        <h1 className="mt-3 text-3xl font-black tracking-tight">
          Sign in with WhatsApp
        </h1>
        <p className="mt-3 text-sm leading-6 text-textSecondary font-bold">
          Staff access uses the same WhatsApp OTP session as FANZONE admin.
        </p>

        <form className="mt-8 space-y-4" onSubmit={sentPhone ? handleVerify : handleSend}>
          <label className="block">
            <span className="text-xs font-black uppercase tracking-widest text-textSecondary">
              WhatsApp phone
            </span>
            <input
              className="mt-2 min-h-14 w-full rounded-2xl border border-border bg-surface2 px-4 font-black text-text outline-none focus:border-primary"
              value={phone}
              onChange={(event) => setPhone(event.target.value)}
              placeholder="+356 ..."
              autoComplete="tel"
              disabled={Boolean(sentPhone)}
            />
          </label>

          {sentPhone && (
            <label className="block">
              <span className="text-xs font-black uppercase tracking-widest text-textSecondary">
                OTP code
              </span>
              <input
                className="mt-2 min-h-14 w-full rounded-2xl border border-border bg-surface2 px-4 text-center text-2xl font-black tracking-[0.35em] text-text outline-none focus:border-primary"
                value={otp}
                onChange={(event) => setOtp(event.target.value.replace(/\D/g, "").slice(0, 6))}
                placeholder="000000"
                inputMode="numeric"
                autoComplete="one-time-code"
              />
            </label>
          )}

          {error && (
            <p className="rounded-2xl border border-danger/30 bg-danger/10 px-4 py-3 text-sm font-bold text-danger">
              {error}
            </p>
          )}

          <button
            type="submit"
            disabled={isSubmitting || isLoading || !phone || (Boolean(sentPhone) && otp.length !== 6)}
            className="min-h-14 w-full rounded-2xl bg-primary px-5 font-black text-primaryText disabled:cursor-not-allowed disabled:opacity-50"
          >
            {sentPhone ? "VERIFY OTP" : "SEND OTP"}
          </button>

          {sentPhone && (
            <button
              type="button"
              onClick={() => {
                setSentPhone("");
                setOtp("");
              }}
              className="min-h-12 w-full rounded-2xl bg-surface2 px-5 font-black text-textSecondary"
            >
              CHANGE PHONE
            </button>
          )}
        </form>
      </section>
    </main>
  );
}

function VenueRoutes() {
  const { session, isLoading } = useVenueAuth();

  if (isLoading) {
    return <PageLoading />;
  }

  if (!session) {
    return <VenueLoginPage />;
  }

  return (
    <VenueProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<AppShell />}>
            <Route index element={<Navigate to="/overview" replace />} />
            <Route path="overview" element={lazyPage(<OverviewPage />)} />
            <Route path="orders" element={lazyPage(<LiveOrderQueuePage />)} />
            <Route path="orders/:orderId" element={lazyPage(<OrderDetailPage />)} />
            <Route path="menu" element={lazyPage(<MenuArchitectPage />)} />
            <Route path="menu/items/new" element={<MenuItemEditorPage />} />
            <Route path="menu/items/:itemId" element={<MenuItemEditorPage />} />
            <Route path="pools" element={lazyPage(<VenuePoolsPage />)} />
            <Route path="pools/new" element={<CreatePoolPage />} />
            <Route path="pools/:poolId" element={<PoolDetailPage />} />
            <Route path="pools/:poolId/settle" element={<PoolSettlementPage />} />
            <Route path="games" element={<GamesPage />} />
            <Route path="games/new" element={<StartGamePage />} />
            <Route path="games/:sessionId/control" element={<GameControlPage />} />
            <Route path="teams" element={<TeamsPage />} />
            <Route path="teams/:teamId" element={<TeamDetailPage />} />
            <Route path="participants" element={<ParticipantsPage />} />
            <Route path="screen" element={<ScreenControlPage />} />
            <Route path="wallet" element={<WalletPage />} />
            <Route path="wallet/buy" element={<BuyFetPage />} />
            <Route path="wallet/ledger" element={<WalletLedgerPage />} />
            <Route path="insights" element={lazyPage(<DashboardPage />)} />
            <Route path="settings" element={lazyPage(<VenueSettingsPage />)} />
            <Route path="settings/profile" element={<SettingsSubsectionPage />} />
            <Route path="settings/payments" element={<SettingsSubsectionPage />} />
            <Route path="settings/permissions" element={<StaffPermissionsPage />} />
            <Route path="settings/screen" element={<SettingsSubsectionPage />} />
            <Route path="settings/fet-rewards" element={lazyPage(<FETRewardsPage />)} />
            <Route path="settings/tables" element={lazyPage(<QRFactoryPage />)} />
            <Route path="notifications" element={<NotificationsPage />} />
            <Route path="rewards" element={<Navigate to="/settings/fet-rewards" replace />} />
            <Route path="tables" element={<Navigate to="/settings/tables" replace />} />
          </Route>

          <Route path="*" element={<Navigate to="/overview" replace />} />
        </Routes>
      </BrowserRouter>
    </VenueProvider>
  );
}

function App() {
  if (!isSupabaseConfigured) {
    return <ConfigurationError />;
  }

  return (
    <VenueAuthProvider>
      <VenueRoutes />
    </VenueAuthProvider>
  );
}

export default App;
