import { Link } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';

export default function NotFound() {
  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      textAlign: 'center',
      minHeight: '60vh',
      padding: '40px 24px',
    }}>
      <div style={{
        width: 72,
        height: 72,
        borderRadius: 20,
        overflow: 'hidden',
        marginBottom: '24px',
        opacity: 0.3,
      }}>
        <img src="/logo-128.png" alt="FANZONE" width={72} height={72} style={{ display: 'block' }} />
      </div>

      <h1 style={{
        fontSize: '6rem',
        fontWeight: 900,
        letterSpacing: '-0.05em',
        color: 'var(--fz-muted-2)',
        lineHeight: 1,
        marginBottom: '8px',
      }}>
        404
      </h1>

      <h2 className="text-2xl font-bold mb-3">Page Not Found</h2>
      <p className="text-secondary mb-8" style={{ maxWidth: 400 }}>
        The page you're looking for doesn't exist or has been moved. Let's get you back to the action.
      </p>

      <Link to="/" className="btn btn-primary btn-lg">
        <ArrowLeft size={18} />
        Back to Home
      </Link>
    </div>
  );
}
