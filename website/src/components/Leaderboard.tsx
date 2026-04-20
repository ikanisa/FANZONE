import { useState } from 'react';
import { motion } from 'motion/react';
import { Trophy, Users, Search, UserPlus, TrendingUp, TrendingDown, Minus, Shield } from 'lucide-react';

export default function Leaderboard() {
  const [activeTab, setActiveTab] = useState('Global');
  const tabs = ['Global', 'Weekly', 'Friends', 'Fan Clubs'];

  return (
    <div className="min-h-screen bg-bg pb-24">
      <header className="sticky top-0 z-30 bg-surface/80 backdrop-blur-md border-b border-border p-4">
        <h1 className="font-display text-4xl text-text tracking-tight mb-4 flex items-center gap-2">Leaderboard</h1>
        <div className="flex gap-2 overflow-x-auto pb-1 no-scrollbar">
          {tabs.map(tab => (
            <button 
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`px-3 py-1.5 rounded-full text-xs font-bold whitespace-nowrap transition-all ${activeTab === tab ? 'bg-primary text-bg shadow-[0_0_10px_rgba(152,255,152,0.3)]' : 'bg-surface2 border border-border text-muted hover:text-text'}`}
            >
              {tab}
            </button>
          ))}
        </div>
      </header>

      {activeTab === 'Fan Clubs' ? (
        <FanClubLeaderboard />
      ) : (
        <>
          {/* Podium */}
          <div className="flex justify-center items-end gap-2 p-6 bg-surface2 border-b border-border">
            <PodiumItem rank={2} name="MaltaFan" fet="12.4k" height="h-28" />
            <PodiumItem rank={1} name="SpartanKing" fet="15.2k" height="h-36" />
            <PodiumItem rank={3} name="PacevillePro" fet="10.1k" height="h-24" />
          </div>

          {/* List */}
          <div className="p-3 space-y-2">
            {[4, 5, 6, 7, 8].map((rank) => (
              <LeaderboardRow key={rank} rank={rank} name={`User_${rank}`} fet={`${10 - rank}.5k`} />
            ))}
          </div>

          {/* Pinned User */}
          <div className="fixed bottom-[70px] lg:bottom-4 left-3 right-3 bg-primary/10 border border-primary/20 rounded-2xl p-3 flex items-center justify-between backdrop-blur-lg z-40">
            <div className="flex items-center gap-3">
              <span className="font-mono text-primary font-bold w-6">#42</span>
              <div className="w-8 h-8 rounded-full bg-surface3 flex items-center justify-center border border-primary/30 text-xs">👤</div>
              <div>
                <div className="text-sm font-bold text-text leading-tight">You</div>
                <div className="text-[10px] text-muted font-bold tracking-widest uppercase">Accuracy 68%</div>
              </div>
            </div>
            <div className="font-mono text-sm font-bold text-secondary">+2.1k FET</div>
          </div>
        </>
      )}
    </div>
  );
}

function FanClubLeaderboard() {
  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
      {/* Podium */}
      <div className="flex justify-center items-end gap-2 p-6 bg-surface2 border-b border-border">
        <ClubPodiumItem rank={2} name="Sliema W." fet="450k" height="h-28" crest="S" />
        <ClubPodiumItem rank={1} name="Hamrun S." fet="620k" height="h-36" crest="H" />
        <ClubPodiumItem rank={3} name="Valletta FC" fet="310k" height="h-24" crest="V" />
      </div>

      {/* List */}
      <div className="p-3 space-y-2">
        <ClubLeaderboardRow rank={4} name="Floriana" fet="280k" crest="F" trend="up" />
        <ClubLeaderboardRow rank={5} name="Birkirkara" fet="210k" crest="B" trend="down" />
        <ClubLeaderboardRow rank={6} name="Hibernians" fet="195k" crest="H" trend="same" />
        <ClubLeaderboardRow rank={7} name="Balzan FC" fet="150k" crest="B" trend="up" />
      </div>
    </motion.div>
  );
}

