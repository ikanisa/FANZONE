import { Gift, Tag, CreditCard, ArrowRight, ShieldCheck } from 'lucide-react';
import { Link } from 'react-router-dom';

export default function Rewards() {
  return (
    <div>
      <div className="page-heading container">
        <h1>Partner Rewards</h1>
        <p>
          Convert your football knowledge into real-world value through our exclusive Maltese and global partner network.
        </p>
      </div>

      {/* How Rewards Work */}
      <section className="section container">
        <div className="grid grid-cols-3 gap-6" style={{ maxWidth: 1000, margin: '0 auto' }}>
          <div className="glass-card fade-in-up" style={{ textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '16px' }}>
            <div className="icon-box" style={{ background: 'rgba(239, 68, 68, 0.1)' }}>
              <Gift size={28} color="var(--fz-danger)" />
            </div>
            <h3 className="text-xl font-bold">1. Earn FET</h3>
            <p className="text-secondary text-sm" style={{ lineHeight: 1.7 }}>
              Climb leaderboards, ace daily challenges, and grow your token balance transparently through verified predictions and community engagement.
            </p>
          </div>

          <div className="glass-card fade-in-up fade-in-up-delay-1" style={{ textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '16px' }}>
            <div className="icon-box" style={{ background: 'rgba(255, 127, 80, 0.1)' }}>
              <Tag size={28} color="var(--fz-coral)" />
            </div>
            <h3 className="text-xl font-bold">2. Browse Marketplace</h3>
            <p className="text-secondary text-sm" style={{ lineHeight: 1.7 }}>
              Discover exclusive discounts, merchandise, and retail offers from curated partners — all hosted directly within the FANZONE app's secure marketplace.
            </p>
          </div>

          <div className="glass-card fade-in-up fade-in-up-delay-2" style={{ textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '16px' }}>
            <div className="icon-box" style={{ background: 'rgba(152, 255, 152, 0.08)' }}>
              <CreditCard size={28} color="var(--fz-success)" />
            </div>
            <h3 className="text-xl font-bold">3. Redeem</h3>
            <p className="text-secondary text-sm" style={{ lineHeight: 1.7 }}>
              Use your FET tokens to claim partner rewards directly in the app. Redemptions are processed securely through the audited FET ledger with full transaction transparency.
            </p>
          </div>
        </div>
      </section>

      {/* Partner Info */}
      <section className="section" style={{ background: 'var(--fz-surface)' }}>
        <div className="container" style={{ maxWidth: 800, margin: '0 auto' }}>
          <div className="section-header">
            <h2>Partner Network</h2>
            <p>The FANZONE partner marketplace is expanding. Here's what to expect.</p>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            {[
              { title: 'Retail Discounts', desc: 'Exclusive percentage-off deals at select retail locations in Malta and partner regions.' },
              { title: 'Merchandise', desc: 'Football-related merchandise and branded items available for FET redemption.' },
              { title: 'F&B Offers', desc: 'Restaurant and café partner deals for match-day dining and fan meetups.' },
              { title: 'Digital Products', desc: 'Digital vouchers, subscriptions, and premium content access from partner brands.' },
            ].map((item, i) => (
              <div
                key={i}
                className="fade-in-up"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '16px',
                  padding: '20px 24px',
                  background: 'var(--fz-surface-2)',
                  borderRadius: '14px',
                  border: '1px solid var(--fz-border)',
                  animationDelay: `${i * 0.05}s`,
                }}
              >
                <div style={{
                  width: '8px',
                  height: '8px',
                  borderRadius: '50%',
                  background: 'var(--fz-accent)',
                  flexShrink: 0,
                }} />
                <div>
                  <div className="font-semibold mb-1">{item.title}</div>
                  <div className="text-sm text-secondary">{item.desc}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Trust Section */}
      <section className="section container">
        <div className="glass-card-static fade-in-up" style={{
          maxWidth: 800,
          margin: '0 auto',
          display: 'flex',
          gap: '24px',
          alignItems: 'flex-start',
          padding: '32px',
        }}>
          <div className="icon-box" style={{ background: 'rgba(34, 211, 238, 0.1)', flexShrink: 0 }}>
            <ShieldCheck size={28} color="var(--fz-accent)" />
          </div>
          <div>
            <h3 className="text-xl font-bold mb-3">Secure & Transparent</h3>
            <p className="text-secondary text-sm" style={{ lineHeight: 1.7 }}>
              All FET redemptions are processed through the audited ledger with Row-Level Security. Transactions are fully transparent, immutable, and reconcilable by operators. Partner rewards are fulfilled as promotional discounts — FET tokens have no fiat monetary value and cannot be purchased with real money.
            </p>
            <div className="flex gap-4 mt-4">
              <Link to="/fet" className="btn btn-outline text-sm" style={{ padding: '8px 16px' }}>
                FET Details <ArrowRight size={14} />
              </Link>
              <Link to="/terms" className="btn btn-ghost text-sm">
                Read Terms
              </Link>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
