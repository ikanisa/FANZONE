import { useState, type ReactNode } from "react";
import { motion, AnimatePresence } from "motion/react";
import {
  Settings as SettingsIcon,
  Bell,
  HelpCircle,
  ChevronRight,
  LogOut,
  MessageCircle,
  Target,
  Trophy,
  Wallet,
  Fingerprint,
  Lock,
  X,
} from "lucide-react";
import { Link } from "react-router-dom";
import { useAppStore } from "../store/useAppStore";
import { TeamLogo } from "./ui/TeamLogo";
import { FETDisplay } from "./ui/FETDisplay";

export default function Profile() {
  const {
    fanId,
    fetBalance,
    favoriteTeams,
    profileTeam,
    setProfileTeam,
    isVerified,
    openAuthGate,
  } = useAppStore();
  const [showImageSelect, setShowImageSelect] = useState(false);

  return (
    <div className="min-h-screen bg-bg p-5 lg:p-12 pb-24 relative">
      <header className="mb-6 flex justify-between items-center">
        <h1 className="font-display text-4xl text-text tracking-tight">
          Profile
        </h1>
        <Link
          to="/settings"
          className="w-10 h-10 rounded-full bg-surface2 border border-border text-muted hover:text-text flex items-center justify-center transition-colors shadow-sm"
        >
          <SettingsIcon size={18} />
        </Link>
      </header>

      {/* Profile Summary */}
      <div className="bg-surface2 p-5 rounded-[28px] border border-border mb-6 flex flex-col gap-5 relative overflow-hidden shadow-sm">
        <div className="flex items-center gap-5">
          <div
            onClick={() => setShowImageSelect(true)}
            className="relative w-20 h-20 rounded-full bg-surface flex items-center justify-center shrink-0 cursor-pointer group shadow-inner border border-border/50"
          >
            {profileTeam ? (
              <TeamLogo teamName={profileTeam} size={48} />
            ) : (
              <span className="text-3xl text-muted">⚽</span>
            )}
            <div className="absolute inset-0 bg-bg/80 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center rounded-full backdrop-blur-sm shadow-inner">
              <span className="text-text text-[10px] font-bold uppercase tracking-widest text-center leading-none">
                Change
              </span>
            </div>
          </div>

          <div className="flex-1">
            <div className="flex items-center gap-2 mb-1.5">
              <Fingerprint size={14} className="text-accent" />
              <div className="text-base font-mono text-text font-bold">
                Fan ID {fanId}
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

        <div className="pt-4 border-t border-border">
          <div className="flex gap-2 flex-wrap">
            {favoriteTeams.length > 0 ? (
              favoriteTeams.map((team) => (
                <div
                  key={team}
                  className="w-10 h-10 rounded-full bg-surface border border-border flex items-center justify-center shadow-sm"
                  title={team}
                >
                  <TeamLogo teamName={team} size={24} />
                </div>
              ))
            ) : (
              <span className="text-[10px] font-bold uppercase tracking-widest text-muted">
                Selected Teams
              </span>
            )}
          </div>
        </div>
      </div>

      <AnimatePresence>
        {showImageSelect && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center p-6 bg-bg/80 backdrop-blur-md"
          >
            <motion.div
              initial={{ scale: 0.9, y: 20 }}
              animate={{ scale: 1, y: 0 }}
              exit={{ scale: 0.9, y: 20 }}
              className="bg-surface2 border border-border rounded-3xl p-6 w-full max-w-sm shadow-2xl relative"
            >
              <button
                onClick={() => setShowImageSelect(false)}
                className="absolute top-4 right-4 text-muted hover:text-text p-2 bg-surface rounded-full"
              >
                <X size={20} />
              </button>

              <h3 className="font-display text-2xl text-text tracking-widest mb-2 mt-2">
                Select Identity
              </h3>
              <p className="text-sm text-muted mb-6">
                Choose your primary team badge for the profile avatar.
              </p>

              {favoriteTeams.length > 0 ? (
                <div className="grid grid-cols-4 gap-4 mb-6">
                  {favoriteTeams.map((team) => (
                    <button
                      key={team}
                      onClick={() => {
                        setProfileTeam(team);
                        setShowImageSelect(false);
                      }}
                      className={`aspect-square flex items-center justify-center rounded-2xl border transition-all ${
                        profileTeam === team
                          ? "border-accent bg-accent/10 shadow-md"
                          : "border-border bg-surface hover:bg-surface3 hover:border-muted"
                      }`}
                      title={team}
                    >
                      <TeamLogo teamName={team} size={40} />
                    </button>
                  ))}
                </div>
              ) : (
                <div className="text-center text-sm text-muted mb-6 py-4 bg-surface rounded-xl border border-border">
                  You need to support a team first. <br />
                  Add a team during onboarding to change your logo.
                </div>
              )}
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Sections */}
      <div className="space-y-6">
        {/* SECTION: My Activity */}
        <section>
          <h3 className="font-sans font-bold text-sm text-text mb-2 px-1">
            Play
          </h3>
          <div className="bg-surface2 rounded-[20px] border border-border overflow-hidden">
            <SettingsItem
              to="/"
              icon={<Target size={18} />}
              label="Predictions"
            />
            <SettingsItem
              to="/leaderboard"
              icon={<Trophy size={18} />}
              label="Leaderboard"
            />
            <SettingsItem
              to="/wallet"
              icon={<Wallet size={18} />}
              label="Wallet"
            />
          </div>
        </section>

        {/* SECTION: Account */}
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
              to="/privacy"
              icon={<Lock size={18} />}
              label="Privacy"
            />
            <SettingsItem
              to="/notifications"
              icon={<Bell size={18} />}
              label="Inbox"
            />
            <SettingsItem
              to="/settings"
              icon={<SettingsIcon size={18} />}
              label="Preferences"
            />
            <SettingsItem
              to="/settings"
              icon={<HelpCircle size={18} />}
              label="Help"
            />
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

      <div className="mt-8 text-center pt-8 border-t border-border">
        <p className="text-[10px] uppercase font-bold tracking-widest text-muted mb-2">
          FANZONE v2.0.1
        </p>
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
