import React, { useEffect, useMemo, useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { useNavigate } from "react-router-dom";
import {
  ChevronRight,
  ShieldCheck,
  Trophy,
  Zap,
  Search,
  MessageCircle,
} from "lucide-react";
import { useAppStore } from "../store/useAppStore";
import { TeamLogo } from "./ui/TeamLogo";
import { api, type WebsitePhonePreset } from "../services/api";
import type { Team } from "../types";

export default function Onboarding() {
  const [step, setStep] = useState(1);
  const navigate = useNavigate();
  const { completeOnboarding, verifyPhone } = useAppStore();

  const nextStep = () => setStep((s) => s + 1);
  const finish = () => {
    verifyPhone(); // Ensure they are marked as verified after finishing OTP/Onboarding
    completeOnboarding();
    navigate("/");
  };

  return (
    <div className="min-h-screen bg-bg flex flex-col relative overflow-hidden">
      {/* Background glow */}
      <div className="absolute top-[-20%] left-[-10%] w-[50%] h-[50%] bg-accent/20 blur-[120px] rounded-full pointer-events-none" />
      <div className="absolute bottom-[-20%] right-[-10%] w-[50%] h-[50%] bg-accent4/20 blur-[120px] rounded-full pointer-events-none" />

      <div className="flex-1 flex flex-col justify-center p-6 lg:p-12 z-10 max-w-md mx-auto w-full">
        <AnimatePresence mode="wait">
          {step === 1 && <Step1 key="step1" onNext={nextStep} />}
          {step === 2 && <Step2 key="step2" onNext={nextStep} />}
          {step === 3 && <Step3 key="step3" onNext={nextStep} />}
          {step === 4 && <Step4 key="step4" onFinish={finish} />}
        </AnimatePresence>
      </div>
    </div>
  );
}

function Step1({ onNext }: { onNext: () => void }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, x: -50 }}
      className="flex flex-col h-full justify-center"
    >
      <div className="mb-12">
        <h1 className="font-display text-6xl text-text tracking-widest mb-2">
          <span className="text-success">FAN</span>
          <span className="text-accent3">ZONE</span>
        </h1>
        <p className="text-accent text-sm font-bold tracking-[3px] uppercase">
          Predict. Earn. Repeat.
        </p>
      </div>

      <div className="space-y-6 mb-12">
        <Feature
          icon={<Zap />}
          title="Live Predictions"
          desc="Predict match outcomes in real-time."
        />
        <Feature
          icon={<Trophy />}
          title="Earn FET Tokens"
          desc="Get rewarded for your football knowledge."
        />
        <Feature
          icon={<ShieldCheck />}
          title="Anonymous Profile"
          desc="Play securely without identity exposure."
        />
      </div>

      <button
        onClick={onNext}
        className="w-full bg-accent hover:bg-accent/90 text-bg font-bold py-4 rounded-xl transition-all flex items-center justify-center gap-2 mt-auto"
      >
        GET STARTED <ChevronRight size={20} />
      </button>
    </motion.div>
  );
}

function Feature({
  icon,
  title,
  desc,
}: {
  icon: React.ReactNode;
  title: string;
  desc: string;
}) {
  return (
    <div className="flex items-center gap-4">
      <div className="w-12 h-12 rounded-full bg-surface2 border border-border flex items-center justify-center text-accent">
        {icon}
      </div>
      <div>
        <div className="font-bold text-text text-sm">{title}</div>
        <div className="text-xs text-muted">{desc}</div>
      </div>
    </div>
  );
}

