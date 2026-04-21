import { useState } from 'react';
import { motion } from 'motion/react';
import { ChevronLeft, Users, Trophy, Zap, ShieldCheck } from 'lucide-react';
import { Link, useParams } from 'react-router-dom';
import { useAppStore } from '../store/useAppStore';
import { MembershipTierModal } from './ui/MembershipTierModal';
import { ContributionConfirmModal } from './ui/ContributionConfirmModal';
import confetti from 'canvas-confetti';

export default function TeamProfile() {
  const { id } = useParams();
  const [activeTab, setActiveTab] = useState('Overview');
  const { isVerified, openAuthGate } = useAppStore();
  
  const [isTierModalOpen, setIsTierModalOpen] = useState(false);
  const [isConfirmModalOpen, setIsConfirmModalOpen] = useState(false);
  const [selectedTier, setSelectedTier] = useState<string | null>(null);

  const handleJoinClick = () => {
    if (!isVerified) {
      openAuthGate();
    } else {
      setIsTierModalOpen(true);
    }
  };

  const handleSelectTier = (tier: string) => {
    setSelectedTier(tier);
    setIsTierModalOpen(false);
    if (tier !== 'Supporter') {
      // Show USSD instructions tab
      setActiveTab('Contribute');
    } else {
      // Free tier, just confirm
      triggerConfetti();
    }
  };

  const handleMoMoDial = () => {
    // In a real app, this would use url_launcher to open the dialer
    // window.location.href = 'tel:*182*8*1*0780123456#';
    
    // Simulate returning from dialer after a short delay
    setTimeout(() => {
      setIsConfirmModalOpen(true);
    }, 1000);
  };

  const handleConfirmContribution = () => {
    setIsConfirmModalOpen(false);
    triggerConfetti();
    // Update user's membership state in global store (simulated)
  };

  const triggerConfetti = () => {
    confetti({
      particleCount: 100,
      spread: 70,
      origin: { y: 0.6 },
      colors: ['#00e5a0', '#ffd32a', '#ffffff']
    });
  };

  return (
    <div className="min-h-screen bg-bg pb-24">
      {/* Header */}
      <header className="sticky top-0 z-30 bg-surface/80 backdrop-blur-md border-b border-border p-4 flex items-center justify-between">
        <Link to="/memberships" className="text-text hover:text-accent transition-all">
          <ChevronLeft size={24} />
        </Link>
        <div className="text-center">
          <div className="text-[10px] font-bold text-muted uppercase tracking-widest">Team Profile</div>
        </div>
        <div className="w-6" />
      </header>

      {/* Hero Banner */}
      <div className="relative h-48 bg-gradient-to-br from-[#1a0a00] to-[#2d1100] border-b border-border overflow-hidden">
        <div className="absolute top-4 left-4 text-[9px] font-bold tracking-widest text-text/40 uppercase">Malta Premier League</div>
        
        <div className="absolute -bottom-8 left-6 w-24 h-24 rounded-full bg-surface border-4 border-surface2 flex items-center justify-center shadow-xl z-10 overflow-hidden p-2">
           <img src="https://upload.wikimedia.org/wikipedia/en/e/eb/Hamrun_Spartans_logo.png" className="w-full h-full object-contain" alt="Logo" />
        </div>
      </div>

      {/* Team Info */}
      <div className="pt-12 px-6 pb-6 bg-surface2 border-b border-border">
        <h1 className="font-display text-3xl text-text tracking-widest mb-1">Hamrun Spartans</h1>
        <p className="text-xs text-muted mb-6">Hamrun, Malta · Champions × 10</p>

        <div className="grid grid-cols-3 gap-3 mb-6">
          <div className="bg-surface3 rounded-xl p-3 text-center">
            <div className="font-mono text-xl font-bold text-text">1,240</div>
            <div className="text-[9px] text-muted uppercase tracking-widest mt-1">Members</div>
          </div>
          <div className="bg-surface3 rounded-xl p-3 text-center">
            <div className="font-mono text-xl font-bold text-text">1</div>
            <div className="text-[9px] text-muted uppercase tracking-widest mt-1">Club Rank</div>
          </div>
          <div className="bg-surface3 rounded-xl p-3 text-center">
            <div className="font-mono text-xl font-bold text-text">48.2K</div>
            <div className="text-[9px] text-muted uppercase tracking-widest mt-1">Club FET</div>
          </div>
        </div>

        <div className="bg-surface3 border border-border rounded-xl p-4 mb-6">
          <div className="text-[9px] font-bold tracking-widest uppercase text-text mb-1">BOV Mobile Pay Add-on</div>
          <div className="font-mono text-lg text-accent tracking-widest">79X2 84X1</div>
          <div className="text-[10px] text-muted mt-2">Send instantly using BOV Mobile Pay · Verified via Fan ID</div>
        </div>

        <button 
          onClick={handleJoinClick}
          className="w-full bg-gradient-to-r from-accent/20 to-accent/10 border border-accent/30 text-accent font-bold py-3 rounded-xl transition-all"
        >
          {isVerified ? 'Manage Membership' : 'Join Spartans Fan Club — Free'}
        </button>
      </div>

      {/* Tabs */}
      <div className="flex border-b border-border bg-surface overflow-x-auto">
        {['Overview', 'Members', 'Fixtures', 'Contribute', 'About'].map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`flex-1 min-w-[100px] py-4 text-sm font-bold transition-all whitespace-nowrap ${activeTab === tab ? 'text-accent border-b-2 border-accent' : 'text-muted hover:text-text'}`}
          >
            {tab}
          </button>
        ))}
      </div>

      {/* Content */}
      <div className="p-6">
        {activeTab === 'Overview' && (
          <div className="space-y-6">
            <h3 className="font-display text-xl text-text tracking-widest mb-4">LATEST MATCH</h3>
            <div className="bg-surface2 border border-border rounded-2xl p-4 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <span className="text-2xl">🦅</span>
                <span className="font-bold text-text">APR</span>
              </div>
              <div className="font-mono text-2xl font-bold">2 - 0</div>
              <div className="flex items-center gap-3">
                <span className="font-bold text-text">RAY</span>
                <span className="text-2xl">⚽</span>
              </div>
            </div>
          </div>
        )}
        
        {activeTab === 'Members' && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-6">
            <h3 className="font-display text-xl text-text tracking-widest mb-4">CLUB MEMBERS</h3>
            <div className="grid grid-cols-2 gap-4 mb-6">
              <div className="bg-surface2 p-4 rounded-xl border border-border text-center">
                <div className="text-2xl mb-1">👑</div>
                <div className="font-mono text-xl font-bold text-text">12</div>
                <div className="text-[10px] text-muted uppercase tracking-widest">Legends</div>
              </div>
              <div className="bg-surface2 p-4 rounded-xl border border-border text-center">
                <div className="text-2xl mb-1">🔥</div>
                <div className="font-mono text-xl font-bold text-text">145</div>
                <div className="text-[10px] text-muted uppercase tracking-widest">Ultras</div>
              </div>
              <div className="bg-surface2 p-4 rounded-xl border border-border text-center">
                <div className="text-2xl mb-1">🏅</div>
                <div className="font-mono text-xl font-bold text-text">380</div>
                <div className="text-[10px] text-muted uppercase tracking-widest">Members</div>
              </div>
              <div className="bg-surface2 p-4 rounded-xl border border-border text-center">
                <div className="text-2xl mb-1">⚽</div>
                <div className="font-mono text-xl font-bold text-text">703</div>
                <div className="text-[10px] text-muted uppercase tracking-widest">Supporters</div>
              </div>
            </div>
            
            <h4 className="text-[10px] font-bold text-muted uppercase tracking-widest mb-3">Top Contributors</h4>
            <div className="space-y-2">
              <MemberRow rank={1} fanId="102948" tier="Legend" fet="12.4k" />
              <MemberRow rank={2} fanId="483291" tier="Ultra" fet="8.2k" isMe />
              <MemberRow rank={3} fanId="992110" tier="Ultra" fet="7.1k" />
              <MemberRow rank={4} fanId="331002" tier="Member" fet="4.5k" />
              <MemberRow rank={5} fanId="884122" tier="Member" fet="3.1k" />
            </div>
          </motion.div>
        )}

        {activeTab === 'Fixtures' && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-4">
            <h3 className="font-display text-xl text-text tracking-widest mb-4">UPCOMING MATCHES</h3>
            <div className="bg-surface2 p-4 rounded-xl border border-border text-center">
              <div className="text-[10px] text-muted uppercase tracking-widest mb-2">Tomorrow, 15:00</div>
              <div className="flex justify-between items-center px-4">
                <div className="text-2xl">🦅</div>
                <div className="font-bold text-text">VS</div>
                <div className="text-2xl">⚽</div>
              </div>
              <div className="flex justify-between items-center mt-2 text-xs font-bold">
                <span>APR FC</span>
                <span>Rayon Sports</span>
              </div>
            </div>
          </motion.div>
        )}

        {activeTab === 'About' && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-4">
            <h3 className="font-display text-xl text-text tracking-widest mb-4">ABOUT APR FC</h3>
            <p className="text-sm text-muted leading-relaxed">
              Armée Patriotique Rwandaise Football Club (APR FC) is a football club from Kigali in Rwanda. The club plays their home games at Amahoro Stadium. Founded in 1993, it is the most successful club in Rwanda.
            </p>
          </motion.div>
        )}

        {activeTab === 'Contribute' && (
          <div className="space-y-6">
            <h3 className="font-display text-xl text-text tracking-widest mb-4">MOMO USSD CONTRIBUTION</h3>
            <div className="bg-surface2 border border-border rounded-2xl p-6">
              <div className="flex items-center gap-4 mb-6">
                <div className="w-12 h-12 rounded-full bg-[#FFCC00]/10 border border-[#FFCC00]/30 flex items-center justify-center text-[#FFCC00] font-mono font-bold shrink-0">1</div>
                <div>
                  <div className="font-bold text-text text-sm">Dial USSD Code</div>
                  <div className="text-xs text-muted">Dial *182*8*1*0780123456# on your MTN line.</div>
                </div>
              </div>
              <div className="flex items-center gap-4 mb-6">
                <div className="w-12 h-12 rounded-full bg-[#FFCC00]/10 border border-[#FFCC00]/30 flex items-center justify-center text-[#FFCC00] font-mono font-bold shrink-0">2</div>
                <div>
                  <div className="font-bold text-text text-sm">Complete Payment</div>
                  <div className="text-xs text-muted">Select amount tier and enter PIN.</div>
                </div>
              </div>
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-full bg-[#FFCC00]/10 border border-[#FFCC00]/30 flex items-center justify-center text-[#FFCC00] font-mono font-bold shrink-0">3</div>
                <div>
                  <div className="font-bold text-text text-sm">Confirm Here</div>
                  <div className="text-xs text-muted">Return to FANZONE to activate your tier.</div>
                </div>
              </div>
            </div>
            <button 
              onClick={handleMoMoDial}
              className="w-full bg-[#FFCC00] hover:bg-[#FFCC00]/90 text-[#1a1400] font-bold py-4 rounded-xl transition-all"
            >
              DIAL NOW
            </button>
          </div>
        )}
      </div>

      <MembershipTierModal 
        isOpen={isTierModalOpen} 
        onClose={() => setIsTierModalOpen(false)} 
        onSelectTier={handleSelectTier} 
      />
      
      <ContributionConfirmModal 
        isOpen={isConfirmModalOpen} 
        onClose={() => setIsConfirmModalOpen(false)} 
        tier={selectedTier}
        onConfirm={handleConfirmContribution}
      />
    </div>
  );
}

function MemberRow({ rank, fanId, tier, fet, isMe = false }: { rank: number, fanId: string, tier: string, fet: string, isMe?: boolean }) {
  return (
    <div className={`flex items-center justify-between p-3 rounded-xl border ${isMe ? 'bg-accent/10 border-accent/30' : 'bg-surface2 border-border'}`}>
      <div className="flex items-center gap-3">
        <div className="font-mono text-muted text-xs w-4">{rank}</div>
        <div className="w-8 h-8 rounded-full bg-surface3 flex items-center justify-center text-xs">👤</div>
        <div>
          <div className="text-sm font-bold text-text flex items-center gap-2">
            {fanId} {isMe && <span className="text-[9px] bg-accent text-bg px-1.5 py-0.5 rounded-sm uppercase tracking-widest">You</span>}
          </div>
          <div className="text-[10px] text-accent3">{tier}</div>
        </div>
      </div>
      <div className="font-mono text-sm font-bold text-accent">{fet}</div>
    </div>
  );
}
