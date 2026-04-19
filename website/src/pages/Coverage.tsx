import { Globe, Cpu, ArrowRight } from 'lucide-react';
import { Link } from 'react-router-dom';

const LEAGUES = [
  { emoji: '🏴󠁧󠁢󠁥󠁮󠁧󠁿', name: 'Premier League', country: 'England', tier: 'Top Flight' },
  { emoji: '🇪🇸', name: 'La Liga', country: 'Spain', tier: 'Top Flight' },
  { emoji: '🇮🇹', name: 'Serie A', country: 'Italy', tier: 'Top Flight' },
  { emoji: '🇩🇪', name: 'Bundesliga', country: 'Germany', tier: 'Top Flight' },
  { emoji: '🇫🇷', name: 'Ligue 1', country: 'France', tier: 'Top Flight' },
  { emoji: '🏆', name: 'UEFA Champions League', country: 'Europe', tier: 'Continental' },
  { emoji: '🥈', name: 'UEFA Europa League', country: 'Europe', tier: 'Continental' },
  { emoji: '🌍', name: 'World Cup / Euros', country: 'Global', tier: 'Seasonal' },
];

export default function Coverage() {
  return (
    <div>
      <div className="page-heading container">
        <h1>Competitions & Coverage</h1>
        <p>
          We intentionally limit our scope to the top-flight leagues and global competitions that matter most to real fans.
        </p>
      </div>

      <section className="section container">
        <div className="grid grid-cols-2 gap-4" style={{ maxWidth: 900, margin: '0 auto' }}>
          {LEAGUES.map(league => (
            <div
              key={league.name}
              className="glass-card fade-in-up"
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '16px',
                padding: '20px 24px',
              }}
            >
              <span style={{ fontSize: '2rem' }}>{league.emoji}</span>
              <div>
                <h3 className="text-base font-bold">{league.name}</h3>
                <div className="flex items-center gap-2 mt-1">
                  <span className="text-xs text-muted">{league.country}</span>
                  <span style={{
                    width: '3px',
                    height: '3px',
                    borderRadius: '50%',
                    background: 'var(--fz-muted-2)',
                  }} />
                  <span className="text-xs" style={{
                    color: league.tier === 'Top Flight' ? 'var(--fz-accent)' : league.tier === 'Continental' ? 'var(--fz-coral)' : 'var(--fz-success)',
                    fontWeight: 600,
                  }}>
                    {league.tier}
                  </span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* Data Quality Section */}
      <section className="section" style={{ background: 'var(--fz-surface)' }}>
        <div className="container" style={{ maxWidth: 900, margin: '0 auto' }}>
          <div className="grid grid-cols-2 gap-8">
            <div className="glass-card fade-in-up" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div className="icon-box" style={{ background: 'rgba(37, 99, 235, 0.1)' }}>
                <Cpu size={28} color="var(--fz-blue)" />
              </div>
              <h3 className="text-xl font-bold">AI-Powered Data</h3>
              <p className="text-secondary text-sm" style={{ lineHeight: 1.7 }}>
                FANZONE uses proprietary sports data ingestion coupled with Google Gemini AI processing. Fixtures, odds, standings, live events, and match statistics are processed reliably in real-time, avoiding irrelevant league bloat.
              </p>
            </div>

            <div className="glass-card fade-in-up fade-in-up-delay-1" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div className="icon-box" style={{ background: 'rgba(15, 123, 108, 0.15)' }}>
                <Globe size={28} color="var(--fz-teal)" />
              </div>
              <h3 className="text-xl font-bold">Malta-First, Global Scale</h3>
              <p className="text-secondary text-sm" style={{ lineHeight: 1.7 }}>
                The current launch focuses on Malta with design-ready regional market preferences, featured events, and global launch tables already built into the schema. Coverage expands based on community demand.
              </p>
            </div>
          </div>

          <div style={{ textAlign: 'center', marginTop: '40px' }}>
            <Link to="/overview" className="btn btn-outline">
              See How It Works <ArrowRight size={16} />
            </Link>
          </div>
        </div>
      </section>
    </div>
  );
}
