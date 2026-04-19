import { Link } from 'react-router-dom';
import { MessageCircle, Zap } from 'lucide-react';

const WHATSAPP_URL = 'https://wa.me/35699711145';

export default function Footer() {
  const currentYear = new Date().getFullYear();

  return (
    <footer style={{
      borderTop: '1px solid var(--fz-border)',
      background: 'var(--fz-surface)',
      marginTop: 'var(--fz-sp-16)',
    }}>
      {/* Main Footer Grid */}
      <div className="container" style={{ padding: '48px 24px 40px' }}>
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(4, 1fr)',
          gap: '32px',
        }}>
          {/* Brand Column */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <Link
              to="/"
              className="flex items-center gap-2"
              style={{ fontWeight: 900, fontSize: '1.25rem', color: 'var(--fz-text)' }}
            >
              <div style={{
                width: 24,
                height: 24,
                borderRadius: 6,
                background: 'linear-gradient(135deg, var(--fz-accent), var(--fz-blue))',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}>
                <Zap size={13} color="#09090B" strokeWidth={3} />
              </div>
              FANZONE
            </Link>
            <p style={{ color: 'var(--fz-muted)', fontSize: '0.8125rem', maxWidth: 260, lineHeight: 1.6 }}>
              Football predictions, fan communities & rewards. The ultimate platform for football fans.
            </p>
            <p style={{
              color: 'var(--fz-muted-2)',
              fontSize: '0.6875rem',
              lineHeight: 1.5,
              marginTop: '4px',
              maxWidth: 260,
            }}>
              FANZONE is a free-to-play prediction platform. FET tokens have no fiat monetary value and cannot be purchased.
            </p>
          </div>

          {/* Product Column */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            <h4 style={{ color: 'var(--fz-text)', fontSize: '0.875rem', fontWeight: 700, marginBottom: '4px' }}>Product</h4>
            <Link to="/overview" style={{ color: 'var(--fz-muted)', fontSize: '0.8125rem' }}>How it Works</Link>
            <Link to="/coverage" style={{ color: 'var(--fz-muted)', fontSize: '0.8125rem' }}>Competitions</Link>
            <Link to="/fet" style={{ color: 'var(--fz-muted)', fontSize: '0.8125rem' }}>FET Token</Link>
            <Link to="/rewards" style={{ color: 'var(--fz-muted)', fontSize: '0.8125rem' }}>Rewards</Link>
            <Link to="/guest-auth" style={{ color: 'var(--fz-muted)', fontSize: '0.8125rem' }}>Guest vs Authenticated</Link>
          </div>

          {/* Support Column */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            <h4 style={{ color: 'var(--fz-text)', fontSize: '0.875rem', fontWeight: 700, marginBottom: '4px' }}>Support</h4>
            <Link to="/faq" style={{ color: 'var(--fz-muted)', fontSize: '0.8125rem' }}>FAQ</Link>
            <Link to="/contact" style={{ color: 'var(--fz-muted)', fontSize: '0.8125rem' }}>Contact Us</Link>
            <a
              href={WHATSAPP_URL}
              target="_blank"
              rel="noreferrer"
              style={{
                color: 'var(--fz-accent)',
                fontSize: '0.8125rem',
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
              }}
            >
              <MessageCircle size={14} />
              WhatsApp Support
            </a>
            <a href="mailto:support@ikanisa.com" style={{ color: 'var(--fz-muted)', fontSize: '0.8125rem' }}>
              support@ikanisa.com
            </a>
          </div>

          {/* Legal Column */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            <h4 style={{ color: 'var(--fz-text)', fontSize: '0.875rem', fontWeight: 700, marginBottom: '4px' }}>Legal</h4>
            <Link to="/terms" style={{ color: 'var(--fz-muted)', fontSize: '0.8125rem' }}>Terms & Conditions</Link>
            <Link to="/privacy" style={{ color: 'var(--fz-muted)', fontSize: '0.8125rem' }}>Privacy Policy</Link>
            <a href="mailto:privacy@ikanisa.com" style={{ color: 'var(--fz-muted)', fontSize: '0.8125rem' }}>
              privacy@ikanisa.com
            </a>
          </div>
        </div>
      </div>

      {/* Bottom Bar */}
      <div
        className="container"
        style={{
          borderTop: '1px solid var(--fz-border)',
          padding: '20px 24px',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: '8px',
        }}
      >
        <p style={{ color: 'var(--fz-muted-2)', fontSize: '0.75rem' }}>
          © {currentYear} FANZONE. All rights reserved.
        </p>
        <p style={{ color: 'var(--fz-muted-2)', fontSize: '0.75rem' }}>
          A product of <a href="https://ikanisa.com" target="_blank" rel="noreferrer" style={{ color: 'var(--fz-muted)', textDecoration: 'underline', textUnderlineOffset: '2px' }}>IKANISA</a>
        </p>
      </div>

      {/* Responsive grid override for footer */}
      <style>{`
        @media (max-width: 768px) {
          footer .container > div:first-child {
            grid-template-columns: repeat(2, 1fr) !important;
          }
        }
        @media (max-width: 480px) {
          footer .container > div:first-child {
            grid-template-columns: 1fr !important;
          }
        }
      `}</style>
    </footer>
  );
}