function Step2({ onNext }: { onNext: () => void }) {
  const [phone, setPhone] = useState("");
  const [phonePreset, setPhonePreset] = useState<WebsitePhonePreset>({
    countryCode: null,
    dialCode: "+",
    hint: "000 000 000",
    minDigits: 7,
  });

  useEffect(() => {
    let active = true;
    api.getPreferredPhonePreset().then((preset) => {
      if (active) {
        setPhonePreset(preset);
      }
    });

    return () => {
      active = false;
    };
  }, []);

  return (
    <motion.div
      initial={{ opacity: 0, x: 50 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: -50 }}
      className="flex flex-col h-full justify-center"
    >
      <div className="w-16 h-16 rounded-full bg-success/10 text-success flex items-center justify-center mb-6 border border-success/20">
        <MessageCircle size={32} />
      </div>
      <h2 className="font-display text-4xl text-text tracking-widest mb-4">
        WHATSAPP LOGIN
      </h2>
      <p className="text-muted text-sm mb-8">
        We'll send you an OTP via WhatsApp. No names or emails required.
      </p>

      <div className="flex gap-4 mb-8">
        <div className="bg-surface2 border border-border rounded-xl p-4 flex items-center justify-center text-text font-bold w-20">
          {phonePreset.dialCode}
        </div>
        <input
          type="tel"
          placeholder={phonePreset.hint}
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          className="flex-1 bg-surface2 border border-border rounded-xl p-4 text-text font-mono focus:outline-none focus:border-accent transition-all"
          autoFocus
        />
      </div>

      <button
        onClick={onNext}
        disabled={phone.length < phonePreset.minDigits}
        className={`w-full font-bold py-4 rounded-xl transition-all mt-auto ${
          phone.length >= phonePreset.minDigits
            ? "bg-success hover:bg-success/90 text-bg"
            : "bg-surface3 text-muted cursor-not-allowed"
        }`}
      >
        SEND OTP TO WHATSAPP
      </button>
    </motion.div>
  );
}

function Step3({ onNext }: { onNext: () => void }) {
  return (
    <motion.div
      initial={{ opacity: 0, x: 50 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: -50 }}
      className="flex flex-col h-full justify-center"
    >
      <h2 className="font-display text-4xl text-text tracking-widest mb-4">
        VERIFY OTP
      </h2>
      <p className="text-muted text-sm mb-8">
        Enter the 6-digit code sent to your WhatsApp.
      </p>

      <div className="flex gap-2 mb-8 justify-between">
        {[1, 2, 3, 4, 5, 6].map((i) => (
          <input
            key={i}
            type="text"
            maxLength={1}
            className="w-12 h-14 bg-surface2 border border-border rounded-xl text-center text-text font-mono text-xl focus:outline-none focus:border-accent transition-all"
          />
        ))}
      </div>

      <button
        onClick={onNext}
        className="w-full bg-accent hover:bg-accent/90 text-bg font-bold py-4 rounded-xl transition-all mt-auto"
      >
        VERIFY CODE
      </button>
    </motion.div>
  );
}

