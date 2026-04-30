// FANZONE Admin — Entry Point
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AuthProvider } from './hooks/AuthProvider';
import { ToastProvider } from './hooks/ToastProvider';
import { ToastContainer } from './components/ui/ToastContainer';
import { App } from './App';
import './styles/index.css';
import './styles/components.css';
import './styles/utilities.css';

document.documentElement.dataset.theme = 'dark';
document.documentElement.style.colorScheme = 'dark';
document.body.style.backgroundColor = '#0C0A09';
document.body.style.color = '#FAFAF9';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <ToastProvider>
          <App />
          <ToastContainer />
        </ToastProvider>
      </AuthProvider>
    </QueryClientProvider>
  </StrictMode>
);
