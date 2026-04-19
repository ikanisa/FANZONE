import { Link, useLocation } from 'react-router-dom';
import { Menu, X, Download, Zap } from 'lucide-react';
import { useState, useEffect } from 'react';

const NAV_LINKS = [
  { to: '/overview', label: 'How it Works' },
  { to: '/coverage', label: 'Coverage' },
  { to: '/fet', label: 'FET Token' },
  { to: '/rewards', label: 'Rewards' },
];

export default function Navbar() {
  const [isOpen, setIsOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const location = useLocation();

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  useEffect(() => {
    setIsOpen(false);
  }, [location.pathname]);

  return (
    <nav
      id="main-nav"
      style={{
        position: 'sticky',
        top: 0,
        zIndex: 50,
        background: scrolled ? 'rgba(9, 9, 11, 0.92)' : 'rgba(9, 9, 11, 0.6)',
        backdropFilter: 'blur(20px)',
        WebkitBackdropFilter: 'blur(20px)',
        borderBottom: scrolled ? '1px solid var(--fz-border)' : '1px solid transparent',
        transition: 'all 300ms ease',
      }}
    >
      <div className="container flex justify-between items-center" style={{ height: '68px' }}>
        {/* Brand */}
        <Link
          to="/"
          id="brand-logo"
          className="flex items-center gap-2"
          style={{ fontWeight: 900, fontSize: '1.25rem', letterSpacing: '-0.02em', color: 'var(--fz-text)' }}
        >
          <div style={{
            width: 28,
            height: 28,
            borderRadius: 8,
            background: 'linear-gradient(135deg, var(--fz-accent), var(--fz-blue))',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}>
            <Zap size={16} color="#09090B" strokeWidth={3} />
          </div>
          FANZONE
        </Link>

        {/* Desktop Nav Links */}
        <div className="desktop-only flex items-center gap-6">
          {NAV_LINKS.map(link => (
            <Link
              key={link.to}
              to={link.to}
              className="text-sm font-medium"
              style={{
                color: location.pathname === link.to ? 'var(--fz-text)' : 'var(--fz-muted)',
                transition: 'color 180ms ease',
              }}
              onMouseEnter={e => (e.currentTarget.style.color = 'var(--fz-text)')}
              onMouseLeave={e => {
                if (location.pathname !== link.to) {
                  e.currentTarget.style.color = 'var(--fz-muted)';
                }
              }}
            >
              {link.label}
            </Link>
          ))}
        </div>

        {/* Desktop Right Actions */}
        <div className="desktop-only flex items-center gap-4">
          <Link
            to="/contact"
            className="text-sm font-medium"
            style={{ color: 'var(--fz-muted)', transition: 'color 180ms ease' }}
            onMouseEnter={e => (e.currentTarget.style.color = 'var(--fz-text)')}
            onMouseLeave={e => (e.currentTarget.style.color = 'var(--fz-muted)')}
          >
            Support
          </Link>
          <a
            href="#download"
            id="nav-download-cta"
            className="btn btn-primary"
            style={{ padding: '8px 18px', fontSize: '0.8125rem' }}
          >
            <Download size={14} />
            Get the App
          </a>
        </div>

        {/* Mobile Menu Button */}
        <button
          id="mobile-menu-toggle"
          className="mobile-only"
          onClick={() => setIsOpen(!isOpen)}
          style={{ background: 'transparent', padding: 8, color: 'var(--fz-text)' }}
          aria-label="Toggle navigation menu"
        >
          {isOpen ? <X size={24} /> : <Menu size={24} />}
        </button>
      </div>

      {/* Mobile Menu */}
      <div
        style={{
          maxHeight: isOpen ? '400px' : '0',
          overflow: 'hidden',
          transition: 'max-height 350ms cubic-bezier(0.4, 0, 0.2, 1)',
          background: 'var(--fz-surface)',
          borderBottom: isOpen ? '1px solid var(--fz-border)' : 'none',
        }}
      >
        <div style={{ padding: '16px 24px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
          {NAV_LINKS.map(link => (
            <Link
              key={link.to}
              to={link.to}
              style={{
                color: location.pathname === link.to ? 'var(--fz-accent)' : 'var(--fz-text)',
                fontWeight: 500,
                padding: '10px 0',
                fontSize: '0.9375rem',
              }}
            >
              {link.label}
            </Link>
          ))}
          <Link
            to="/contact"
            style={{ color: 'var(--fz-text)', fontWeight: 500, padding: '10px 0', fontSize: '0.9375rem' }}
          >
            Support
          </Link>
          <div style={{ paddingTop: '8px' }}>
            <a
              href="#download"
              className="btn btn-primary w-full"
              style={{ justifyContent: 'center', padding: '12px' }}
            >
              <Download size={16} />
              Get the App
            </a>
          </div>
        </div>
      </div>
    </nav>
  );
}
