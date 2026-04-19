// FANZONE Admin — Auth Guard
import { Navigate } from 'react-router-dom';
import { useAuth } from '../../hooks/useAuth';
import { ROUTES } from '../../config/routes';
import { LoadingState } from '../../components/ui/StateViews';

interface AuthGuardProps {
  children: React.ReactNode;
}

export function AuthGuard({ children }: AuthGuardProps) {
  const { admin, isLoading } = useAuth();

  if (isLoading) {
    return <LoadingState fullPage />;
  }

  if (!admin) {
    return <Navigate to={ROUTES.LOGIN} replace />;
  }

  return <>{children}</>;
}
