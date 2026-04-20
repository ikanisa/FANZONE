import { useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Calendar, ChevronLeft, ChevronRight, Search, ChevronRight as ChevronRightIcon, Filter, Globe, Trophy, Star, ChevronDown, Compass, PlusCircle, Swords, Target } from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';
import { Card } from './ui/Card';
import { useScrollDirection } from '../hooks/useScrollDirection';
import { TeamLogo } from './ui/TeamLogo';
import { useAppStore } from '../store/useAppStore';

export default function Fixtures() {
  const [activeTab, setActiveTab] = useState<'matches' | 'competitions'>('competitions');
  const scrollDirection = useScrollDirection();

  return (
    <div className="min-h-screen bg-bg pb-32 transition-colors duration-300">
      {/* Page Title */}
      <div className="px-4 pt-5 pb-3 flex items-center justify-between">
        <h1 className="font-display text-4xl text-text tracking-tight">Fixtures</h1>
        
        {/* Minimized Icon-Driven Primary Tabs */}
        <div className="flex gap-1.5 bg-surface2 p-1 rounded-full border border-border">
          <button 
            onClick={() => setActiveTab('competitions')}
            className={`p-2 rounded-full transition-all flex items-center justify-center ${activeTab === 'competitions' ? 'bg-[var(--accent2)] text-bg shadow-sm' : 'text-muted hover:text-text'}`}
          >
            <Compass size={16} />
          </button>
          <button 
            onClick={() => setActiveTab('matches')}
            className={`p-2 rounded-full transition-all flex items-center justify-center ${activeTab === 'matches' ? 'bg-accent text-bg shadow-sm' : 'text-muted hover:text-text'}`}
          >
            <Calendar size={16} />
          </button>
        </div>
      </div>

      {activeTab === 'matches' && <MatchesView scrollDirection={scrollDirection} />}
      {activeTab === 'competitions' && <CompetitionsView />}
    </div>
  );
}

