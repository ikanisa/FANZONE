// FANZONE Admin — Login Page
import { useState } from 'react';
import { useAuth } from '../../hooks/useAuth';
import { Loader } from 'lucide-react';
import logoImg from '../../assets/logo-128.png';
import { isDemoMode } from '../../lib/supabase';

export function LoginPage() {
  const { signIn, isLoading, error } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim() || !password.trim()) return;
    await signIn(email.trim(), password.trim());
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="login-brand">
          <img src={logoImg} alt="FANZONE" className="login-logo" />
          <h1 className="login-title">FANZONE</h1>
          <p className="login-subtitle">Admin Console</p>
        </div>

        <form className="login-form" onSubmit={handleSubmit}>
          {isDemoMode && (
            <div className="login-info">
              Demo mode is enabled for local development. Live admin writes are disabled.
            </div>
          )}

          {error && (
            <div className="login-error">
              {error}
            </div>
          )}

          <div className="field-group">
            <label className="label" htmlFor="login-email">Email</label>
            <input
              id="login-email"
              type="email"
              className="input"
              placeholder="admin@fanzone.mt"
              value={email}
              onChange={e => setEmail(e.target.value)}
              autoComplete="email"
              autoFocus
              required
            />
          </div>

          <div className="field-group">
            <label className="label" htmlFor="login-password">Password</label>
            <input
              id="login-password"
              type="password"
              className="input"
              placeholder="••••••••"
              value={password}
              onChange={e => setPassword(e.target.value)}
              autoComplete="current-password"
              required
            />
          </div>

          <button
            type="submit"
            className="btn btn-primary w-full btn-lg"
            disabled={isLoading || !email.trim() || !password.trim()}
          >
            {isLoading ? <Loader size={18} className="spin" /> : 'Sign In'}
          </button>
        </form>

        <p className="login-footer">FANZONE Malta — Internal Use Only</p>
      </div>

      <style>{`
        .login-page {
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          background: var(--fz-bg);
          padding: var(--fz-sp-6);
        }
        .login-card {
          width: 100%;
          max-width: 400px;
          background: var(--fz-surface);
          border: 1px solid var(--fz-border);
          border-radius: var(--fz-radius-xl);
          padding: var(--fz-sp-10);
        }
        .login-brand {
          text-align: center;
          margin-bottom: var(--fz-sp-8);
        }
        .login-logo {
          width: 64px;
          height: 64px;
          border-radius: var(--fz-radius-lg);
          object-fit: contain;
          margin: 0 auto var(--fz-sp-4);
        }
        .login-title {
          font-size: var(--fz-text-2xl);
          font-weight: 800;
          letter-spacing: 0.06em;
          color: var(--fz-text);
        }
        .login-subtitle {
          font-size: var(--fz-text-sm);
          color: var(--fz-muted);
          margin-top: var(--fz-sp-1);
        }
        .login-form {
          display: flex;
          flex-direction: column;
          gap: var(--fz-sp-5);
        }
        .login-error {
          background: var(--fz-error-bg);
          color: var(--fz-error);
          padding: var(--fz-sp-3) var(--fz-sp-4);
          border-radius: var(--fz-radius);
          font-size: var(--fz-text-sm);
          border: 1px solid rgba(239,68,68,0.2);
        }
        .login-info {
          background: rgba(34, 211, 238, 0.12);
          color: var(--fz-text);
          padding: var(--fz-sp-3) var(--fz-sp-4);
          border-radius: var(--fz-radius);
          font-size: var(--fz-text-sm);
          border: 1px solid rgba(34, 211, 238, 0.2);
        }
        .login-footer {
          text-align: center;
          font-size: var(--fz-text-xs);
          color: var(--fz-muted-2);
          margin-top: var(--fz-sp-8);
        }
        .spin { animation: spin 1s linear infinite; }
        @keyframes spin { to { transform: rotate(360deg); } }
      `}</style>
    </div>
  );
}