function ClubPodiumItem({ rank, name, fet, height, crest }: { rank: number; name: string; fet: string; height: string; crest: string }) {
  return (
    <div className={`flex flex-col items-center gap-2 ${height}`}>
      <div className="w-10 h-10 rounded-xl bg-surface border border-border flex items-center justify-center font-display text-lg z-10 -mb-4 shadow-lg text-text">
        {crest}
      </div>
      <div className={`w-20 ${height} bg-surface3 rounded-t-xl border-t border-x border-border flex flex-col items-center justify-end p-2 relative overflow-hidden`}>
        <div className="absolute inset-0 bg-gradient-to-t from-transparent to-white/5" />
        <span className="font-mono text-xs font-bold text-text relative z-10">#{rank}</span>
      </div>
      <div className="text-center">
        <div className="text-xs font-bold text-text whitespace-nowrap leading-tight">{name}</div>
        <div className="text-[10px] text-primary font-mono">{fet} FET</div>
      </div>
    </div>
  );
}

function ClubLeaderboardRow({ rank, name, fet, crest, trend }: { rank: number; name: string; fet: string; crest: string; trend: 'up' | 'down' | 'same' }) {
  return (
    <div className="bg-surface2 px-3 py-2.5 rounded-xl border border-border flex items-center justify-between">
      <div className="flex items-center gap-3">
        <div className="flex flex-col items-center justify-center w-5">
          <span className="font-mono text-muted text-xs font-bold">{rank}</span>
          {trend === 'up' && <TrendingUp size={10} className="text-primary mt-0.5" />}
          {trend === 'down' && <TrendingDown size={10} className="text-secondary mt-0.5" />}
          {trend === 'same' && <Minus size={10} className="text-muted mt-0.5" />}
        </div>
        <div className="w-8 h-8 rounded-lg bg-surface3 flex items-center justify-center font-display text-sm text-text border border-border">
          {crest}
        </div>
        <span className="text-sm font-bold text-text">{name}</span>
      </div>
      <div className="flex flex-col items-end">
        <span className="font-mono text-sm font-bold text-primary">{fet}</span>
        <span className="text-[9px] text-muted font-bold uppercase tracking-widest">Pool</span>
      </div>
    </div>
  );
}

function PodiumItem({ rank, name, fet, height }: { rank: number; name: string; fet: string; height: string }) {
  return (
    <div className={`flex flex-col items-center gap-2 ${height}`}>
      <div className={rank === 1 ? 'text-primary' : rank === 2 ? 'text-muted' : 'text-secondary'}><Trophy size={rank === 1 ? 32 : 24} /></div>
      <div className={`w-16 ${height} bg-surface3 rounded-t-xl border-t border-x border-border flex flex-col items-center justify-end p-2`}>
        <span className="font-mono text-xs font-bold text-text">#{rank}</span>
      </div>
      <div className="text-center">
        <div className="text-xs font-bold text-text leading-tight">{name}</div>
        <div className="text-[10px] text-secondary font-mono">{fet}</div>
      </div>
    </div>
  );
}

function LeaderboardRow({ rank, name, fet }: { rank: number; name: string; fet: string }) {
  return (
    <div className="bg-surface2 p-3 rounded-xl border border-border flex items-center justify-between">
      <div className="flex items-center gap-3">
        <span className="font-mono text-muted text-xs font-bold w-5">{rank}</span>
        <div className="w-8 h-8 rounded-full bg-surface3 flex items-center justify-center text-xs border border-border">👤</div>
        <span className="text-sm font-bold text-text">{name}</span>
      </div>
      <div className="flex items-center gap-3">
        <span className="font-mono text-sm font-bold text-secondary">{fet} FET</span>
        <button className="w-8 h-8 rounded-full bg-surface3 border border-border text-muted hover:text-primary flex justify-center items-center transition-colors">
          <UserPlus size={14} />
        </button>
      </div>
    </div>
  );
}

