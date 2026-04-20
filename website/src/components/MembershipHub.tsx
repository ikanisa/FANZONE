import { useState } from 'react';
import { motion } from 'motion/react';
import { ChevronLeft, Search, Share2 } from 'lucide-react';
import { Link } from 'react-router-dom';
import { useAppStore } from '../store/useAppStore';
import { MembershipTierModal } from './ui/MembershipTierModal';
import { ContributionConfirmModal } from './ui/ContributionConfirmModal';
import { DigitalMembershipCard } from './ui/DigitalMembershipCard';
import { ShareCardModal } from './ui/ShareCardModal';
import confetti from 'canvas-confetti';

export default function MembershipHub() {
  const [activeTab, setActiveTab] = useState('My Clubs');
  const { isVerified } = useAppStore();

  return (
    <div className="min-h-screen bg-bg pb-24">
      {/* Header */}
      <header className="sticky top-0 z-30 bg-surface/80 backdrop-blur-md border-b border-border p-4 flex items-center justify-between">
        <Link to="/profile" className="text-text hover:text-primary transition-all">
          <ChevronLeft size={24} />
        </Link>
        <div className="text-center">
          <div className="text-[10px] font-bold text-muted uppercase tracking-widest">Fan Clubs</div>
          <div className="text-sm font-bold text-text">Membership Hub</div>
        </div>
        <div className="w-6" />
      </header>

      {/* Tabs */}
      <div className="flex border-b border-border bg-surface overflow-x-auto">
        {['My Clubs', 'Malta', 'European Fan Clubs'].map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`flex-1 min-w-[120px] py-4 text-sm font-bold transition-all whitespace-nowrap ${activeTab === tab ? 'text-primary border-b-2 border-primary' : 'text-muted hover:text-text'}`}
          >
            {tab}
          </button>
        ))}
      </div>

      {/* Content */}
      <div className="p-6">
        {activeTab === 'My Clubs' && <MyClubsTab isVerified={isVerified} />}
        {activeTab === 'Malta' && <DiscoverTab category="Malta" />}
        {activeTab === 'European Fan Clubs' && <DiscoverTab category="Europe" />}
      </div>
    </div>
  );
}

function MyClubsTab({ isVerified }: { isVerified: boolean }) {
  const { fanId } = useAppStore();
  const [isTierModalOpen, setIsTierModalOpen] = useState(false);
  const [isConfirmModalOpen, setIsConfirmModalOpen] = useState(false);
  const [isShareModalOpen, setIsShareModalOpen] = useState(false);
  const [selectedTier, setSelectedTier] = useState<string | null>(null);

  const handleSelectTier = (tier: string) => {
    setSelectedTier(tier);
    setIsTierModalOpen(false);
    if (tier !== 'Supporter') {
      setIsConfirmModalOpen(true);
    } else {
      triggerConfetti();
    }
  };

  const handleConfirmContribution = () => {
    setIsConfirmModalOpen(false);
    triggerConfetti();
  };

  const triggerConfetti = () => {
    confetti({
      particleCount: 100,
      spread: 70,
      origin: { y: 0.6 },
      colors: ['#98ff98', '#ff7f50', '#fdfcf0']
    });
  };

  if (!isVerified) {
    return (
      <div className="flex flex-col items-center justify-center py-20 text-center">
        <div className="w-20 h-20 rounded-full bg-surface2 border border-border flex items-center justify-center text-4xl mb-6">
          🤖
        </div>
        <h3 className="font-display text-2xl text-text tracking-widest mb-2">VERIFY TO JOIN</h3>
        <p className="text-muted text-sm max-w-xs mb-6">
          You need to verify your phone number via WhatsApp to join fan clubs and contribute.
        </p>
      </div>
    );
  }

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-8">
      
      {/* Digital Card Section */}
      <section>
        <div className="flex justify-between items-center mb-4">
          <h3 className="font-display text-xl text-text tracking-widest">DIGITAL CARD</h3>
          <button 
            onClick={() => setIsShareModalOpen(true)}
            className="flex items-center gap-2 text-[10px] font-bold text-primary uppercase tracking-widest bg-primary/10 px-3 py-1.5 rounded-full hover:bg-primary/20 transition-colors"
          >
            <Share2 size={12} /> Share
          </button>
        </div>
        <DigitalMembershipCard 
          clubName="Hamrun Spartans"
          tier="Ultra"
          fanId={fanId}
          crest="H"
          color="var(--brand-secondary)"
          memberSince="OCT 2023"
        />
      </section>

      {/* Active Memberships Details */}
      <section>
        <h3 className="font-display text-xl text-text tracking-widest mb-4">MEMBERSHIP DETAILS</h3>
        <div className="bg-surface2 border-t-2 border-secondary rounded-2xl p-6 relative overflow-hidden">
          <div className="absolute top-4 right-4 bg-secondary/20 text-secondary text-[9px] font-bold uppercase tracking-widest px-2 py-1 rounded-full">
            Ultra Member
          </div>
          
          <div className="flex items-center gap-4 mb-6">
            <div className="w-14 h-14 rounded-full bg-surface border-2 border-border flex items-center justify-center text-2xl font-display font-bold">
              H
            </div>
            <div>
              <h4 className="font-bold text-text text-lg">Hamrun Spartans</h4>
              <div className="text-xs text-muted">Malta Premier League</div>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4 mb-6">
            <div className="bg-surface3 rounded-xl p-3">
              <div className="text-[10px] text-muted uppercase tracking-widest font-bold mb-1">Your Rank</div>
              <div className="font-mono text-lg font-bold text-secondary">#42</div>
            </div>
            <div className="bg-surface3 rounded-xl p-3">
              <div className="text-[10px] text-muted uppercase tracking-widest font-bold mb-1">FET to Club</div>
              <div className="font-mono text-lg font-bold text-primary">20%</div>
            </div>
          </div>

          <div className="flex gap-3">
            <Link to="/team/hamrun" className="flex-1 bg-surface3 hover:bg-surface3/80 border border-border text-text text-xs font-bold py-3 rounded-xl text-center transition-all">
              View Club
            </Link>
            <button 
              onClick={() => setIsTierModalOpen(true)}
              className="flex-1 bg-secondary hover:bg-secondary/90 text-bg text-xs font-bold py-3 rounded-xl text-center transition-all"
            >
              Upgrade Tier
            </button>
          </div>
        </div>
      </section>

      {/* Contribution History */}
      <section>
        <h3 className="font-display text-xl text-text tracking-widest mb-4">CONTRIBUTION HISTORY</h3>
        <div className="space-y-2">
          <HistoryRow date="Today, 14:30" amount="FET 1,500 (€15.00)" tier="Ultra" status="Verified" />
          <HistoryRow date="Oct 12, 09:15" amount="FET 1,000 (€10.00)" tier="Ultra" status="Verified" />
          <HistoryRow date="Sep 10, 16:45" amount="FET 500 (€5.00)" tier="Member" status="Verified" />
        </div>
      </section>

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

      <ShareCardModal 
        isOpen={isShareModalOpen} 
        onClose={() => setIsShareModalOpen(false)} 
        fanId={fanId}
      />
    </motion.div>
  );
}

