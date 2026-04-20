import React, { useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { useNavigate } from 'react-router-dom';
import { ChevronRight, ShieldCheck, Trophy, Zap, Search } from 'lucide-react';
import { useAppStore } from '../store/useAppStore';

export default function Onboarding() {
  const [step, setStep] = useState(1);
  const navigate = useNavigate();
  const { completeOnboarding, verifyPhone } = useAppStore();

  const nextStep = () => setStep(s => s + 1);
  const finish = () => {
    verifyPhone(); // Ensure they are marked as verified after finishing OTP/Onboarding
    completeOnboarding();
    navigate('/');
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
          {step === 4 && <Step4 key="step4" onNext={nextStep} />}
          {step === 5 && <Step5 key="step5" onFinish={finish} />}
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
        <h1 className="font-display text-6xl text-text tracking-widest mb-2">FANZONE</h1>
        <p className="text-accent text-sm font-bold tracking-[3px] uppercase">Predict. Earn. Repeat.</p>
      </div>

      <div className="space-y-6 mb-12">
        <Feature icon={<Zap />} title="Live Predictions" desc="Predict match outcomes in real-time." />
        <Feature icon={<Trophy />} title="Earn FET Tokens" desc="Get rewarded for your football knowledge." />
        <Feature icon={<ShieldCheck />} title="100% Free to Play" desc="No stakes, no risk. Just pure fandom." />
      </div>

      <button onClick={onNext} className="w-full bg-accent hover:bg-accent/90 text-bg font-bold py-4 rounded-xl transition-all flex items-center justify-center gap-2 mt-auto">
        GET STARTED <ChevronRight size={20} />
      </button>
    </motion.div>
  );
}

function Feature({ icon, title, desc }: { icon: React.ReactNode; title: string; desc: string }) {
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
  return (
    <motion.div
      initial={{ opacity: 0, x: 50 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: -50 }}
      className="flex flex-col h-full justify-center"
    >
      <h2 className="font-display text-4xl text-text tracking-widest mb-4">ENTER PHONE</h2>
      <p className="text-muted text-sm mb-8">We'll send you a code to verify your account.</p>

      <div className="flex gap-4 mb-8">
        <div className="bg-surface2 border border-border rounded-xl p-4 flex items-center justify-center text-text font-bold w-20">
          +356
        </div>
        <input 
          type="tel" 
          placeholder="79XX XXXX" 
          className="flex-1 bg-surface2 border border-border rounded-xl p-4 text-text font-mono focus:outline-none focus:border-accent transition-all"
          autoFocus
        />
      </div>

      <button onClick={onNext} className="w-full bg-accent hover:bg-accent/90 text-bg font-bold py-4 rounded-xl transition-all mt-auto">
        SEND OTP
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
      <h2 className="font-display text-4xl text-text tracking-widest mb-4">VERIFY OTP</h2>
      <p className="text-muted text-sm mb-8">Enter the 6-digit code sent to your phone.</p>

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

      <button onClick={onNext} className="w-full bg-accent hover:bg-accent/90 text-bg font-bold py-4 rounded-xl transition-all mt-auto">
        VERIFY
      </button>
    </motion.div>
  );
}

import { TeamLogo } from './ui/TeamLogo';

function Step4({ onNext }: { onNext: () => void }) {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedTeam, setSelectedTeam] = useState('');
  const { addFavoriteTeam } = useAppStore();

  // Simulating a database of potentially thousands of teams
  const allTeams = [
    // Malta
    'Hamrun Spartans', 'Valletta FC', 'Floriana', 'Birkirkara', 
    'Hibernians', 'Sliema Wanderers', 'Balzan', 'Gzira United',
    'Marsaxlokk', 'Sirens', 'Mosta', 'Naxxar Lions',
    // UK
    'Arsenal', 'Manchester City', 'Manchester United', 'Chelsea',
    'Liverpool', 'Tottenham Hotspur', 'Aston Villa', 'Newcastle United',
    // Rwanda
    'APR FC', 'Rayon Sports', 'Kiyovu Sports', 'Police FC', 'Mukura VS',
    // Nigeria
    'Enyimba', 'Kano Pillars', 'Rivers United', 'Enugu Rangers',
    // Kenya
    'Gor Mahia', 'AFC Leopards'
  ];

  const searchResults = searchQuery 
    ? allTeams.filter(team => team.toLowerCase().includes(searchQuery.toLowerCase())).slice(0, 10)
    : [];

  const handleSelectTeam = (team: string) => {
    setSelectedTeam(team);
    setSearchQuery(''); // Close search and return to default view when selected
  };

  const handleNext = () => {
    if (selectedTeam) {
      addFavoriteTeam(selectedTeam);
    }
    onNext();
  };

  const TeamListItem = ({ team, isSelected }: { team: string, isSelected?: boolean }) => (
    <button
      onClick={() => handleSelectTeam(team)}
      className={`w-full text-left px-4 py-3 rounded-xl transition-all flex items-center justify-between ${
        isSelected 
          ? 'bg-text text-bg font-bold shadow-md' 
          : 'bg-surface hover:bg-surface2 text-text border border-border'
      }`}
    >
      <div className="flex items-center gap-3">
        <div className={`w-8 h-8 rounded-full flex items-center justify-center border ${isSelected ? 'border-bg/20 bg-bg/10' : 'border-border bg-surface2'}`}>
          {isSelected ? (
              <span className="text-bg text-xs font-bold">{team.substring(0, 2).toUpperCase()}</span>
          ) : (
              <TeamLogo teamName={team} size={20} />
          )}
        </div>
        <span>{team}</span>
      </div>
      {isSelected && <ShieldCheck size={18} className="text-bg" />}
    </button>
  );

  return (
    <motion.div
      initial={{ opacity: 0, x: 50 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, y: -20 }}
      className="flex flex-col h-full overflow-hidden pb-4"
    >
      <div className="pt-8 shrink-0 mb-6">
        <h2 className="font-display text-4xl text-text tracking-widest mb-2">Favorite Team</h2>
        <p className="text-muted text-sm">FANZONE is local, add your local favorite team</p>
      </div>

      <div className="flex-1 min-h-0 flex flex-col mb-6">
        <div className="relative mb-4 shrink-0 transition-all">
          <Search size={18} className="absolute left-4 top-1/2 -translate-y-1/2 text-muted" />
          <input 
            type="text"
            placeholder="Search your local favorite team"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-surface2 border border-border rounded-xl p-4 pl-12 text-text focus:outline-none focus:border-accent transition-all placeholder:text-muted/60"
          />
        </div>
        
        <div className="flex-1 overflow-y-auto hide-scrollbar pb-2">
          {searchQuery ? (
            <div className="space-y-2 border border-border rounded-xl bg-surface2/50 p-2">
              {searchResults.length > 0 ? (
                searchResults.map(team => (
                  <TeamListItem key={team} team={team} isSelected={selectedTeam === team} />
                ))
              ) : (
                <div className="text-center text-muted text-sm py-8">No teams found matching "{searchQuery}"</div>
              )}
            </div>
          ) : (
            <div className="space-y-6">
              {selectedTeam ? (
                <div>
                  <div className="text-xs font-bold text-accent uppercase tracking-widest mb-3 px-1">Your Selection</div>
                  <div className="border border-accent/20 rounded-xl bg-accent/5 p-2 mb-8">
                    <TeamListItem team={selectedTeam} isSelected={true} />
                  </div>
                  <div className="flex flex-col items-center justify-center text-center opacity-60">
                    <p className="text-muted text-sm">Search to change your team</p>
                  </div>
                </div>
              ) : (
                <div className="flex flex-col items-center justify-center py-16 px-4 text-center">
                  <Search size={48} className="text-muted/20 mb-4" />
                  <p className="text-muted text-sm">Start typing to find your team</p>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      <div className="mt-auto shrink-0 flex flex-col gap-2">
        <button 
          onClick={handleNext} 
          className={`w-full font-bold py-4 rounded-xl transition-all ${
            selectedTeam 
              ? 'bg-accent hover:bg-accent/90 text-bg shadow-lg shadow-accent/20' 
              : 'bg-surface2 hover:bg-surface3 text-text border border-border shadow-sm'
          }`}
        >
          {selectedTeam ? 'CONTINUE' : 'SKIP THIS STEP'}
        </button>
      </div>
    </motion.div>
  );
}

function Step5({ onFinish }: { onFinish: () => void }) {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedTeam, setSelectedTeam] = useState('');
  const { addFavoriteTeam } = useAppStore();

  const top20Teams = [
    'Real Madrid', 'Barcelona', 'Arsenal', 'Manchester City', 'Manchester United',
    'Liverpool', 'Chelsea', 'Tottenham Hotspur', 'Bayern Munich', 'Borussia Dortmund',
    'PSG', 'Juventus', 'AC Milan', 'Inter Milan', 'Napoli',
    'Atletico Madrid', 'Ajax', 'Porto', 'Benfica', 'Sporting CP'
  ];

  const allEuroTeams = [
    ...top20Teams,
    'AS Roma', 'Lazio', 'Fiorentina', 'Atalanta', 'Sevilla', 'Valencia', 'Villarreal',
    'Real Sociedad', 'Bayer Leverkusen', 'RB Leipzig', 'Eintracht Frankfurt', 'Marseille',
    'Lyon', 'Monaco', 'Lille', 'PSV Eindhoven', 'Feyenoord', 'Club Brugge', 'Anderlecht',
    'Galatasaray', 'Fenerbahce', 'Besiktas', 'Celtic', 'Rangers', 'FC Copenhagen', 'Aston Villa', 'Newcastle United'
  ];

  const searchResults = searchQuery 
    ? allEuroTeams.filter(team => team.toLowerCase().includes(searchQuery.toLowerCase())).slice(0, 10)
    : [];

  const handleSelectTeam = (team: string) => {
    setSelectedTeam(team);
    setSearchQuery('');
  };

  const handleFinish = () => {
    if (selectedTeam) {
      addFavoriteTeam(selectedTeam);
    }
    onFinish();
  };

  const TeamListItem = ({ team, isSelected }: { team: string, isSelected?: boolean }) => (
    <button
      onClick={() => handleSelectTeam(team)}
      className={`w-full text-left px-4 py-3 rounded-xl transition-all flex items-center justify-between ${
        isSelected 
          ? 'bg-text text-bg font-bold shadow-md' 
          : 'bg-surface hover:bg-surface2 text-text border border-border'
      }`}
    >
      <div className="flex items-center gap-3">
        <div className={`w-8 h-8 rounded-full flex items-center justify-center border ${isSelected ? 'border-bg/20 bg-bg/10' : 'border-border bg-surface2'}`}>
          {isSelected ? (
              <span className="text-bg text-xs font-bold">{team.substring(0, 2).toUpperCase()}</span>
          ) : (
              <TeamLogo teamName={team} size={20} />
          )}
        </div>
        <span>{team}</span>
      </div>
      {isSelected && <ShieldCheck size={18} className="text-bg" />}
    </button>
  );

  return (
    <motion.div
      initial={{ opacity: 0, x: 50 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, y: -20 }}
      className="flex flex-col h-full overflow-hidden pb-4"
    >
      <div className="pt-8 shrink-0 mb-4">
        <h2 className="font-display text-4xl text-text tracking-widest mb-2">Popular Teams</h2>
        <p className="text-muted text-sm">Choose your favorite</p>
      </div>

      <div className="flex-1 min-h-0 flex flex-col mb-6 overflow-y-auto hide-scrollbar">
        {selectedTeam ? (
            <div className="mb-6 mt-2">
              <div className="text-xs font-bold text-accent uppercase tracking-widest mb-3 px-1">Your Selection</div>
              <div className="border border-accent/20 rounded-xl bg-accent/5 p-2 mb-8">
                <TeamListItem team={selectedTeam} isSelected={true} />
              </div>
              <div className="flex flex-col items-center justify-center text-center opacity-60">
                <p className="text-muted text-sm">Search or select below to change your team</p>
              </div>
            </div>
        ) : null}

        {(!searchQuery && !selectedTeam) && (
          <div className="grid grid-cols-5 gap-3 mb-8">
            {top20Teams.map(team => (
              <button
                key={team}
                onClick={() => handleSelectTeam(team)}
                title={team}
                className={`aspect-square flex items-center justify-center rounded-xl border transition-all ${
                  selectedTeam === team 
                    ? 'border-accent bg-accent/5 shadow-md' 
                    : 'border-border bg-surface hover:bg-surface2'
                }`}
              >
                <TeamLogo teamName={team} size={32} />
              </button>
            ))}
          </div>
        )}

        <div className="mt-auto shrink-0 space-y-4">
          {(!searchQuery && !selectedTeam) && (
             <p className="text-center text-xs font-bold text-muted uppercase tracking-widest">Didn't find your favorite team? Search more</p>
          )}
          
          <div className="relative shrink-0 transition-all">
            <Search size={18} className="absolute left-4 top-1/2 -translate-y-1/2 text-muted" />
            <input 
              type="text"
              placeholder="Search European teams"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full bg-surface2 border border-border rounded-xl p-4 pl-12 text-text focus:outline-none focus:border-accent transition-all placeholder:text-muted/60"
            />
          </div>

          {searchQuery && (
            <div className="space-y-2 border border-border rounded-xl bg-surface2/50 p-2">
              {searchResults.length > 0 ? (
                searchResults.map(team => (
                  <TeamListItem key={team} team={team} isSelected={selectedTeam === team} />
                ))
              ) : (
                <div className="text-center text-muted text-sm py-8">No teams found matching "{searchQuery}"</div>
              )}
            </div>
          )}
        </div>
      </div>

      <button 
        onClick={handleFinish} 
        className={`w-full font-bold py-4 rounded-xl transition-all mt-auto shrink-0 ${
          selectedTeam 
            ? 'bg-accent hover:bg-accent/90 text-bg shadow-lg shadow-accent/20' 
            : 'bg-surface2 hover:bg-surface3 text-text border border-border shadow-sm'
        }`}
      >
        {selectedTeam ? 'COMPLETE SETUP' : 'SKIP FOR NOW'}
      </button>
    </motion.div>
  );
}