function Step4({ onFinish }: { onFinish: () => void }) {
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedTeam, setSelectedTeam] = useState<Team | null>(null);
  const [popularTeams, setPopularTeams] = useState<Team[]>([]);
  const [searchResults, setSearchResults] = useState<Team[]>([]);
  const { addFavoriteTeam } = useAppStore();

  useEffect(() => {
    let active = true;
    api.getPopularTeams(12).then((teams) => {
      if (active) {
        setPopularTeams(teams);
      }
    });

    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    if (!searchQuery.trim()) {
      setSearchResults([]);
      return;
    }

    let active = true;
    api.searchTeams(searchQuery, 6).then((teams) => {
      if (active) {
        setSearchResults(teams);
      }
    });

    return () => {
      active = false;
    };
  }, [searchQuery]);

  const suggestedTeams = useMemo(
    () =>
      popularTeams.filter((team) => team.name.trim().length > 0).slice(0, 4),
    [popularTeams],
  );

  const handleSelectTeam = (team: Team) => {
    setSelectedTeam(team);
    setSearchQuery("");
  };

  const handleFinish = () => {
    if (selectedTeam) {
      addFavoriteTeam(selectedTeam.name);
    }
    onFinish();
  };

  return (
    <motion.div
      initial={{ opacity: 0, x: 50 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, y: -20 }}
      className="flex flex-col h-full overflow-hidden pb-4 justify-center"
    >
      <div className="shrink-0 mb-6">
        <div className="w-16 h-16 rounded-full bg-accent/10 text-accent flex items-center justify-center mb-6 border border-accent/20">
          <ShieldCheck size={32} />
        </div>
        <h2 className="font-display text-4xl text-text tracking-widest mb-2">
          Almost Done
        </h2>
        <p className="text-muted text-sm">
          Your anonymous Fan ID has been generated securely.
        </p>
      </div>

      <div className="flex-1 min-h-[300px] flex flex-col mb-6 mt-4">
        <p className="text-[10px] font-bold text-muted uppercase tracking-widest mb-3">
          Optional: Pick your favorite team
        </p>

        {selectedTeam ? (
          <div className="mb-6">
            <div className="border border-accent/20 rounded-xl bg-accent/5 p-4 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <TeamLogo
                  teamName={selectedTeam.name}
                  src={selectedTeam.crestUrl || selectedTeam.logoUrl}
                  size={24}
                />
                <span className="font-bold text-text">{selectedTeam.name}</span>
              </div>
              <ShieldCheck size={18} className="text-bg" />
            </div>
            <button
              onClick={() => setSelectedTeam(null)}
              className="text-xs text-accent mt-3 font-bold border-b border-accent/30 pb-0.5"
            >
              Change team
            </button>
          </div>
        ) : (
          <div className="relative shrink-0 transition-all mb-4">
            <Search
              size={18}
              className="absolute left-4 top-1/2 -translate-y-1/2 text-muted"
            />
            <input
              type="text"
              placeholder="Search teams..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full bg-surface2 border border-border rounded-xl p-4 pl-12 text-text focus:outline-none focus:border-accent transition-all placeholder:text-muted/60"
            />
          </div>
        )}

        {!selectedTeam && (
          <div className="flex-1 overflow-y-auto hide-scrollbar">
            {searchQuery ? (
              <div className="space-y-2">
                {searchResults.map((team) => (
                  <button
                    key={team.id}
                    onClick={() => handleSelectTeam(team)}
                    className="w-full text-left p-4 rounded-xl bg-surface2 border border-border hover:border-accent/50 transition-colors flex items-center gap-3"
                  >
                    <TeamLogo
                      teamName={team.name}
                      src={team.crestUrl || team.logoUrl}
                      size={20}
                    />
                    <div>
                      <span className="text-sm font-bold text-text block">
                        {team.name}
                      </span>
                      {team.leagueName ? (
                        <span className="text-xs text-muted">
                          {team.leagueName}
                        </span>
                      ) : null}
                    </div>
                  </button>
                ))}
                {searchResults.length === 0 && (
                  <p className="text-muted text-xs p-4">No teams found.</p>
                )}
              </div>
            ) : (
              <div className="flex flex-wrap gap-2">
                {suggestedTeams.map((team) => (
                  <button
                    key={team.id}
                    onClick={() => handleSelectTeam(team)}
                    className="bg-surface2 border border-border px-4 py-2 rounded-full text-xs font-bold text-text hover:border-accent/50 transition-colors"
                  >
                    {team.name}
                  </button>
                ))}
                {suggestedTeams.length === 0 && (
                  <p className="text-muted text-xs p-4">
                    Team suggestions will appear once the live catalog finishes
                    loading.
                  </p>
                )}
              </div>
            )}
          </div>
        )}
      </div>

      <div className="mt-auto shrink-0 flex flex-col gap-2">
        <button
          onClick={handleFinish}
          className={`w-full font-bold py-4 rounded-xl transition-all ${
            selectedTeam
              ? "bg-accent hover:bg-accent/90 text-bg shadow-lg shadow-accent/20"
              : "bg-surface2 hover:bg-surface3 text-text border border-border shadow-sm"
          }`}
        >
          {selectedTeam ? "ENTER PLATFORM" : "SKIP & ENTER TO APP"}
        </button>
      </div>
    </motion.div>
  );
}
