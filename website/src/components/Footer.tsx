import { Link } from 'react-router-dom';
import { MessageCircle } from 'lucide-react';

export default function Footer() {
  return (
    <footer style={{
      borderTop: '1px solid var(--fz-border)',
      background: 'var(--fz-surface)',
      marginTop: 'var(--fz-sp-16)',
      padding: 'var(--fz-sp-12) 0 var(--fz-sp-6)'
    }}>
      <div className="container grid md:grid-cols-4 gap-8" style={{ paddingBottom: 'var(--fz-sp-10)' }}>
        <div className="flex-col gap-4">
          <Link to="/" className="flex items-center gap-2" style={{ fontWeight: 800, fontSize: '1.25rem', color: '#fff', marginBottom: '16px' }}>
            <div style={{ width: 24, height: 24, borderRadius: 6, background: 'var(--fz-malta-red)' }} />
            FANZONE
          </Link>
          <p className="text-secondary text-sm" style={{ maxWidth: 280, color: 'var(--fz-muted)' }}>
            The ultimate football prediction and fan engagement platform. Play, predict, and earn rewards with the FET token.
          </p>
        </div>
        
        <div className="flex-col gap-4">
          <h4 style={{ color: 'var(--fz-text)', marginBottom: '16px' }}>Product</h4>
          <Link to="/overview" className="text-secondary hover:text-white text-sm" style={{ display: 'block', marginBottom: '8px' }}>How it Works</Link>
          <Link to="/coverage" className="text-secondary hover:text-white text-sm" style={{ display: 'block', marginBottom: '8px' }}>Competitions</Link>
          <Link to="/fet" className="text-secondary hover:text-white text-sm" style={{ display: 'block', marginBottom: '8px' }}>FET Token</Link>
          <Link to="/guest-auth" className="text-secondary hover:text-white text-sm" style={{ display: 'block', marginBottom: '8px' }}>Guest vs Authenticated</Link>
        </div>

        <div className="flex-col gap-4">
          <h4 style={{ color: 'var(--fz-text)', marginBottom: '16px' }}>Support</h4>
          <Link to="/faq" className="text-secondary hover:text-white text-sm" style={{ display: 'block', marginBottom: '8px' }}>FAQ</Link>
          <Link to="/contact" className="text-secondary hover:text-white text-sm" style={{ display: 'block', marginBottom: '8px' }}>Contact Us</Link>
          <a href="https://wa.me/1234567890" target="_blank" rel="noreferrer" className="text-accent hover:text-accent-hover text-sm flex items-center gap-1" style={{ display: 'flex', marginTop: '8px' }}>
            <MessageCircle size={16} /> WhatsApp Support
          </a>
        </div>

        <div className="flex-col gap-4">
          <h4 style={{ color: 'var(--fz-text)', marginBottom: '16px' }}>Legal</h4>
          <Link to="/terms" className="text-secondary hover:text-white text-sm" style={{ display: 'block', marginBottom: '8px' }}>Terms & Conditions</Link>
          <Link to="/privacy" className="text-secondary hover:text-white text-sm" style={{ display: 'block', marginBottom: '8px' }}>Privacy Policy</Link>
        </div>
      </div>

      <div className="container" style={{
        borderTop: '1px solid var(--fz-border-2)',
        paddingTop: 'var(--fz-sp-6)',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center'
      }}>
        <p className="text-muted text-xs">© {new Date().getFullYear()} FANZONE. All rights reserved.</p>
        <p className="text-muted text-xs">A product of IKANISA.</p>
      </div>
    </footer>
  );
}
