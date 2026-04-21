import { useState } from 'react';
import { motion } from 'motion/react';
import { ChevronLeft, Shield, Eye, EyeOff, Lock, Smartphone } from 'lucide-react';
import { Link } from 'react-router-dom';
import { useAppStore } from '../store/useAppStore';

export default function PrivacySettings() {
  const { isVerified } = useAppStore();
  const [showName, setShowName] = useState(false);
  const [findable, setFindable] = useState(false);

  return (
    <div className="min-h-screen bg-bg pb-24">
      {/* Header */}
      <header className="sticky top-0 z-30 bg-surface/80 backdrop-blur-md border-b border-border p-4 flex items-center justify-between">
        <Link to="/profile" className="text-text hover:text-accent transition-all">
          <ChevronLeft size={24} />
        </Link>
        <div className="text-center">
          <div className="text-[10px] font-bold text-muted uppercase tracking-widest">Settings</div>
          <div className="text-sm font-bold text-text">Privacy</div>
        </div>
        <div className="w-6" />
      </header>

      <div className="p-6 lg:p-12 max-w-2xl mx-auto space-y-8">
        
        {/* Core Privacy Guarantees */}
        <section>
          <h3 className="text-[10px] font-bold text-muted uppercase tracking-widest mb-3 px-2">Core Guarantees</h3>
          <div className="bg-surface2 rounded-3xl border border-border overflow-hidden">
            <div className="p-4 border-b border-border flex gap-4 items-start">
              <div className="w-10 h-10 rounded-full bg-[#25D366]/10 flex items-center justify-center text-[#25D366] shrink-0">
                <Smartphone size={20} />
              </div>
              <div>
                <div className="font-bold text-sm text-text mb-1">Phone Number Hidden</div>
                <div className="text-xs text-muted leading-relaxed">
                  Your WhatsApp/Phone number is encrypted and stored server-side only. It is never exposed to other users, club admins, or in public leaderboards.
                </div>
              </div>
            </div>
            <div className="p-4 flex gap-4 items-start">
              <div className="w-10 h-10 rounded-full bg-accent/10 flex items-center justify-center text-accent shrink-0">
                <Shield size={20} />
              </div>
              <div>
                <div className="font-bold text-sm text-text mb-1">Anonymous Contributions</div>
                <div className="text-xs text-muted leading-relaxed">
                  MoMo contributions to fan clubs are logged using your Fan ID and amount bracket only. Exact amounts and phone numbers are not recorded.
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* Visibility Toggles */}
        <section>
          <h3 className="text-[10px] font-bold text-muted uppercase tracking-widest mb-3 px-2">Visibility Controls</h3>
          <div className="bg-surface2 rounded-3xl border border-border overflow-hidden p-2">
            
            <div className="p-4 flex items-center justify-between border-b border-border">
              <div className="pr-4">
                <div className="font-bold text-sm text-text mb-1 flex items-center gap-2">
                  Display Name on Leaderboards
                  {!isVerified && <Lock size={12} className="text-muted" />}
                </div>
                <div className="text-xs text-muted">
                  Show your custom display name instead of your anonymous Fan ID on public leaderboards.
                </div>
              </div>
              <button 
                disabled={!isVerified}
                onClick={() => setShowName(!showName)}
                className={`w-12 h-6 rounded-full transition-colors relative shrink-0 ${showName && isVerified ? 'bg-accent' : 'bg-surface3'} ${!isVerified && 'opacity-50 cursor-not-allowed'}`}
              >
                <motion.div 
                  className="w-4 h-4 bg-white rounded-full absolute top-1"
                  animate={{ left: showName && isVerified ? '26px' : '4px' }}
                />
              </button>
            </div>

            <div className="p-4 flex items-center justify-between">
              <div className="pr-4">
                <div className="font-bold text-sm text-text mb-1 flex items-center gap-2">
                  Allow Friends to Find Me
                  {!isVerified && <Lock size={12} className="text-muted" />}
                </div>
                <div className="text-xs text-muted">
                  Allow other users who have your phone number in their contacts to find your Fan ID.
                </div>
              </div>
              <button 
                disabled={!isVerified}
                onClick={() => setFindable(!findable)}
                className={`w-12 h-6 rounded-full transition-colors relative shrink-0 ${findable && isVerified ? 'bg-accent' : 'bg-surface3'} ${!isVerified && 'opacity-50 cursor-not-allowed'}`}
              >
                <motion.div 
                  className="w-4 h-4 bg-white rounded-full absolute top-1"
                  animate={{ left: findable && isVerified ? '26px' : '4px' }}
                />
              </button>
            </div>

          </div>
          {!isVerified && (
            <p className="text-[10px] text-accent2 mt-3 px-4 font-bold">
              * Verification required to change visibility settings.
            </p>
          )}
        </section>

      </div>
    </div>
  );
}
