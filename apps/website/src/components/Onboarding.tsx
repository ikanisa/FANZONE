import React, { useEffect, useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { useNavigate } from "react-router-dom";
import {
  ChevronRight,
  ShieldCheck,
  Trophy,
  Zap,
  MessageCircle,
} from "lucide-react";
import { useAppStore } from "../store/useAppStore";
import { api, type WebsitePhonePreset } from "../services/api";

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
      <div className="flex-1 flex flex-col justify-center p-6 lg:p-12 z-10 max-w-md mx-auto w-full">
        <AnimatePresence mode="wait">
          {step === 1 && <Step1 key="step1" onNext={nextStep} />}
          {step === 2 && <Step2 key="step2" onNext={nextStep} />}
          {step === 3 && <Step3 key="step3" onFinish={finish} />}
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
          Order. Pool. Earn.
        </p>
      </div>

      <div className="space-y-6 mb-12">
        <Feature
          icon={<Zap />}
          title="Match Pools"
          desc="Join venue, country, and global match pools."
        />
        <Feature
          icon={<Trophy />}
          title="Earn FET"
          desc="Earn from venue orders and pool wins."
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

function Step3({ onFinish }: { onFinish: () => void }) {
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
        onClick={onFinish}
        className="w-full bg-accent hover:bg-accent/90 text-bg font-bold py-4 rounded-xl transition-all mt-auto"
      >
        VERIFY & ENTER
      </button>
    </motion.div>
  );
}