function CompetitionsView() {
  const navigate = useNavigate();
  const { profileTeam, favoriteTeams } = useAppStore();
  const [showOthers, setShowOthers] = useState(false);

  // Assuming local user context mapping
  const localLeague = "Rwanda Premier League"; 

  const handleNavigate = (league: string) => {
    navigate(`/league/${league.toLowerCase().replace(/\s+/g, '-')}`);
  };

  const topEuropean = [
    { name: "Premier League", country: "England", code: "EPL", icon: "🏴󠁧󠁢󠁥󠁮󠁧󠁿" },
    { name: "La Liga", country: "Spain", code: "LAL", icon: "🇪🇸" },
    { name: "Serie A", country: "Italy", code: "SER", icon: "🇮🇹" },
    { name: "Bundesliga", country: "Germany", code: "BUN", icon: "🇩🇪" },
    { name: "Ligue 1", country: "France", code: "LIG", icon: "🇫🇷" }
  ];

  const otherLeagues = [
    { name: "Eredivisie", country: "Netherlands", icon: "🇳🇱" },
    { name: "Primeira Liga", country: "Portugal", icon: "🇵🇹" },
    { name: "Pro League", country: "Saudi Arabia", icon: "🇸🇦" },
    { name: "MLS", country: "USA", icon: "🇺🇸" },
    { name: "Brasileirão", country: "Brazil", icon: "🇧🇷" },
  ];

  const majorCompetitions = [
    { name: "2026 World Cup", desc: "North America Qualifier", icon: "🌎" },
    { name: "Champions League", desc: "Group Stage", icon: "⭐" },
    { name: "Europa League", desc: "Knockouts", icon: "🏆" }
  ];

  return (
    <div className="p-4 space-y-6">
      
      {/* 1. My Local & Favorites */}
      <section>
        <div className="flex items-center gap-2 mb-2 px-1">
          <Star size={14} className="text-accent3" />
          <h2 className="font-sans font-bold text-sm text-text">For You</h2>
        </div>
        <div className="grid grid-cols-3 gap-2">
          <Card 
            className="hover:border-accent/30 cursor-pointer group flex flex-col items-center justify-center p-3 text-center gap-1.5 border-border shadow-none"
            onClick={() => handleNavigate(localLeague)}
          >
            <div className="w-8 h-8 rounded-full bg-surface2 border border-border flex justify-center items-center text-sm shadow-inner">🇷🇼</div>
            <div>
              <h3 className="font-bold text-[10px] text-text group-hover:text-accent transition-colors leading-tight">Rwanda<br/>Premier League</h3>
            </div>
          </Card>

          {favoriteTeams.map(team => (
            <Card 
              key={team}
              className="hover:border-accent/30 cursor-pointer group flex flex-col items-center justify-center p-3 text-center gap-1.5 border-border shadow-none"
              onClick={() => handleNavigate('EPL')} // Temporary nav
            >
              <div className="w-8 h-8 rounded-full bg-surface2 border border-border flex justify-center items-center overflow-hidden">
                <TeamLogo teamName={team} size={20} />
              </div>
              <div>
                <h3 className="font-bold text-[10px] text-text group-hover:text-accent transition-colors leading-tight truncate px-1 max-w-full block">{team}</h3>
              </div>
            </Card>
          ))}
        </div>
      </section>

      {/* 2. Top 5 European */}
      <section>
        <div className="flex items-center gap-2 mb-2 px-1">
          <Globe size={14} className="text-accent" />
          <h2 className="font-sans font-bold text-sm text-text">Europe</h2>
        </div>
        <div className="grid gap-1.5">
          {topEuropean.map(league => (
            <div 
              key={league.name}
              onClick={() => handleNavigate(league.name)}
              className="bg-surface hover:bg-surface2 transition-all px-3 py-2.5 rounded-[14px] border border-border flex items-center justify-between cursor-pointer group"
            >
              <div className="flex items-center gap-3">
                <div className="text-base">{league.icon}</div>
                <div className="font-bold text-text text-xs group-hover:text-accent transition-colors">{league.name}</div>
              </div>
              <ChevronRightIcon size={14} className="text-muted/50 group-hover:text-accent transition-colors" />
            </div>
          ))}

          {/* Others Accordion */}
          <div className="mt-1">
            <button 
              onClick={() => setShowOthers(!showOthers)}
              className="w-full bg-surface2/50 hover:bg-surface2 transition-all py-2 rounded-[14px] border border-transparent hover:border-border flex items-center justify-center gap-2 text-muted hover:text-text font-bold text-[10px]"
            >
              <ChevronDown size={12} className={`transition-transform ${showOthers ? 'rotate-180' : ''}`} />
              OTHER LEAGUES
            </button>
            <AnimatePresence>
              {showOthers && (
                <motion.div 
                  initial={{ height: 0, opacity: 0 }}
                  animate={{ height: 'auto', opacity: 1 }}
                  exit={{ height: 0, opacity: 0 }}
                  className="overflow-hidden mt-1.5"
                >
                  <div className="grid gap-3">
                    {otherLeagues.map(l => (
                      <div 
                        key={l.name}
                        onClick={() => handleNavigate(l.name)}
                        className="bg-surface p-4 rounded-xl border border-border flex items-center gap-4 cursor-pointer hover:border-text transition-colors"
                      >
                         <div className="text-xl">{l.icon}</div>
                         <div>
                           <div className="font-bold text-text text-sm">{l.name}</div>
                           <div className="text-xs text-muted">{l.country}</div>
                         </div>
                      </div>
                    ))}
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </div>
      </section>

      {/* 3. Major Competitions */}
      <section>
        <div className="flex items-center gap-2 mb-2 px-1">
          <Trophy size={14} className="text-[var(--accent2)]" />
          <h2 className="font-sans font-bold text-sm text-text">Major Tournaments</h2>
        </div>
        <div className="grid grid-cols-2 gap-2">
          {majorCompetitions.map(comp => (
            <div 
              key={comp.name} 
              className="bg-surface hover:bg-surface2 transition-all p-3 rounded-[14px] border border-border cursor-pointer group flex flex-col gap-1.5"
              onClick={() => handleNavigate(comp.name)}
            >
              <div className="flex items-center justify-between">
                <div className="text-xl group-hover:scale-110 transition-transform">{comp.icon}</div>
                <ChevronRightIcon size={12} className="text-muted/30 group-hover:text-accent transition-colors" />
              </div>
              <div>
                <h3 className="font-bold text-text text-[10px] leading-tight group-hover:text-accent transition-colors truncate">{comp.name}</h3>
                <p className="text-[9px] text-muted truncate">{comp.desc}</p>
              </div>
            </div>
          ))}
        </div>
      </section>

    </div>
  );
}

function MatchesView({ scrollDirection }: { scrollDirection: 'up' | 'down' | null }) {
  const [activeLeague, setActiveLeague] = useState('All');
  const navigate = useNavigate();
  const leagues = ['All', 'Rwanda Premier', 'EPL', 'La Liga', 'Serie A', 'UCL'];
  
  return (
    <>
      {/* Compact, Auto-Hiding, Icon-Driven Filter Bar */}
      <header 
        className={`sticky z-30 transition-all duration-300 bg-bg/95 backdrop-blur-xl border-b border-border shadow-sm flex flex-col gap-2 pt-2 pb-1 ${
          scrollDirection === 'down' ? '-top-32' : 'top-[60px] lg:top-0'
        }`}
      >
        <div className="flex items-center justify-between gap-3 px-4">
          {/* Calendar Nav - Ultra Compact */}
          <div className="flex items-center bg-surface2 rounded-xl p-1 border border-border flex-1">
            <button className="text-muted hover:text-text p-1.5"><ChevronLeft size={16} /></button>
            <div className="flex-1 flex justify-center items-center gap-1.5 text-xs font-bold text-text">
              <Calendar size={14} className="text-accent" />
              <span className="truncate">This Week</span>
            </div>
            <button className="text-muted hover:text-text p-1.5"><ChevronRight size={16} /></button>
          </div>

          {/* Icons Actions */}
          <div className="flex items-center gap-1.5 w-auto">
            <button className="p-2 bg-surface2 border border-border rounded-xl text-text hover:bg-surface3 transition-colors shrink-0">
              <Search size={16} />
            </button>
            <button className="p-2 bg-surface2 border border-border rounded-xl text-text hover:bg-surface3 transition-colors shrink-0">
              <Filter size={16} />
            </button>
          </div>
        </div>

        {/* Super compact League Rail */}
        <div className="flex gap-1.5 overflow-x-auto no-scrollbar px-4 pb-1 pt-1 mt-1">
          {leagues.map(league => (
            <button 
              key={league}
              onClick={() => setActiveLeague(league)}
              className={`px-3 py-1.5 rounded-full text-xs font-bold whitespace-nowrap transition-all ${
                activeLeague === league ? 'bg-text text-bg shadow-sm' : 'bg-surface2 border border-border text-muted hover:text-text'
              }`}
            >
              {league}
            </button>
          ))}
        </div>
      </header>

      {/* Fixture List */}
      <div className="p-4 space-y-6">
        <FixtureGroup date="Today, Apr 14" />
        <FixtureGroup date="Tomorrow, Apr 15" />
      </div>
    </>
  );
}

function FixtureGroup({ date }: { date: string }) {
  return (
    <div>
      <h3 className="text-[10px] font-bold text-muted uppercase tracking-widest mb-2 px-1">{date}</h3>
      <div className="rounded-[20px] bg-surface flex flex-col divide-y divide-border/50 border border-border overflow-hidden shadow-sm">
        <FixtureItem time="18:00" teamA="Liverpool" teamB="Arsenal" matchId="m1" />
        <FixtureItem time="20:00" teamA="Real Madrid" teamB="Barcelona" matchId="m2" />
        <FixtureItem time="21:00" teamA="APR FC" teamB="Rayon Sports" matchId="m3" />
      </div>
    </div>
  );
}

function FixtureItem({ time, teamA, teamB, matchId }: { time: string; teamA: string; teamB: string; matchId: string }) {
  const navigate = useNavigate();

  return (
    <div className="p-3.5 flex items-center justify-between group hover:bg-surface2 transition-colors gap-3">
      <Link to={`/match/${matchId}`} className="flex items-center gap-3 flex-1 min-w-0">
        <div className="font-mono text-[10px] font-bold text-muted w-8 text-center shrink-0">{time}</div>
        
        <div className="flex-1 flex flex-col justify-center gap-2 min-w-0">
          <div className="flex items-center gap-2.5">
             <div className="w-5 h-5 rounded-full overflow-hidden bg-bg flex items-center justify-center shrink-0 border border-border/50 shadow-sm">
               <TeamLogo teamName={teamA} size={20} className="w-full h-full object-contain" />
             </div>
             <span className="text-sm font-bold text-text group-hover:text-accent transition-all truncate leading-none">{teamA}</span>
          </div>
          <div className="flex items-center gap-2.5">
             <div className="w-5 h-5 rounded-full overflow-hidden bg-bg flex items-center justify-center shrink-0 border border-border/50 shadow-sm">
               <TeamLogo teamName={teamB} size={20} className="w-full h-full object-contain" />
             </div>
             <span className="text-sm font-bold text-text group-hover:text-accent transition-all truncate leading-none">{teamB}</span>
          </div>
        </div>
      </Link>

      <div className="flex items-center gap-2 shrink-0 pr-1">
        <button 
          onClick={(e) => { e.preventDefault(); navigate(`/match/${matchId}`); }}
          className="w-10 h-10 rounded-full bg-[var(--accent2)]/10 text-[var(--accent2)] hover:bg-[var(--accent2)] hover:text-bg flex items-center justify-center transition-colors border border-[var(--accent2)]/20"
        >
          <Target size={18} />
        </button>
        <button 
          onClick={(e) => { e.preventDefault(); navigate('/pools'); }}
          className="w-10 h-10 rounded-full bg-accent/10 flex items-center justify-center text-accent hover:bg-accent hover:text-bg transition-colors border border-accent/20"
        >
          <Swords size={18} />
        </button>
      </div>
    </div>
  );
}