function HistoryRow({ date, amount, tier, status }: { date: string, amount: string, tier: string, status: string }) {
  return (
    <div className="bg-surface2 p-4 rounded-xl border border-border flex items-center justify-between">
      <div>
        <div className="text-sm font-bold text-text">{amount}</div>
        <div className="text-[10px] text-muted">{date}</div>
      </div>
      <div className="text-right">
        <div className="text-xs font-bold text-secondary">{tier}</div>
        <div className="text-[10px] text-primary">{status}</div>
      </div>
    </div>
  );
}

function DiscoverTab({ category }: { category: string }) {
  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-6">
      <div className="flex gap-2 mb-6">
        <div className="flex-1 bg-surface2 border border-border rounded-xl p-3 flex items-center gap-2">
          <Search size={16} className="text-muted" />
          <input 
            type="text" 
            placeholder="Search clubs..." 
            className="bg-transparent border-none text-text text-sm w-full focus:outline-none"
          />
        </div>
      </div>

      <div className="space-y-4">
        {category === 'Africa' ? (
          <>
            <ClubRow id="hamrun" name="Hamrun Spartans" league="Malta Premier League" members="1,240" crest="H" rank={1} />
            <ClubRow id="valletta" name="Valletta FC" league="Malta Premier League" members="980" crest="V" rank={2} />
            <ClubRow id="malta" name="Malta Knights" league="Malta National Team" members="8,220" crest="🇲🇹" rank={3} />
          </>
        ) : (
          <>
            <ClubRow id="ars" name="Arsenal Fans Malta" league="Local Chapter" members="3,890" crest="⚡" rank={1} />
            <ClubRow id="mun" name="Man United Fans Malta" league="Local Chapter" members="2,100" crest="🔴" rank={4} />
          </>
        )}
      </div>
    </motion.div>
  );
}

function ClubRow({ id, name, league, members, crest, rank }: { id: string, name: string, league: string, members: string, crest: string, rank: number }) {
  return (
    <Link to={`/team/${id}`} className="block bg-surface2 border border-border rounded-2xl p-4 hover:border-primary/40 transition-colors">
      <div className="flex items-center gap-4">
        <div className="w-12 h-12 rounded-full bg-surface3 border border-border flex items-center justify-center text-xl shadow-inner">
          {crest}
        </div>
        <div className="flex-1">
          <div className="font-bold text-text text-sm">{name}</div>
          <div className="text-[10px] text-muted">{league}</div>
        </div>
        <div className="text-right">
          <div className="font-mono text-sm font-bold text-secondary">#{rank}</div>
          <div className="text-[10px] text-muted">{members} fans</div>
        </div>
      </div>
    </Link>
  );
}
