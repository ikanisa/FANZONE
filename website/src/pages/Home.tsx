import { ArrowRight, Trophy, Wallet, Phone, Download } from 'lucide-react';
import { Link } from 'react-router-dom';

export default function Home() {
  return (
    <div>
      {/* Hero Section */}
      <section className="section" style={{
        position: 'relative',
        overflow: 'hidden',
        minHeight: '80vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'radial-gradient(circle at top right, rgba(239, 68, 68, 0.15), transparent 60%), radial-gradient(circle at bottom left, rgba(14, 165, 233, 0.1), transparent 50%)'
      }}>
        <div className="container flex flex-col items-center text-center gap-6" style={{ position: 'relative', zIndex: 10 }}>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', background: 'var(--fz-surface-2)', padding: '6px 16px', borderRadius: 'var(--fz-radius-full)', border: '1px solid var(--fz-border-2)' }}>
            <span style={{ display: 'inline-block', width: '8px', height: '8px', background: 'var(--fz-malta-red)', borderRadius: '50%' }}></span>
            <span className="text-sm font-semibold">Malta's Premier Football Platform</span>
          </div>
          
          <h1 className="text-5xl md:text-6xl" style={{ maxWidth: '800px', margin: '16px auto', fontWeight: 800 }}>
            Every Match <br />
            <span style={{ color: 'var(--fz-malta-red)' }}>Means More.</span>
          </h1>
          
          <p className="text-lg text-secondary" style={{ maxWidth: '600px', margin: '0 auto 24px' }}>
            Predict scores, climb leaderboards, earn FET tokens, and redeem real-world rewards. The ultimate hub for football fans.
          </p>
          
          <div className="flex gap-4">
            <a href="#download" className="btn btn-primary" style={{ padding: '12px 28px', fontSize: '16px' }}>
              <Download size={20} /> Download App
            </a>
            <Link to="/guest-auth" className="btn btn-outline" style={{ padding: '12px 28px', fontSize: '16px' }}>
              Explore as Guest
            </Link>
          </div>
        </div>
      </section>

      {/* Features Outline */}
      <section className="section bg-surface my-12" style={{ background: 'var(--fz-surface)' }}>
        <div className="container">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="glass-card flex flex-col items-center text-center gap-4">
              <div style={{ padding: '16px', background: 'var(--fz-bg)', borderRadius: '16px', color: 'var(--fz-accent)' }}>
                <Trophy size={32} />
              </div>
              <h3 className="text-xl font-bold">Predict & Win</h3>
              <p className="text-secondary text-sm">Join daily challenges, place predictions, and climb the global leaderboard.</p>
              <Link to="/overview" className="text-accent hover:text-accent-hover text-sm font-semibold flex items-center gap-1 mt-auto">Learn More <ArrowRight size={16} /></Link>
            </div>
            
            <div className="glass-card flex flex-col items-center text-center gap-4">
              <div style={{ padding: '16px', background: 'var(--fz-bg)', borderRadius: '16px', color: 'var(--fz-warning)' }}>
                <Wallet size={32} />
              </div>
              <h3 className="text-xl font-bold">The FET Economy</h3>
              <p className="text-secondary text-sm">Earn internal FET tokens through engagement and redeem them at select partners.</p>
              <Link to="/fet" className="text-accent hover:text-accent-hover text-sm font-semibold flex items-center gap-1 mt-auto">Token Details <ArrowRight size={16} /></Link>
            </div>
            
            <div className="glass-card flex flex-col items-center text-center gap-4">
              <div style={{ padding: '16px', background: 'var(--fz-bg)', borderRadius: '16px', color: 'var(--fz-success)' }}>
                <Phone size={32} />
              </div>
              <h3 className="text-xl font-bold">One Tap Access</h3>
              <p className="text-secondary text-sm">Login seamlessly with WhatsApp OTP. Real fans, no bots, completely secure.</p>
              <Link to="/guest-auth" className="text-accent hover:text-accent-hover text-sm font-semibold flex items-center gap-1 mt-auto">Security Model <ArrowRight size={16} /></Link>
            </div>
          </div>
        </div>
      </section>

      {/* App CTA */}
      <section className="section" style={{ padding: '100px 0' }}>
        <div className="container">
          <div className="glass-card" style={{ padding: '64px', display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', background: 'linear-gradient(135deg, rgba(239, 68, 68, 0.1) 0%, var(--fz-surface-2) 100%)', border: '1px solid var(--fz-malta-red)' }}>
            <h2 className="text-3xl md:text-4xl font-bold mb-4">Ready to enter the Fanzone?</h2>
            <p className="text-secondary mb-8" style={{ maxWidth: 500 }}>
              Available on iOS and Android. Join the community, predict matches, and start earning today.
            </p>
            <div className="flex gap-4 flex-wrap justify-center" id="download">
              <a href="#" className="btn" style={{ background: '#000', color: '#fff', border: '1px solid #333' }}>
                <img src="/placeholder-apple.svg" alt="App Store" style={{ width: 24, height: 24, marginRight: 8, display: 'none' }} />
                App Store
              </a>
              <a href="#" className="btn" style={{ background: '#000', color: '#fff', border: '1px solid #333' }}>
                <img src="/placeholder-play.svg" alt="Google Play" style={{ width: 24, height: 24, marginRight: 8, display: 'none' }} />
                Google Play
              </a>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
