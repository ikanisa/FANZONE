import type { ReactNode } from "react";
import {
  Settings as SettingsIcon,
  Bell,
  ChevronRight,
  LogOut,
  MessageCircle,
  Trophy,
  Wallet,
  Fingerprint,
  Lock,
} from "lucide-react";
import { Link } from "react-router-dom";
import { useAppStore } from "../store/useAppStore";
import { FETDisplay } from "./ui/FETDisplay";
import {
  getPlatformFeatureRoute,
  isPlatformFeatureVisible,
} from "../platform/access";
import { usePlatformBootstrap } from "../platform/bootstrap";

export default function Profile() {
  usePlatformBootstrap();
  const {
    fanId,
    fetBalance,
    isVerified,
    openAuthGate,
  } = useAppStore();
  const showPools = isPlatformFeatureVisible("pools", {
    surface: "route",
  });
  const showWallet = isPlatformFeatureVisible("wallet", {
    surface: "route",
  });
  const showInbox = isPlatformFeatureVisible("notifications", {
    surface: "route",
  });
  const showSettings = isPlatformFeatureVisible("settings", {
    surface: "route",
  });
  const poolsRoute = getPlatformFeatureRoute("pools", {
    fallback: "/pools",
  });
  const walletRoute = getPlatformFeatureRoute("wallet", {
    fallback: "/wallet",
  });
  const notificationsRoute = getPlatformFeatureRoute("notifications", {
    fallback: "/notifications",
  });
  const settingsRoute = getPlatformFeatureRoute("settings", {
    fallback: "/settings",
  });
  const displayFanId = fanId.trim() || "Pending";

  return (
    <div className="min-h-screen bg-bg p-5 lg:p-12 pb-24 relative">
      <header className="mb-6 flex justify-between items-center">
        <h1 className="font-display text-4xl text-text tracking-tight">
          Profile
        </h1>
        {showSettings && (
          <Link
            to={settingsRoute}
            className="w-10 h-10 rounded-full bg-surface2 border border-border text-muted hover:text-text flex items-center justify-center transition-colors shadow-sm"
          >
            <SettingsIcon size={18} />
          </Link>
        )}
      </header>

      <div className="bg-surface2 p-5 rounded-[28px] border border-border mb-6 flex flex-col gap-5 relative overflow-hidden shadow-sm">
        <div className="flex items-center gap-5">
          <div className="relative w-20 h-20 rounded-full bg-surface flex items-center justify-center shrink-0 shadow-inner border border-border/50 text-accent">
            <Fingerprint size={34} />
          </div>

          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 mb-1.5">
              <Fingerprint size={14} className="text-accent" />
              <div className="text-base font-mono text-text font-bold truncate">
                Fan ID {displayFanId}
              </div>
            </div>

            <div className="inline-flex max-w-fit items-center gap-1.5 bg-bg border border-border rounded-xl px-3 py-1.5 text-xs font-bold text-text shadow-sm">
              <FETDisplay
                amount={fetBalance}
                showFiat={true}
                className="font-mono"
                fiatClassName="text-muted ml-1"
              />
            </div>
          </div>
        </div>
      </div>

      <div className="space-y-6">
        {(showPools || showWallet) && (
          <section>
            <h3 className="font-sans font-bold text-sm text-text mb-2 px-1">
              Sports-Bar Wallet
            </h3>
            <div className="bg-surface2 rounded-[20px] border border-border overflow-hidden">
              {showPools && (
                <SettingsItem
                  to={poolsRoute}
                  icon={<Trophy size={18} />}
                  label="Match Pools"
                />
              )}
              {showWallet && (
                <SettingsItem
                  to={walletRoute}
                  icon={<Wallet size={18} />}
                  label="FET Wallet"
                />
              )}
            </div>
          </section>
        )}

        <section>
          <h3 className="font-sans font-bold text-sm text-text mb-2 px-1">
            Account
          </h3>
          <div className="bg-surface2 rounded-[20px] border border-border overflow-hidden">
            {!isVerified && (
              <button
                onClick={openAuthGate}
                className="w-full flex items-center justify-between p-3.5 hover:bg-surface3 transition-all text-[#25D366] border-b border-border"
              >
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full bg-[#25D366]/10 flex items-center justify-center border border-[#25D366]/20">
                    <MessageCircle size={16} />
                  </div>
                  <div className="text-left">
                    <div className="font-bold text-sm leading-tight">
                      Verify WhatsApp
                    </div>
                  </div>
                </div>
                <ChevronRight size={16} className="opacity-50" />
              </button>
            )}
            <SettingsItem
              to="/privacy-settings"
              icon={<Lock size={18} />}
              label="Privacy"
            />
            {showInbox && (
              <SettingsItem
                to={notificationsRoute}
                icon={<Bell size={18} />}
                label="Inbox"
              />
            )}
            {showSettings && (
              <SettingsItem
                to={settingsRoute}
                icon={<SettingsIcon size={18} />}
                label="Preferences"
              />
            )}
            {isVerified && (
              <SettingsItem
                to="/"
                icon={<LogOut size={18} />}
                label="Sign Out"
                danger
              />
            )}
          </div>
        </section>
      </div>
    </div>
  );
}

function SettingsItem({
  to,
  icon,
  label,
  danger = false,
}: {
  to: string;
  icon: ReactNode;
  label: string;
  danger?: boolean;
}) {
  return (
    <Link
      to={to}
      className={`w-full flex items-center justify-between p-3.5 hover:bg-surface3 transition-all border-b border-border last:border-0 ${danger ? "text-danger" : "text-text"} group`}
    >
      <div className="flex items-center gap-3">
        <div
          className={`w-8 h-8 rounded-full bg-surface3 flex items-center justify-center text-muted group-hover:text-text transition-colors border border-border/50 ${danger ? "text-danger group-hover:text-danger bg-danger/10 border-danger/20" : ""}`}
        >
          {icon}
        </div>
        <span className="font-bold text-sm">{label}</span>
      </div>
      <ChevronRight
        size={16}
        className="text-muted opacity-50 group-hover:opacity-100 transition-opacity"
      />
    </Link>
  );
}
