import { CheckCircle2 } from 'lucide-react';

export default function Overview() {
  return (
    <div className="section container">
      <div className="text-center mb-12">
        <h1 className="text-4xl md:text-5xl font-bold mb-4">How FANZONE Works</h1>
        <p className="text-xl text-secondary max-w-2xl mx-auto">
          Built for real fans. Engage with matches, make smart predictions, and grow your reputation.
        </p>
      </div>

      <div className="grid md:grid-cols-2 gap-8 my-16">
        <div className="glass-card flex-col justify-center">
          <h2 className="text-3xl font-bold mb-6 text-red">1. Predict the Action</h2>
          <p className="text-secondary mb-6 text-lg">
            Use your football knowledge to predict outcomes of top-flight matches. Join daily challenges or place predictions on live events as the game unfolds.
          </p>
          <ul className="flex-col gap-4">
            <li className="flex items-center gap-3"><CheckCircle2 className="text-accent" /> Free Prediction Slips</li>
            <li className="flex items-center gap-3"><CheckCircle2 className="text-accent" /> Live Live-Match Predictions</li>
            <li className="flex items-center gap-3"><CheckCircle2 className="text-accent" /> Dynamic Leaderboards</li>
          </ul>
        </div>
        
        <div style={{ background: 'var(--fz-surface-2)', borderRadius: '16px', minHeight: '300px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <span className="text-muted">Prediction UI Showcase</span>
        </div>
      </div>

      <div className="grid md:grid-cols-2 gap-8 my-16">
        <div style={{ background: 'var(--fz-surface-2)', borderRadius: '16px', minHeight: '300px', display: 'flex', alignItems: 'center', justifyContent: 'center', order: -1 }}>
          <span className="text-muted">Wallet & Rewards UI</span>
        </div>

        <div className="glass-card flex-col justify-center">
          <h2 className="text-3xl font-bold mb-6 text-accent">2. Earn & Redeem</h2>
          <p className="text-secondary mb-6 text-lg">
            Your success on the platform translates into FET tokens. Withdraw your winnings directly or redeem them for exclusive partner rewards.
          </p>
          <ul className="flex-col gap-4">
            <li className="flex items-center gap-3"><CheckCircle2 className="text-red" /> FET Token Economy</li>
            <li className="flex items-center gap-3"><CheckCircle2 className="text-red" /> Secure Wallet Integration</li>
            <li className="flex items-center gap-3"><CheckCircle2 className="text-red" /> Exclusive Retail Partners</li>
          </ul>
        </div>
      </div>

      <div className="grid md:grid-cols-2 gap-8 my-16">
        <div className="glass-card flex-col justify-center">
          <h2 className="text-3xl font-bold mb-6 text-red">3. Defend Your Team</h2>
          <p className="text-secondary mb-6 text-lg">
            Football is tribal. Identity matters. Support your club, engage in AI-curated team news streams, and contribute to your team's community strength meter.
          </p>
          <ul className="flex-col gap-4">
            <li className="flex items-center gap-3"><CheckCircle2 className="text-accent" /> Fan Identity Workflows</li>
            <li className="flex items-center gap-3"><CheckCircle2 className="text-accent" /> AI Team News</li>
            <li className="flex items-center gap-3"><CheckCircle2 className="text-accent" /> Community Contests</li>
          </ul>
        </div>

        <div style={{ background: 'var(--fz-surface-2)', borderRadius: '16px', minHeight: '300px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <span className="text-muted">Community UI</span>
        </div>
      </div>
    </div>
  );
}
