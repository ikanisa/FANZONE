import { useState } from 'react';
import { motion } from 'motion/react';
import { ChevronLeft, Users, Trophy, Swords, UserPlus, Search } from 'lucide-react';
import { Link } from 'react-router-dom';
import { PoolModal } from './ui/PoolModal';

export default function SocialHub() {
  const [activeTab, setActiveTab] = useState('Friends');

  return (
    <div className="min-h-screen bg-bg pb-24">
      {/* Header */}
      <header className="sticky top-0 z-30 bg-surface/80 backdrop-blur-md border-b border-border p-4 flex items-center justify-between">
        <Link to="/profile" className="text-text hover:text-accent transition-all">
          <ChevronLeft size={24} />
        </Link>
        <div className="text-center">
          <div className="text-[10px] font-bold text-muted uppercase tracking-widest">Community</div>
          <div className="text-sm font-bold text-text">Social Hub</div>
        </div>
        <div className="w-6" />
      </header>

      {/* Tabs */}
      <div className="flex border-b border-border bg-surface">
        {['Friends', 'Club Fan Zone'].map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`flex-1 py-4 text-sm font-bold transition-all ${activeTab === tab ? 'text-accent border-b-2 border-accent' : 'text-muted hover:text-text'}`}
          >
            {tab}
          </button>
        ))}
      </div>

      {/* Content */}
      <div className="p-6">
        {activeTab === 'Friends' && <FriendsTab />}
        {activeTab === 'Club Fan Zone' && <ClubFanZoneTab />}
      </div>
    </div>
  );
}

function FriendsTab() {
  const [poolTarget, setPoolTarget] = useState<string | null>(null);

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-6">
      <div className="flex gap-2">
        <div className="flex-1 bg-surface2 border border-border rounded-xl p-3 flex items-center gap-2">
          <Search size={16} className="text-muted" />
          <input 
            type="text" 
            placeholder="Search friends..." 
            className="bg-transparent border-none text-text text-sm w-full focus:outline-none"
          />
        </div>
        <button className="bg-accent/10 border border-accent/20 text-accent p-3 rounded-xl hover:bg-accent/20 transition-all">
          <UserPlus size={20} />
        </button>
      </div>

      <div className="bg-surface2 rounded-3xl border border-border overflow-hidden">
        <FriendRow name="PacevillePro" acc="72%" status="online" onPool={() => setPoolTarget('PacevillePro')} />
        <FriendRow name="GozitanFan" acc="65%" status="offline" onPool={() => setPoolTarget('GozitanFan')} />
        <FriendRow name="PredictorPro" acc="81%" status="online" onPool={() => setPoolTarget('PredictorPro')} />
        <FriendRow name="SoccerFan99" acc="54%" status="offline" onPool={() => setPoolTarget('SoccerFan99')} />
      </div>

      <PoolModal 
        isOpen={!!poolTarget} 
        onClose={() => setPoolTarget(null)} 
        targetName={poolTarget || ''} 
      />
    </motion.div>
  );
}

function FriendRow({ name, acc, status, onPool }: { name: string; acc: string; status: 'online' | 'offline', onPool: () => void }) {
  return (
    <div className="flex items-center justify-between p-4 border-b border-border last:border-0 hover:bg-surface3 transition-colors">
      <div className="flex items-center gap-4">
        <div className="relative">
          <div className="w-10 h-10 rounded-full bg-surface3 flex items-center justify-center text-lg">👤</div>
          <div className={`absolute bottom-0 right-0 w-3 h-3 rounded-full border-2 border-surface2 ${status === 'online' ? 'bg-accent' : 'bg-muted'}`}></div>
        </div>
        <div>
          <div className="text-sm font-bold text-text">{name}</div>
          <div className="text-[10px] text-muted uppercase tracking-widest">Acc: {acc}</div>
        </div>
      </div>
      <button 
        onClick={onPool}
        className="flex items-center gap-2 bg-surface3 hover:bg-accent/20 text-accent text-xs font-bold px-3 py-2 rounded-lg transition-all border border-border hover:border-accent/30"
      >
        <Swords size={14} /> Pool
      </button>
    </div>
  );
}

  function ClubFanZoneTab() {
    return (
      <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-6">
        <div className="bg-gradient-to-br from-surface2 to-surface3 border border-border rounded-3xl p-6 flex items-center gap-6">
          <div className="w-16 h-16 rounded-full bg-surface flex items-center justify-center text-3xl shadow-inner border border-border">
            🛡️
          </div>
          <div>
            <h2 className="font-display text-2xl text-text tracking-widest">HAMRUN FANS</h2>
            <p className="text-xs text-muted">You are ranked #42 among Hamrun fans.</p>
          </div>
        </div>

        <div>
          <h3 className="font-display text-xl text-text tracking-widest mb-4">FAN LEADERBOARD</h3>
          <div className="bg-surface2 rounded-3xl border border-border overflow-hidden">
            <FanRow rank={1} name="Hamrun_Ultra" pts="14,200" isMe={false} />
            <FanRow rank={2} name="MaltaLion" pts="13,850" isMe={false} />
            <FanRow rank={3} name="SoccerKing" pts="12,100" isMe={false} />
            <div className="p-2 bg-surface3 text-center text-[10px] text-muted font-bold tracking-widest">...</div>
            <FanRow rank={42} name="MaltaFan_99" pts="4,150" isMe={true} />
          </div>
        </div>
      </motion.div>
    );
  }

function FanRow({ rank, name, pts, isMe }: { rank: number; name: string; pts: string; isMe: boolean }) {
  return (
    <div className={`flex items-center justify-between p-4 border-b border-border last:border-0 ${isMe ? 'bg-accent/5' : 'hover:bg-surface3'} transition-colors`}>
      <div className="flex items-center gap-4">
        <div className={`font-mono text-sm font-bold w-6 text-center ${rank <= 3 ? 'text-accent3' : 'text-muted'}`}>{rank}</div>
        <div className="w-8 h-8 rounded-full bg-surface3 flex items-center justify-center text-sm">👤</div>
        <div className={`text-sm font-bold ${isMe ? 'text-accent' : 'text-text'}`}>{name} {isMe && '(You)'}</div>
      </div>
      <div className="font-mono text-sm font-bold text-accent3">{pts}</div>
    </div>
  );
}
