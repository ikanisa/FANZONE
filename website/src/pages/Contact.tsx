import { MessageCircle, Mail, Shield, Clock } from 'lucide-react';

const WHATSAPP_URL = 'https://wa.me/35699711145';

export default function Contact() {
  return (
    <div>
      <div className="page-heading container">
        <h1>Support & Contact</h1>
        <p>
          Questions about predictions, your wallet, account security, or partner rewards? We're here to help.
        </p>
      </div>

      <section className="section container">
        <div className="grid grid-cols-2 gap-8" style={{ maxWidth: 900, margin: '0 auto' }}>
          {/* WhatsApp */}
          <div className="glass-card fade-in-up" style={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            textAlign: 'center',
            gap: '16px',
            padding: '40px 32px',
          }}>
            <div className="icon-box" style={{ background: 'rgba(34, 211, 238, 0.1)', width: 64, height: 64 }}>
              <MessageCircle size={32} color="var(--fz-accent)" />
            </div>
            <h3 className="text-2xl font-bold">WhatsApp Support</h3>
            <p className="text-secondary text-sm" style={{ lineHeight: 1.6, maxWidth: 280 }}>
              Fastest response. Chat directly with the FANZONE support team on WhatsApp during business hours.
            </p>
            <div className="flex items-center gap-2 text-xs text-muted">
              <Clock size={12} />
              <span>Typical response: under 2 hours</span>
            </div>
            <a
              href={WHATSAPP_URL}
              target="_blank"
              rel="noreferrer"
              id="contact-whatsapp-cta"
              className="btn btn-primary w-full"
              style={{ justifyContent: 'center', marginTop: '8px' }}
            >
              <MessageCircle size={16} />
              Open WhatsApp Chat
            </a>
          </div>

          {/* Email */}
          <div className="glass-card fade-in-up fade-in-up-delay-1" style={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            textAlign: 'center',
            gap: '16px',
            padding: '40px 32px',
          }}>
            <div className="icon-box" style={{ background: 'var(--fz-surface-3)', width: 64, height: 64 }}>
              <Mail size={32} color="var(--fz-text-secondary)" />
            </div>
            <h3 className="text-2xl font-bold">Email Support</h3>
            <p className="text-secondary text-sm" style={{ lineHeight: 1.6, maxWidth: 280 }}>
              For partnerships, data requests, account deletion, GDPR inquiries, or detailed technical issues.
            </p>
            <div className="flex items-center gap-2 text-xs text-muted">
              <Clock size={12} />
              <span>Typical response: 1–2 business days</span>
            </div>
            <a
              href="mailto:support@ikanisa.com"
              id="contact-email-cta"
              className="btn btn-outline w-full"
              style={{ justifyContent: 'center', marginTop: '8px' }}
            >
              <Mail size={16} />
              support@ikanisa.com
            </a>
          </div>
        </div>
      </section>

      {/* Additional Contacts */}
      <section className="section" style={{ background: 'var(--fz-surface)' }}>
        <div className="container" style={{ maxWidth: 800, margin: '0 auto' }}>
          <div className="section-header">
            <h2>Other Inquiries</h2>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            <div className="fade-in-up" style={{
              display: 'flex',
              alignItems: 'center',
              gap: '16px',
              padding: '20px 24px',
              background: 'var(--fz-surface-2)',
              borderRadius: '14px',
              border: '1px solid var(--fz-border)',
            }}>
              <Shield size={22} color="var(--fz-accent)" />
              <div style={{ flex: 1 }}>
                <div className="font-semibold mb-1">Privacy & Data Requests</div>
                <div className="text-sm text-secondary">GDPR rights, data export, account deletion</div>
              </div>
              <a href="mailto:privacy@ikanisa.com" className="text-accent text-sm font-semibold">
                privacy@ikanisa.com
              </a>
            </div>

            <div className="fade-in-up fade-in-up-delay-1" style={{
              display: 'flex',
              alignItems: 'center',
              gap: '16px',
              padding: '20px 24px',
              background: 'var(--fz-surface-2)',
              borderRadius: '14px',
              border: '1px solid var(--fz-border)',
            }}>
              <Mail size={22} color="var(--fz-coral)" />
              <div style={{ flex: 1 }}>
                <div className="font-semibold mb-1">General & Business</div>
                <div className="text-sm text-secondary">Partnerships, press, and general inquiries</div>
              </div>
              <a href="mailto:info@ikanisa.com" className="text-accent text-sm font-semibold">
                info@ikanisa.com
              </a>
            </div>

            <div className="fade-in-up fade-in-up-delay-2" style={{
              display: 'flex',
              alignItems: 'center',
              gap: '16px',
              padding: '20px 24px',
              background: 'var(--fz-surface-2)',
              borderRadius: '14px',
              border: '1px solid var(--fz-border)',
            }}>
              <Shield size={22} color="var(--fz-teal)" />
              <div style={{ flex: 1 }}>
                <div className="font-semibold mb-1">Account Deletion</div>
                <div className="text-sm text-secondary">Use Settings → Request Account Deletion in the app, or email us</div>
              </div>
              <a href="mailto:privacy@ikanisa.com" className="text-accent text-sm font-semibold">
                Request
              </a>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
