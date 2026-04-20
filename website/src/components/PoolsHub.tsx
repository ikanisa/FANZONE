import { useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Swords, Plus, Clock, Users, ChevronRight, Activity, Zap, Filter, Trophy, CheckCircle, XCircle, RotateCcw } from 'lucide-react';
import { Link } from 'react-router-dom';
import { useAppStore } from '../store/useAppStore';
import { Card } from './ui/Card';
import { Badge } from './ui/Badge';
import { useScrollDirection } from '../hooks/useScrollDirection';
import { TeamLogo } from './ui/TeamLogo';
import { FETDisplay } from './ui/FETDisplay';

type SortOption = 'ending_soon' | 'high_pool' | 'most_participants';
type MyPoolTab = 'open' | 'locked' | 'settled' | 'voided';

export default function PoolsHub() {
  const [activeTab, setActiveTab] = useState<'featured' | 'open' | 'my_pools' | 'settled'>('open');
  const [myPoolsTab, setMyPoolsTab] = useState<MyPoolTab>('open');
  const [sortBy, setSortBy] = useState<SortOption>('ending_soon');
  const { scorePools, poolEntries } = useAppStore();
  const scrollDirection = useScrollDirection();

  const myEntries = poolEntries.filter(e => e.userId === 'me');
  const myEntryMap = new Map(myEntries.map(e => [e.poolId, e]));
  const myPools = scorePools.filter(c => myEntryMap.has(c.id));
  
  const myOpenPools = myPools.filter(c => c.status === 'open');
  const myLockedPools = myPools.filter(c => c.status === 'locked');
  const mySettledPools = myPools.filter(c => c.status === 'settled');
  const myVoidedPools = myPools.filter(c => c.status === 'void');

  const settledPools = scorePools.filter(c => c.status === 'settled');
  let openPools = scorePools.filter(c => c.status === 'open');
  const featuredPools = [...openPools].sort((a, b) => b.totalPool - a.totalPool).slice(0, 3);

  if (sortBy === 'high_pool') {
    openPools.sort((a, b) => b.totalPool - a.totalPool);
  } else if (sortBy === 'most_participants') {
    openPools.sort((a, b) => b.participantsCount - a.participantsCount);
  } else if (sortBy === 'ending_soon') {
    openPools.sort((a, b) => new Date(a.lockAt).getTime() - new Date(b.lockAt).getTime());
  }

  // Helper to split matchName
  const renderMatchLogos = (matchName: string) => {
    const teams = matchName.split(' vs ');
    if (teams.length === 2) {
      return (
        <div className="flex items-center mr-2">
           <TeamLogo teamName={teams[0]} size={16} className="w-5 h-5 rounded-full border border-border bg-surface -mr-1 relative z-10" />
           <TeamLogo teamName={teams[1]} size={16} className="w-5 h-5 rounded-full border border-border bg-surface" />
        </div>
      );
    }
    return null;
  };

  const renderPoolCard = (pool: any) => (
    <motion.div 
      key={pool.id}
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -10 }}
      className="mb-3"
    >
      <Link to={`/pool/${pool.id}`} className="block group">
        <Card className="hover:border-accent/40 group-hover:shadow-sm p-4">
          <div className="flex justify-between items-start mb-3">
            <div>
              <div className="flex items-center gap-2 mb-2">
                <Badge variant="ghost" className="px-1.5 py-0.5 text-[10px]">
                  <Clock size={10} className="mr-1 inline" /> {new Date(pool.lockAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </Badge>
                {pool.status === 'open' && <Badge variant="accent" pulse className="px-1.5 py-0.5 text-[10px]">OPEN</Badge>}
                {pool.status === 'settled' && <Badge variant="accent3" className="px-1.5 py-0.5 text-[10px]">SETTLED</Badge>}
                {pool.status === 'locked' && <Badge variant="ghost" className="px-1.5 py-0.5 text-[10px]">LOCKED</Badge>}
              </div>
              <div className="flex items-center mt-1">
                 {renderMatchLogos(pool.matchName)}
                 <h3 className="font-sans font-bold text-sm text-text tracking-tight">{pool.matchName}</h3>
              </div>
            </div>
            <div className="text-right">
              <div className="text-[10px] text-muted font-bold uppercase tracking-widest mb-0.5">Stake</div>
              <div className="font-mono font-bold text-text text-xs">
                 <FETDisplay amount={pool.stake} showFiat={false} />
              </div>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-2 mb-3">
            <div className="bg-surface2 rounded-lg p-2 flex items-center justify-between border border-border">
              <div className="flex items-center gap-1.5">
                <Zap size={14} className="text-accent" />
                <span className="text-[10px] text-muted font-bold uppercase">Pool</span>
              </div>
              <div className="font-mono font-bold text-text text-xs">
                 <FETDisplay amount={pool.totalPool} showFiat={false} />
              </div>
            </div>
            <div className="bg-surface2 rounded-lg p-2 flex items-center justify-between border border-border">
               <div className="flex items-center gap-1.5">
                <Users size={14} className="text-accent4" />
                <span className="text-[10px] text-muted font-bold uppercase">Entries</span>
              </div>
              <div className="font-mono font-bold text-text text-xs">{pool.participantsCount}</div>
            </div>
          </div>
        </Card>
      </Link>
    </motion.div>
  );

  const renderMyPoolCard = (pool: any) => {
    const myEntry = myEntryMap.get(pool.id)!;
    const parts = pool.matchName.split(' vs ');
    const ht = parts[0] ? parts[0].trim() : 'Home';
    const at = parts[1] ? parts[1].trim() : 'Away';
    const myPickStr = `${ht} ${myEntry.predictedHomeScore}:${myEntry.predictedAwayScore} ${at}`;

    return (
      <motion.div 
        key={pool.id}
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: -10 }}
        className="mb-3"
      >
        <Link to={`/pool/${pool.id}`} className="block group">
          <Card className="hover:border-accent/40 group-hover:shadow-sm p-4">
            <div className="flex justify-between items-start mb-3">
              <div>
                <div className="flex items-center gap-2 mb-2">
                  {pool.status === 'open' && <Badge variant="accent" pulse className="px-1.5 py-0.5 text-[10px]">OPEN</Badge>}
                  {pool.status === 'locked' && <Badge variant="ghost" className="px-1.5 py-0.5 text-[10px]">LOCKED</Badge>}
                  {pool.status === 'settled' && <Badge variant="accent3" className="px-1.5 py-0.5 text-[10px]">SETTLED</Badge>}
                  {pool.status === 'void' && <Badge variant="ghost" className="px-1.5 py-0.5 text-[10px]">VOIDED</Badge>}
                </div>
                <div className="flex items-center mt-1">
                   {renderMatchLogos(pool.matchName)}
                   <h3 className="font-sans font-bold text-sm text-text tracking-tight">{pool.matchName}</h3>
                </div>
              </div>
              <div className="text-right">
                <div className="text-[10px] text-muted font-bold uppercase tracking-widest mb-0.5">Stake</div>
                <div className="font-mono font-bold text-text text-xs">{pool.stake}</div>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-2 mb-3">
              <div className="bg-surface2 flex items-center justify-between border border-border p-2 rounded-lg">
                <span className="text-[10px] text-muted font-bold uppercase">Your Pick</span>
                <span className="font-bold text-xs text-text">{myPickStr}</span>
              </div>
              <div className="bg-surface2 flex items-center justify-between border border-border p-2 rounded-lg">
                 <div className="flex items-center gap-1.5">
                   <Zap size={14} className="text-accent" />
                   <span className="text-[10px] text-muted font-bold uppercase">Pool</span>
                 </div>
                 <span className="font-mono text-xs font-bold text-text">{pool.totalPool}</span>
              </div>
            </div>

            {pool.status === 'settled' && (
              <div className={`pt-2 border-t border-border flex items-center justify-between ${
                myEntry.status === 'winner' ? 'text-accent' : 'text-accent2'
              }`}>
                <div className="flex items-center gap-1.5 font-bold text-[10px] uppercase tracking-widest">
                  {myEntry.status === 'winner' ? <CheckCircle size={12} /> : <XCircle size={12} />}
                  {myEntry.status === 'winner' ? 'WON' : 'LOST'}
                </div>
                {myEntry.status === 'winner' && (
                  <span className="font-mono font-bold text-xs">+{myEntry.payout} FET</span>
                )}
              </div>
             )}

            {pool.status === 'void' && (
              <div className="pt-2 border-t border-border flex items-center justify-between text-muted">
                <div className="flex items-center gap-1.5 font-bold text-[10px] uppercase tracking-widest">
                  <RotateCcw size={12} /> REFUNDED
                </div>
                <span className="font-mono font-bold text-xs">+{myEntry.stake} FET</span>
              </div>
            )}
          </Card>
        </Link>
      </motion.div>
    );
  };

  return (
    <div className="min-h-screen bg-bg pb-32 transition-colors duration-300">
      
      {/* Page Title - Not Sticky */}
      <div className="px-5 pt-5 pb-3 flex items-center justify-between">
        <div>
          <h1 className="font-display text-4xl text-text tracking-tight mb-1">Pools</h1>
        </div>
        <Link 
          to="/pools/create" 
          className="bg-[var(--accent2)] w-10 h-10 rounded-full flex items-center justify-center text-bg hover:opacity-90 transition-opacity shadow-[0_0_15px_rgba(255,127,80,0.3)]"
        >
          <Plus size={20} />
        </Link>
      </div>

      {/* Auto-Hiding Filter Bar */}
      <header 
        className={`sticky z-30 transition-all duration-300 bg-bg/95 backdrop-blur-xl border-b border-border p-3 shadow-sm flex flex-col gap-3 ${
          scrollDirection === 'down' ? '-top-40' : 'top-[60px] lg:top-0'
        }`}
      >
        <div className="flex gap-2 bg-surface2 p-1 rounded-full border border-border">
          <button 
            onClick={() => setActiveTab('featured')}
            className={`flex-1 p-2 rounded-full transition-all flex items-center justify-center gap-1 font-bold text-xs ${activeTab === 'featured' ? 'bg-text text-bg shadow-sm' : 'text-muted hover:text-text'}`}
          >
            <Star size={16} className={activeTab === 'featured' ? 'text-bg' : 'text-accent3'} /> <span className="hidden sm:inline">Featured</span>
          </button>
          <button 
            onClick={() => setActiveTab('open')}
            className={`flex-1 p-2 rounded-full transition-all flex items-center justify-center gap-1 font-bold text-xs ${activeTab === 'open' ? 'bg-text text-bg shadow-sm' : 'text-muted hover:text-text'}`}
          >
            <Activity size={16} className={activeTab === 'open' ? 'text-bg' : 'text-accent'} /> <span className="hidden sm:inline">Open</span>
          </button>
          <button 
            onClick={() => setActiveTab('my_pools')}
            className={`flex-1 p-2 rounded-full transition-all flex items-center justify-center gap-1 font-bold text-xs ${activeTab === 'my_pools' ? 'bg-text text-bg shadow-sm' : 'text-muted hover:text-text'}`}
          >
            <Swords size={16} /> <span className="hidden sm:inline">Mine</span>
            {myPools.length > 0 && (
              <span className={`text-[9px] px-1.5 py-0.5 rounded-full leading-none ${activeTab === 'my_pools' ? 'bg-bg text-text' : 'bg-accent text-surface'}`}>{myPools.length}</span>
            )}
          </button>
          <button 
            onClick={() => setActiveTab('settled')}
            className={`flex-1 p-2 rounded-full transition-all flex items-center justify-center gap-1 font-bold text-xs ${activeTab === 'settled' ? 'bg-text text-bg shadow-sm' : 'text-muted hover:text-text'}`}
          >
            <Trophy size={16} /> <span className="hidden sm:inline">Settled</span>
          </button>
        </div>

        {/* Sub Filters */}
        {activeTab === 'open' && (
          <div className="flex gap-2 overflow-x-auto hide-scrollbar items-center px-1 pb-1">
            <Filter size={14} className="text-muted mr-1" />
            <button 
              onClick={() => setSortBy('ending_soon')}
              className={`px-3 py-1.5 rounded-full text-[10px] font-bold uppercase tracking-widest whitespace-nowrap transition-all flex items-center gap-1.5 ${
                sortBy === 'ending_soon' ? 'bg-text text-bg' : 'bg-surface border border-border text-muted hover:text-text'
              }`}
            >
              <Clock size={12} /> Soon
            </button>
            <button 
              onClick={() => setSortBy('high_pool')}
              className={`px-3 py-1.5 rounded-full text-[10px] font-bold uppercase tracking-widest whitespace-nowrap transition-all flex items-center gap-1.5 ${
                sortBy === 'high_pool' ? 'bg-text text-bg' : 'bg-surface border border-border text-muted hover:text-text'
              }`}
            >
              <Zap size={12} /> Big Pool
            </button>
            <button 
              onClick={() => setSortBy('most_participants')}
              className={`px-3 py-1.5 rounded-full text-[10px] font-bold uppercase tracking-widest whitespace-nowrap transition-all flex items-center gap-1.5 ${
                sortBy === 'most_participants' ? 'bg-text text-bg' : 'bg-surface border border-border text-muted hover:text-text'
              }`}
            >
              <Users size={12} /> Entries
            </button>
          </div>
        )}

        {activeTab === 'my_pools' && (
          <div className="flex gap-2 overflow-x-auto hide-scrollbar px-1">
            {['open', 'locked', 'settled', 'voided'].map((tab) => (
               <button 
                key={tab}
                onClick={() => setMyPoolsTab(tab as MyPoolTab)}
                className={`px-3 py-1.5 rounded-full text-[10px] font-bold uppercase tracking-widest whitespace-nowrap transition-all ${
                  myPoolsTab === tab ? 'bg-text text-bg' : 'bg-surface border border-border text-muted hover:text-text'
                }`}
              >
                {tab}
              </button>
            ))}
          </div>
        )}
      </header>

      <div className="p-6 lg:p-12">
        <AnimatePresence mode="popLayout">
          {activeTab === 'featured' && (
            featuredPools.length > 0 ? featuredPools.map(renderPoolCard) : (
              <EmptyState icon={<Zap size={40} />} title="No Featured Pools" subtitle="Check back later for big pool pools." action={() => setActiveTab('open')} actionText="View Open" />
            )
          )}
          
          {activeTab === 'open' && (
            openPools.length > 0 ? openPools.map(renderPoolCard) : (
              <EmptyState icon={<Swords size={40} />} title="No Open Pools" subtitle="Be the first to create one and invite others to join." link="/pools/create" linkText="Create Pool" />
            )
          )}

          {activeTab === 'my_pools' && myPoolsTab === 'open' && (
            myOpenPools.length > 0 ? myOpenPools.map(renderMyPoolCard) : (
             <EmptyState icon={<Swords size={40} />} title="No Open Entries" subtitle="You haven't joined any open pools." action={() => setActiveTab('open')} actionText="Browse Open" />
            )
          )}

          {activeTab === 'my_pools' && myPoolsTab === 'locked' && (
            myLockedPools.length > 0 ? myLockedPools.map(renderMyPoolCard) : (
             <EmptyState icon={<Clock size={40} />} title="No Locked Entries" subtitle="Pools lock at kickoff. You have none pending." />
            )
          )}

          {activeTab === 'my_pools' && myPoolsTab === 'settled' && (
            mySettledPools.length > 0 ? mySettledPools.map(renderMyPoolCard) : (
             <EmptyState icon={<Trophy size={40} />} title="No Settled Entries" subtitle="None of your active pools have settled yet." />
            )
          )}

          {activeTab === 'my_pools' && myPoolsTab === 'voided' && (
            myVoidedPools.length > 0 ? myVoidedPools.map(renderMyPoolCard) : (
             <EmptyState icon={<RotateCcw size={40} />} title="No Voided Entries" subtitle="Pools are voided if matches are cancelled or there are no winners." />
            )
          )}

          {activeTab === 'settled' && (
            settledPools.length > 0 ? settledPools.map(renderPoolCard) : (
              <EmptyState icon={<Trophy size={40} />} title="No Settled Pools" subtitle="No pools have been settled recently." action={() => setActiveTab('open')} actionText="Browse Open" />
            )
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}

function EmptyState({ icon, title, subtitle, action, actionText, link, linkText }: any) {
  return (
    <motion.div 
      initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
      className="text-center py-16 px-4"
    >
      <div className="mx-auto text-muted mb-4 flex justify-center">{icon}</div>
      <h3 className="text-xl font-sans font-bold text-text tracking-tight mb-2">{title}</h3>
      <p className="text-muted text-sm mb-6 max-w-xs mx-auto">{subtitle}</p>
      {action && (
        <button onClick={action} className="inline-flex bg-text text-bg font-bold px-6 py-2.5 rounded-full hover:opacity-90 transition-opacity">
          {actionText}
        </button>
      )}
      {link && (
        <Link to={link} className="inline-flex bg-text text-bg font-bold px-6 py-2.5 rounded-full hover:opacity-90 transition-opacity">
          {linkText}
        </Link>
      )}
    </motion.div>
  );
}
