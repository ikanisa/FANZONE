import { Lock, Eye, CheckCircle2, ShieldCheck } from 'lucide-react';
import { Link } from 'react-router-dom';

export default function GuestAuth() {
  return (
    <div className="section container">
      <div className="text-center mb-16">
        <h1 className="text-4xl md:text-5xl font-bold mb-4">Privacy by Design</h1>
        <p className="text-xl text-secondary max-w-2xl mx-auto">
          Explore FANZONE on your terms, and upgrade purely when you are ready to play.
        </p>
      </div>

      <div className="grid md:grid-cols-2 gap-12 max-w-5xl mx-auto">
        <div className="glass-card" style={{ border: '1px solid var(--fz-border-2)' }}>
          <div className="flex items-center gap-3 mb-6">
            <div style={{ padding: '12px', background: 'var(--fz-surface)', borderRadius: '12px', color: 'var(--fz-text)' }}>
              <Eye size={24} />
            </div>
            <h2 className="text-2xl font-bold">Guest Mode</h2>
          </div>
          <p className="text-secondary mb-6">
            Download the app and start discovering right away without sharing a single personal detail.
          </p>
          <ul className="flex-col gap-4 mb-8">
            <li className="flex items-center gap-3"><CheckCircle2 className="text-muted" size={20} /> View Match Coverage</li>
            <li className="flex items-center gap-3"><CheckCircle2 className="text-muted" size={20} /> View Live Scores</li>
            <li className="flex items-center gap-3"><CheckCircle2 className="text-muted" size={20} /> Check Leaderboards</li>
            <li className="flex items-center gap-3 opacity-50"><Lock className="text-muted" size={20} /> No Predictions</li>
            <li className="flex items-center gap-3 opacity-50"><Lock className="text-muted" size={20} /> No FET Wallet</li>
          </ul>
        </div>

        <div className="glass-card" style={{ border: '1px solid var(--fz-accent)' }}>
          <div className="flex items-center gap-3 mb-6">
            <div style={{ padding: '12px', background: 'var(--fz-surface)', borderRadius: '12px', color: 'var(--fz-accent)' }}>
              <ShieldCheck size={24} />
            </div>
            <h2 className="text-2xl font-bold">Authenticated</h2>
          </div>
          <p className="text-secondary mb-6">
            Securely verify via WhatsApp OTP to unlock the full ecosystem. One-tap simple.
          </p>
          <ul className="flex-col gap-4 mb-8">
            <li className="flex items-center gap-3"><CheckCircle2 className="text-accent" size={20} /> Full Prediction Access</li>
            <li className="flex items-center gap-3"><CheckCircle2 className="text-accent" size={20} /> FET Wallet unlocked</li>
            <li className="flex items-center gap-3"><CheckCircle2 className="text-accent" size={20} /> Fan Identity unlocked</li>
            <li className="flex items-center gap-3"><CheckCircle2 className="text-accent" size={20} /> Partner Rewards access</li>
          </ul>
          <Link to="/overview" className="btn btn-accent w-full text-center" style={{ width: '100%' }}>See Product Overview</Link>
        </div>
      </div>
    </div>
  );
}
