import { Link } from 'react-router-dom';
import { Menu, X, Download } from 'lucide-react';
import { useState } from 'react';

export default function Navbar() {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <nav style={{
      position: 'sticky',
      top: 0,
      zIndex: 50,
      background: 'rgba(12, 10, 9, 0.8)',
      backdropFilter: 'blur(16px)',
      borderBottom: '1px solid var(--fz-glass-border)'
    }}>
      <div className="container flex justify-between items-center" style={{ height: '72px' }}>
        <Link to="/" className="flex items-center gap-2" style={{ fontWeight: 800, fontSize: '1.25rem', letterSpacing: '-0.02em', color: '#fff' }}>
          <div style={{ width: 24, height: 24, borderRadius: 6, background: 'var(--fz-malta-red)' }} />
          FANZONE
        </Link>
        
        <div className="hidden md:flex items-center gap-6" style={{ display: 'none' }}>
          <Link to="/overview" className="text-secondary hover:text-white" style={{ transition: 'color 150ms' }}>How it Works</Link>
          <Link to="/coverage" className="text-secondary hover:text-white" style={{ transition: 'color 150ms' }}>Coverage</Link>
          <Link to="/fet" className="text-secondary hover:text-white" style={{ transition: 'color 150ms' }}>FET Token</Link>
          <Link to="/rewards" className="text-secondary hover:text-white" style={{ transition: 'color 150ms' }}>Rewards</Link>
        </div>
        
        <div className="hidden md:flex items-center gap-4" style={{ display: 'none' }}>
          <Link to="/contact" className="text-secondary hover:text-white">Support</Link>
          <a href="#download" className="btn btn-primary" style={{ padding: '8px 20px', fontSize: '14px' }}>
            <Download size={16} />
            Get the App
          </a>
        </div>

        {/* Desktop query override (since no tailwind, we do style quick fix or rely on standard media queries). Let's just use CSS. */}
        <style dangerouslySetInnerHTML={{__html: `
          @media (min-width: 768px) {
            .md\\:flex { display: flex !important; }
            .mobile-menu-btn { display: none !important; }
          }
        `}} />

        <button className="mobile-menu-btn text-white" onClick={() => setIsOpen(!isOpen)} style={{ background: 'transparent', padding: 8 }}>
          {isOpen ? <X size={24} /> : <Menu size={24} />}
        </button>
      </div>

      {/* Mobile Menu */}
      {isOpen && (
        <div style={{
          position: 'absolute',
          top: '72px',
          left: 0,
          right: 0,
          background: 'var(--fz-surface)',
          borderBottom: '1px solid var(--fz-border)',
          padding: '24px',
          display: 'flex',
          flexDirection: 'column',
          gap: '16px'
        }}>
          <Link to="/overview" onClick={() => setIsOpen(false)} style={{ color: 'var(--fz-text)', fontWeight: 500 }}>How it Works</Link>
          <Link to="/coverage" onClick={() => setIsOpen(false)} style={{ color: 'var(--fz-text)', fontWeight: 500 }}>Coverage</Link>
          <Link to="/fet" onClick={() => setIsOpen(false)} style={{ color: 'var(--fz-text)', fontWeight: 500 }}>FET Token</Link>
          <Link to="/rewards" onClick={() => setIsOpen(false)} style={{ color: 'var(--fz-text)', fontWeight: 500 }}>Rewards</Link>
          <Link to="/contact" onClick={() => setIsOpen(false)} style={{ color: 'var(--fz-text)', fontWeight: 500 }}>Support</Link>
          <a href="#download" className="btn btn-primary" style={{ justifyContent: 'center' }}>Get the App</a>
        </div>
      )}
    </nav>
  );
}
